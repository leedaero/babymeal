#!/usr/bin/env python3
import sys, os, json, argparse, secrets, logging, urllib.request, urllib.error
from datetime import datetime, timedelta
from pathlib import Path
from functools import wraps

PROJECT_ROOT = str(Path(__file__).resolve().parent.parent)
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from flask import (
    Flask, render_template, request, redirect,
    url_for, session, jsonify, flash, g, make_response,
)
from werkzeug.security import check_password_hash, generate_password_hash

import db as _db
import minio_storage
from emoji_image import save_emoji_image
from deduction import compute_deductions

# Module-level references exposed for patching in tests
get_connection = _db.get_connection


def get_db():
    """Module-level get_db; replaced per-app by create_app for proper g-scoping."""
    raise RuntimeError('get_db called before create_app')


_VALID_STATUSES  = {'upcoming', 'confirmed', 'skipped', 'auto-consumed'}
_VALID_MEAL_TIMES = {'morning', 'lunch', 'snack', 'dinner'}


def create_app(config=None):
    app = Flask(__name__)
    app.config['SECRET_KEY'] = 'dev'
    app.config['TESTING'] = False
    app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=7)

    if config:
        app.config.update(config)

    if not app.config.get('TESTING') and app.config['SECRET_KEY'] == 'dev':
        import warnings
        warnings.warn('SECRET_KEY가 기본값입니다. config.json에서 변경하세요.', stacklevel=2)

    # ─── DB ───────────────────────────────────────────────
    # Replace module-level get_db so that patch('web.app.get_db') works in tests

    _mod = sys.modules[__name__]

    def _get_db():
        if 'db' not in g:
            if app.config.get('TESTING'):
                from unittest.mock import MagicMock
                g.db = MagicMock()
            else:
                g.db = _db.get_connection()
        return g.db

    _mod.get_db = _get_db

    def get_view_user_id():
        return session.get('view_as_user_id') or session.get('user_id')

    # ─── 보안 헤더 ───────────────────────────────────────────

    @app.after_request
    def _security_headers(resp):
        resp.headers['X-Content-Type-Options'] = 'nosniff'
        resp.headers['X-Frame-Options']        = 'SAMEORIGIN'
        resp.headers['Referrer-Policy']        = 'same-origin'
        return resp

    @app.teardown_appcontext
    def close_db(exc):
        db = g.pop('db', None)
        if db is not None:
            try:
                db.close()
            except Exception:
                pass

    # ─── CSRF ─────────────────────────────────────────────

    _CSRF_EXEMPT  = {'/login', '/logout'}
    _CSRF_SAFE    = {'GET', 'HEAD', 'OPTIONS'}

    def _get_csrf_token():
        if 'csrf_token' not in session:
            session['csrf_token'] = secrets.token_hex(32)
        return session['csrf_token']

    @app.context_processor
    def _inject_csrf():
        return {'csrf_token': _get_csrf_token}

    @app.before_request
    def _csrf_protect():
        if request.method in _CSRF_SAFE:
            return
        if request.path in _CSRF_EXEMPT:
            return
        if not session.get('logged_in'):
            return
        token = (request.headers.get('X-CSRF-Token')
                 or request.form.get('csrf_token'))
        if not token or not secrets.compare_digest(
                token, session.get('csrf_token', '')):
            if request.path.startswith('/api/'):
                return jsonify({'error': 'CSRF 토큰 오류'}), 403
            return 'CSRF 토큰 오류', 403

    # ─── 브루트포스 방지 ──────────────────────────────────

    _attempts = {}
    _MAX_ATTEMPTS  = 10
    _BLOCK_MINUTES = 10

    def _client_ip():
        return request.remote_addr or ''

    def _is_blocked(ip):
        info = _attempts.get(ip)
        if not info:
            return False
        if info.get('blocked_until') and datetime.now() < info['blocked_until']:
            return True
        if info.get('blocked_until'):
            _attempts.pop(ip, None)
        return False

    def _record_failure(ip):
        info = _attempts.get(ip, {'count': 0})
        info['count'] += 1
        if info['count'] >= _MAX_ATTEMPTS:
            info['blocked_until'] = datetime.now() + timedelta(minutes=_BLOCK_MINUTES)
        _attempts[ip] = info

    def _clear_attempts(ip):
        _attempts.pop(ip, None)

    # ─── login_required ───────────────────────────────────

    def login_required(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if not session.get('logged_in'):
                return redirect(url_for('login_page'))
            return f(*args, **kwargs)
        return wrapper

    def admin_required(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if not session.get('logged_in'):
                return redirect(url_for('login_page'))
            if not session.get('is_admin'):
                if request.path.startswith('/api/'):
                    return jsonify({'error': '관리자 권한 필요'}), 403
                return redirect(url_for('inventory_page'))
            return f(*args, **kwargs)
        return wrapper

    # ─── 페이지 라우트 ────────────────────────────────────

    @app.route('/login', methods=['GET', 'POST'])
    def login_page():
        if request.method == 'GET':
            if session.get('logged_in'):
                return redirect(url_for('inventory_page'))
            return render_template('login.html')

        username = request.form.get('username', '')
        password = request.form.get('password', '')
        ip = _client_ip()

        if _is_blocked(ip):
            flash(f'로그인 시도가 너무 많습니다. {_BLOCK_MINUTES}분 후 다시 시도하세요.', 'error')
            return render_template('login.html')

        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute(
            'SELECT id, password_hash, is_admin, is_active FROM users WHERE username=%s',
            (username,)
        )
        user = cur.fetchone()
        if user and user['is_active'] and check_password_hash(user['password_hash'], password):
            session.clear()
            session['logged_in'] = True
            session['username']  = username
            session['user_id']   = user['id']
            session['is_admin']  = bool(user['is_admin'])
            session['view_as_user_id'] = user['id']
            session.permanent    = True
            _clear_attempts(ip)
            return redirect(url_for('inventory_page'))

        _record_failure(ip)
        flash('아이디 또는 비밀번호가 올바르지 않습니다.', 'error')
        return render_template('login.html')

    @app.route('/logout')
    def logout():
        session.clear()
        return redirect(url_for('login_page'))

    @app.route('/')
    @login_required
    def inventory_page():
        _run_auto_deduction(_mod.get_db())
        return render_template('inventory.html', **_page_ctx())

    @app.route('/schedule')
    @login_required
    def schedule_page():
        _run_auto_deduction(_mod.get_db())
        return render_template('schedule.html', **_page_ctx())

    @app.route('/settings')
    @admin_required
    def settings_page():
        return render_template('settings.html', **_page_ctx())

    # ─── 자동 차감 ────────────────────────────────────────

    # ─── 유저 API (관리자 전용) ──────────────────────────────

    @app.get('/api/users')
    @admin_required
    def api_users_list():
        cur = _mod.get_db().cursor()
        cur.execute('SELECT id, username, is_admin, is_active FROM users ORDER BY id')
        return jsonify([dict(r) for r in cur.fetchall()])

    @app.post('/api/users')
    @admin_required
    def api_users_add():
        d = request.get_json() or {}
        username = d.get('username', '').strip()
        password = d.get('password', '')
        is_admin = int(bool(d.get('is_admin', False)))
        if not username or not password:
            return jsonify({'error': '아이디와 비밀번호를 입력하세요'}), 400
        if len(password) < 6:
            return jsonify({'error': '비밀번호는 6자 이상이어야 합니다'}), 400
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('SELECT id FROM users WHERE username=%s', (username,))
        if cur.fetchone():
            return jsonify({'error': '이미 존재하는 아이디입니다'}), 409
        phash = generate_password_hash(password)
        cur.execute(
            'INSERT INTO users (username, password_hash, is_admin) VALUES (%s, %s, %s)',
            (username, phash, is_admin)
        )
        conn.commit()
        cur.execute('SELECT id, username, is_admin, is_active FROM users WHERE id=%s', (cur.lastrowid,))
        return jsonify(dict(cur.fetchone())), 201

    @app.delete('/api/users/<int:user_id>')
    @admin_required
    def api_users_delete(user_id):
        if user_id == session.get('user_id'):
            return jsonify({'error': '본인 계정은 삭제할 수 없습니다'}), 400
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('DELETE FROM users WHERE id=%s', (user_id,))
        conn.commit()
        return jsonify({'ok': True})

    @app.post('/api/users/<int:user_id>/toggle-active')
    @admin_required
    def api_users_toggle(user_id):
        if user_id == session.get('user_id'):
            return jsonify({'error': '본인 계정은 변경할 수 없습니다'}), 400
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('SELECT is_active FROM users WHERE id=%s', (user_id,))
        row = cur.fetchone()
        if not row:
            return jsonify({'error': 'not found'}), 404
        new_active = 0 if row['is_active'] else 1
        cur.execute('UPDATE users SET is_active=%s WHERE id=%s', (new_active, user_id))
        conn.commit()
        cur.execute('SELECT id, username, is_admin, is_active FROM users WHERE id=%s', (user_id,))
        return jsonify(dict(cur.fetchone()))

    def _page_ctx():
        uid = session['user_id']
        vid = session.get('view_as_user_id', uid)
        ctx = {
            'username': session.get('username'),
            'is_admin': session.get('is_admin', False),
            'is_viewing_other': vid != uid,
            'view_username': session.get('username'),
            'all_users': None,
            'view_user_id': vid,
        }
        if session.get('is_admin'):
            cur = _mod.get_db().cursor()
            cur.execute('SELECT id, username FROM users WHERE is_active=1 ORDER BY id')
            ctx['all_users'] = [dict(r) for r in cur.fetchall()]
            if vid != uid:
                cur.execute('SELECT username FROM users WHERE id=%s', (vid,))
                row = cur.fetchone()
                ctx['view_username'] = row['username'] if row else str(vid)
        return ctx

    def _run_auto_deduction(conn):
        if app.config.get('TESTING'):
            return
        cur = conn.cursor()
        cur.execute("""
            SELECT m.id, m.date, m.meal_time, m.status,
                   mi.ingredient_id, mi.grams, i.weight_per_cube
            FROM meals m
            JOIN meal_ingredients mi ON mi.meal_id = m.id
            JOIN ingredients i ON i.id = mi.ingredient_id
            WHERE m.status = 'upcoming'
        """)
        rows = cur.fetchall()
        if not rows:
            return

        meals_map, ing_map = {}, {}
        for r in rows:
            mid = r['id']
            if mid not in meals_map:
                meals_map[mid] = {
                    'id': mid, 'date': str(r['date']),
                    'meal_time': r['meal_time'], 'status': r['status'],
                    'ingredients': [],
                }
            meals_map[mid]['ingredients'].append(
                {'ingredient_id': r['ingredient_id'], 'grams': r['grams']}
            )
            ing_map[r['ingredient_id']] = {
                'id': r['ingredient_id'], 'weight_per_cube': r['weight_per_cube']
            }

        updates, deltas = compute_deductions(
            list(meals_map.values()), list(ing_map.values())
        )
        for meal_id, status in updates.items():
            cur.execute('UPDATE meals SET status=%s WHERE id=%s', (status, meal_id))
        for ing_id, delta in deltas.items():
            cur.execute(
                'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s',
                (delta, ing_id)
            )
        conn.commit()

    @app.post('/api/deduct')
    @login_required
    def api_deduct():
        _run_auto_deduction(_mod.get_db())
        return jsonify({'ok': True})

    # ─── 재고 API ─────────────────────────────────────────

    def _fmt_ingredient(row):
        r = dict(row)
        if r.get('created_at') is not None:
            r['created_at'] = str(r['created_at'])[:10]
        return r

    @app.get('/api/ingredients')
    @login_required
    def api_ingredients_list():
        cur = _mod.get_db().cursor()
        cur.execute('SELECT * FROM ingredients WHERE user_id=%s ORDER BY name',
                    (get_view_user_id(),))
        return jsonify([_fmt_ingredient(r) for r in cur.fetchall()])

    @app.post('/api/ingredients')
    @login_required
    def api_ingredients_add():
        d = request.get_json() or {}
        required = {'name', 'emoji', 'color', 'created_at', 'weight_per_cube', 'total_cubes'}
        if not required.issubset(d):
            return jsonify({'error': '필수 항목 누락'}), 400
        try:
            d['weight_per_cube'] = int(d['weight_per_cube'])
            d['total_cubes']     = int(d['total_cubes'])
            if d['weight_per_cube'] <= 0 or d['total_cubes'] <= 0:
                raise ValueError
        except (ValueError, TypeError):
            return jsonify({'error': '중량/개수는 양의 정수여야 합니다'}), 400
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute("""
            INSERT INTO ingredients
              (name, emoji, color, created_at, weight_per_cube, total_cubes, current_cubes, user_id)
            VALUES (%(name)s, %(emoji)s, %(color)s, %(created_at)s,
                    %(weight_per_cube)s, %(total_cubes)s, %(total_cubes)s, %(user_id)s)
        """, {**d, 'user_id': session['user_id']})
        conn.commit()
        cur.execute('SELECT * FROM ingredients WHERE id=%s', (cur.lastrowid,))
        ing = dict(cur.fetchone())
        if not app.config.get('TESTING'):
            cfg = _db.load_config()
            mc = minio_storage.get_minio_client(cfg)
            if mc:
                bucket = cfg.get('minio', {}).get('bucket', 'babymeal')
                minio_storage.ensure_bucket(mc, bucket)
                img_url = save_emoji_image(mc, bucket, ing['emoji'])
                if img_url:
                    cur.execute('UPDATE ingredients SET image_url=%s WHERE id=%s', (img_url, ing['id']))
                    conn.commit()
                    ing['image_url'] = img_url
        return jsonify(_fmt_ingredient(ing)), 201

    @app.put('/api/ingredients/<int:ing_id>')
    @login_required
    def api_ingredients_update(ing_id):
        d    = request.get_json()
        conn = _mod.get_db()
        cur  = conn.cursor()
        UPDATABLE_FIELDS = {'name', 'emoji', 'color', 'created_at', 'weight_per_cube', 'total_cubes'}
        d = {k: v for k, v in d.items() if k in UPDATABLE_FIELDS}
        if not d:
            return jsonify({'error': 'no valid fields'}), 400
        sets = ', '.join(f'{k}=%({k})s' for k in d)
        cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s AND user_id=%(uid)s',
                    {**d, 'id': ing_id, 'uid': get_view_user_id()})
        conn.commit()
        cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))
        ing = dict(cur.fetchone())
        if not app.config.get('TESTING') and 'emoji' in d:
            cfg = _db.load_config()
            mc = minio_storage.get_minio_client(cfg)
            if mc:
                bucket = cfg.get('minio', {}).get('bucket', 'babymeal')
                minio_storage.ensure_bucket(mc, bucket)
                img_url = save_emoji_image(mc, bucket, ing['emoji'])
                if img_url:
                    cur.execute('UPDATE ingredients SET image_url=%s WHERE id=%s', (img_url, ing['id']))
                    conn.commit()
                    ing['image_url'] = img_url
        return jsonify(_fmt_ingredient(ing))

    @app.delete('/api/ingredients/<int:ing_id>')
    @login_required
    def api_ingredients_delete(ing_id):
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('DELETE FROM ingredients WHERE id=%s AND user_id=%s',
                    (ing_id, get_view_user_id()))
        conn.commit()
        return jsonify({'ok': True})

    @app.post('/api/ingredients/<int:ing_id>/adjust')
    @login_required
    def api_ingredients_adjust(ing_id):
        body = request.get_json() or {}
        try:
            delta = int(body['delta'])
        except (KeyError, TypeError, ValueError):
            return jsonify({'error': 'delta는 정수여야 합니다'}), 400
        conn  = _mod.get_db()
        cur   = conn.cursor()
        cur.execute(
            'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s AND user_id=%s',
            (delta, ing_id, get_view_user_id())
        )
        conn.commit()
        cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))
        return jsonify(_fmt_ingredient(cur.fetchone()))

    # ─── 이모지 이미지 API ────────────────────────────────────

    @app.get('/api/emoji/<codepoint>')
    @login_required
    def api_emoji_image(codepoint):
        cfg = _db.load_config()
        mc = minio_storage.get_minio_client(cfg)
        bucket = cfg.get('minio', {}).get('bucket', 'babymeal')
        data, ct = minio_storage.get_bytes(mc, bucket, f'emoji/{codepoint}.png')
        if data:
            resp = make_response(data)
            resp.headers['Content-Type'] = ct or 'image/png'
            resp.headers['Cache-Control'] = 'public, max-age=604800'
            return resp
        return '', 404

    @app.post('/api/admin/switch-user')
    @admin_required
    def api_admin_switch_user():
        d = request.get_json() or {}
        uid = d.get('user_id')
        if not uid:
            return jsonify({'error': 'user_id 필요'}), 400
        conn = _mod.get_db()
        cur = conn.cursor()
        cur.execute('SELECT id, username FROM users WHERE id=%s AND is_active=1', (uid,))
        user = cur.fetchone()
        if not user:
            return jsonify({'error': '존재하지 않는 사용자'}), 400
        session['view_as_user_id'] = user['id']
        return jsonify({'username': user['username']})

    @app.delete('/api/admin/switch-user')
    @admin_required
    def api_admin_switch_user_reset():
        session['view_as_user_id'] = session['user_id']
        return jsonify({'ok': True})

    # ─── 식단 API ─────────────────────────────────────────

    def _meal_with_ingredients(conn, meal_id):
        cur = conn.cursor()
        cur.execute('SELECT * FROM meals WHERE id=%s', (meal_id,))
        meal = dict(cur.fetchone())
        meal['date'] = str(meal['date'])
        cur.execute("""
            SELECT mi.ingredient_id, mi.grams, i.name, i.emoji, i.weight_per_cube
            FROM meal_ingredients mi
            JOIN ingredients i ON i.id = mi.ingredient_id
            WHERE mi.meal_id=%s
        """, (meal_id,))
        meal['ingredients'] = [dict(r) for r in cur.fetchall()]
        return meal

    @app.get('/api/meals')
    @login_required
    def api_meals_list():
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('SELECT id FROM meals WHERE user_id=%s ORDER BY date, meal_time',
                    (get_view_user_id(),))
        return jsonify([_meal_with_ingredients(conn, r['id']) for r in cur.fetchall()])

    @app.post('/api/meals')
    @login_required
    def api_meals_add():
        d = request.get_json() or {}
        if not d.get('date') or not d.get('meal_time'):
            return jsonify({'error': '날짜와 끼니를 입력하세요'}), 400
        if d['meal_time'] not in _VALID_MEAL_TIMES:
            return jsonify({'error': '유효하지 않은 끼니입니다'}), 400
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute(
            'INSERT INTO meals (date, meal_time, note, user_id) VALUES (%s, %s, %s, %s)',
            (d['date'], d['meal_time'], d.get('note', ''), session['user_id'])
        )
        meal_id = cur.lastrowid
        for mi in d.get('ingredients', []):
            cur.execute(
                'INSERT INTO meal_ingredients (meal_id, ingredient_id, grams) VALUES (%s, %s, %s)',
                (meal_id, mi['ingredient_id'], mi['grams'])
            )
        conn.commit()
        return jsonify(_meal_with_ingredients(conn, meal_id)), 201

    @app.delete('/api/meals/<int:meal_id>')
    @login_required
    def api_meals_delete(meal_id):
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('DELETE FROM meals WHERE id=%s AND user_id=%s',
                    (meal_id, get_view_user_id()))
        conn.commit()
        return jsonify({'ok': True})

    @app.post('/api/meals/<int:meal_id>/status')
    @login_required
    def api_meals_status(meal_id):
        body = request.get_json() or {}
        new_status = body.get('status')
        if new_status not in _VALID_STATUSES:
            return jsonify({'error': '유효하지 않은 상태입니다'}), 400
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('SELECT status FROM meals WHERE id=%s AND user_id=%s',
                    (meal_id, get_view_user_id()))
        row = cur.fetchone()
        if not row:
            return jsonify({'error': 'not found'}), 404
        old_status = row['status']

        if old_status in ('confirmed', 'auto-consumed') and new_status == 'skipped':
            _apply_stock_delta(conn, meal_id, direction='restore')
        elif old_status in ('upcoming', 'skipped') and new_status == 'confirmed':
            _apply_stock_delta(conn, meal_id, direction='deduct')

        cur.execute('UPDATE meals SET status=%s WHERE id=%s AND user_id=%s',
                    (new_status, meal_id, get_view_user_id()))
        conn.commit()
        return jsonify(_meal_with_ingredients(conn, meal_id))

    def _apply_stock_delta(conn, meal_id, direction):
        cur = conn.cursor()
        cur.execute("""
            SELECT mi.ingredient_id, mi.grams, i.weight_per_cube
            FROM meal_ingredients mi
            JOIN ingredients i ON i.id = mi.ingredient_id
            WHERE mi.meal_id=%s
        """, (meal_id,))
        for r in cur.fetchall():
            cubes = round(r['grams'] / r['weight_per_cube'])
            delta = -cubes if direction == 'deduct' else cubes
            cur.execute(
                'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s',
                (delta, r['ingredient_id'])
            )

    # ─── 알림 설정 API ────────────────────────────────────────

    def _ensure_notification_table(conn):
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS notification_settings (
                id TINYINT PRIMARY KEY DEFAULT 1,
                enabled TINYINT(1) NOT NULL DEFAULT 0,
                notify_hour TINYINT NOT NULL DEFAULT 8,
                notify_minute TINYINT NOT NULL DEFAULT 0
            )
        """)
        cur.execute("INSERT IGNORE INTO notification_settings (id) VALUES (1)")
        conn.commit()

    def _get_notification_settings_row():
        conn = _db.get_connection()
        try:
            _ensure_notification_table(conn)
            cur = conn.cursor()
            cur.execute("SELECT enabled, notify_hour, notify_minute FROM notification_settings WHERE id=1")
            return cur.fetchone() or {'enabled': 0, 'notify_hour': 8, 'notify_minute': 0}
        finally:
            conn.close()

    @app.get('/api/notification-settings')
    @admin_required
    def api_notification_get():
        row = _get_notification_settings_row()
        return jsonify({
            'enabled':       bool(row['enabled']),
            'notify_hour':   row['notify_hour'],
            'notify_minute': row['notify_minute'],
        })

    @app.post('/api/notification-settings/test')
    @admin_required
    def api_notification_test():
        cfg = _db.load_config()
        webhook = cfg.get('discord_webhook', '').strip()
        if not webhook:
            return jsonify({'error': 'config.json에 discord_webhook이 비어 있습니다'}), 400
        try:
            payload = json.dumps({"content": "🍼 **치밀한 이유식** — 디스코드 알림 테스트입니다 ✅"}).encode("utf-8")
            req = urllib.request.Request(
                webhook, data=payload,
                headers={"Content-Type": "application/json"}, method="POST",
            )
            urllib.request.urlopen(req, timeout=10)
        except Exception as e:
            return jsonify({'error': f'전송 실패: {e}'}), 500
        return jsonify({'ok': True})

    @app.put('/api/notification-settings')
    @admin_required
    def api_notification_put():
        d = request.get_json() or {}
        try:
            enabled = bool(d.get('enabled', False))
            hour    = int(d.get('notify_hour', 8))
            minute  = int(d.get('notify_minute', 0))
            if not (0 <= hour <= 23 and 0 <= minute <= 59):
                raise ValueError
        except (TypeError, ValueError):
            return jsonify({'error': '유효하지 않은 시간입니다'}), 400

        conn = _db.get_connection()
        try:
            _ensure_notification_table(conn)
            cur = conn.cursor()
            cur.execute(
                "UPDATE notification_settings SET enabled=%s, notify_hour=%s, notify_minute=%s WHERE id=1",
                (int(enabled), hour, minute),
            )
            conn.commit()
        finally:
            conn.close()

        _reschedule_notification(enabled, hour, minute)
        return jsonify({'ok': True, 'enabled': enabled, 'notify_hour': hour, 'notify_minute': minute})

    # ─── APScheduler ─────────────────────────────────────────

    def _send_low_stock_notification():
        cfg = _db.load_config()
        webhook = cfg.get('discord_webhook', '').strip()
        if not webhook:
            return
        conn = _db.get_connection()
        try:
            cur = conn.cursor()
            cur.execute(
                "SELECT name, emoji, current_cubes FROM ingredients WHERE current_cubes <= 3 ORDER BY current_cubes"
            )
            items = cur.fetchall()
        finally:
            conn.close()

        if not items:
            return

        lines = ["🚨 **재고 부족 알림** — 치밀한 이유식\n"]
        for item in items:
            bar = "▓" * item['current_cubes'] + "░" * (3 - item['current_cubes'])
            lines.append(f"{item['emoji']} **{item['name']}** — {item['current_cubes']}개 남음  `{bar}`")
        lines.append("\n> 재고 탭에서 큐브를 보충해주세요 🍼")
        message = "\n".join(lines)

        try:
            payload = json.dumps({"content": message}).encode("utf-8")
            req = urllib.request.Request(
                webhook, data=payload,
                headers={"Content-Type": "application/json"}, method="POST",
            )
            urllib.request.urlopen(req, timeout=10)
        except Exception as e:
            logging.warning("Discord 알림 실패: %s", e)

    if not app.config.get('TESTING'):  # noqa: SIM102
        try:
            from apscheduler.schedulers.background import BackgroundScheduler
            from apscheduler.triggers.cron import CronTrigger

            _scheduler = BackgroundScheduler(daemon=True)
            _scheduler.start()

            def _reschedule_notification(enabled, hour, minute):
                _scheduler.remove_all_jobs()
                if enabled:
                    _scheduler.add_job(
                        _send_low_stock_notification,
                        CronTrigger(hour=hour, minute=minute),
                        id='low_stock_notify',
                        replace_existing=True,
                    )

            # 앱 시작 시 DB에서 설정 읽어 스케줄 복원
            try:
                row = _get_notification_settings_row()
                _reschedule_notification(row['enabled'], row['notify_hour'], row['notify_minute'])
            except Exception as e:
                logging.warning("알림 스케줄 복원 실패: %s", e)

        except ImportError:
            logging.warning("APScheduler 미설치 — 알림 스케줄링 비활성화")
            def _reschedule_notification(enabled, hour, minute):
                pass
    else:
        def _reschedule_notification(enabled, hour, minute):
            pass

    return app


# ─── CLI 진입점 ───────────────────────────────────────────

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='치밀한 이유식')
    parser.add_argument('--port',  type=int, default=8990)
    parser.add_argument('--host',  default='0.0.0.0')
    parser.add_argument('--debug', action='store_true')
    parser.add_argument('--init-admin', action='store_true',
                        help='관리자 계정 초기 생성')
    args = parser.parse_args()

    cfg = _db.load_config()

    if args.init_admin:
        import getpass
        uname = input('관리자 아이디: ').strip()
        pw    = getpass.getpass('비밀번호: ')
        phash = generate_password_hash(pw)
        conn  = _db.get_connection(cfg)
        cur   = conn.cursor()
        cur.execute(
            'INSERT INTO users (username, password_hash, is_admin) VALUES (%s, %s, 1)',
            (uname, phash)
        )
        conn.commit()
        conn.close()
        print(f'관리자 {uname!r} 계정 생성 완료')
        sys.exit(0)

    app  = create_app({'SECRET_KEY': cfg.get('secret_key', 'dev')})
    port = cfg.get('port', args.port)
    app.run(host=args.host, port=port, debug=args.debug)
