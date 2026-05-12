#!/usr/bin/env python3
import sys, os, json, argparse, secrets, logging
from datetime import datetime, timedelta
from pathlib import Path
from functools import wraps

PROJECT_ROOT = str(Path(__file__).resolve().parent.parent)
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from flask import (
    Flask, render_template, request, redirect,
    url_for, session, jsonify, flash, g,
)
from werkzeug.security import check_password_hash, generate_password_hash

import db as _db
from deduction import compute_deductions

# Module-level references exposed for patching in tests
get_connection = _db.get_connection


def get_db():
    """Module-level get_db; replaced per-app by create_app for proper g-scoping."""
    raise RuntimeError('get_db called before create_app')


def create_app(config=None):
    app = Flask(__name__)
    app.config['SECRET_KEY'] = 'dev'
    app.config['TESTING'] = False

    if config:
        app.config.update(config)

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
        return render_template('inventory.html',
                               username=session.get('username'))

    @app.route('/schedule')
    @login_required
    def schedule_page():
        _run_auto_deduction(_mod.get_db())
        return render_template('schedule.html',
                               username=session.get('username'))

    # ─── 자동 차감 ────────────────────────────────────────

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
            conn.execute('UPDATE meals SET status=%s WHERE id=%s', (status, meal_id))
        for ing_id, delta in deltas.items():
            conn.execute(
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

    @app.get('/api/ingredients')
    @login_required
    def api_ingredients_list():
        cur = _mod.get_db().cursor()
        cur.execute('SELECT * FROM ingredients ORDER BY name')
        return jsonify([dict(r) for r in cur.fetchall()])

    @app.post('/api/ingredients')
    @login_required
    def api_ingredients_add():
        d = request.get_json()
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute("""
            INSERT INTO ingredients
              (name, emoji, color, created_at, weight_per_cube, total_cubes, current_cubes)
            VALUES (%(name)s, %(emoji)s, %(color)s, %(created_at)s,
                    %(weight_per_cube)s, %(total_cubes)s, %(total_cubes)s)
        """, d)
        conn.commit()
        cur.execute('SELECT * FROM ingredients WHERE id=%s', (cur.lastrowid,))
        return jsonify(dict(cur.fetchone())), 201

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
        cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s', {**d, 'id': ing_id})
        conn.commit()
        cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))
        return jsonify(dict(cur.fetchone()))

    @app.delete('/api/ingredients/<int:ing_id>')
    @login_required
    def api_ingredients_delete(ing_id):
        conn = _mod.get_db()
        conn.execute('DELETE FROM ingredients WHERE id=%s', (ing_id,))
        conn.commit()
        return jsonify({'ok': True})

    @app.post('/api/ingredients/<int:ing_id>/adjust')
    @login_required
    def api_ingredients_adjust(ing_id):
        delta = request.get_json()['delta']
        conn  = _mod.get_db()
        conn.execute(
            'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s',
            (delta, ing_id)
        )
        conn.commit()
        cur = conn.cursor()
        cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))
        return jsonify(dict(cur.fetchone()))

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
        cur.execute('SELECT id FROM meals ORDER BY date, meal_time')
        return jsonify([_meal_with_ingredients(conn, r['id']) for r in cur.fetchall()])

    @app.post('/api/meals')
    @login_required
    def api_meals_add():
        d    = request.get_json()
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute(
            'INSERT INTO meals (date, meal_time, note) VALUES (%s, %s, %s)',
            (d['date'], d['meal_time'], d.get('note', ''))
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
        conn.execute('DELETE FROM meals WHERE id=%s', (meal_id,))
        conn.commit()
        return jsonify({'ok': True})

    @app.post('/api/meals/<int:meal_id>/status')
    @login_required
    def api_meals_status(meal_id):
        new_status = request.get_json()['status']
        conn = _mod.get_db()
        cur  = conn.cursor()
        cur.execute('SELECT status FROM meals WHERE id=%s', (meal_id,))
        row = cur.fetchone()
        if not row:
            return jsonify({'error': 'not found'}), 404
        old_status = row['status']

        if old_status in ('confirmed', 'auto-consumed') and new_status == 'skipped':
            _apply_stock_delta(conn, meal_id, direction='restore')
        elif old_status in ('upcoming', 'skipped') and new_status == 'confirmed':
            _apply_stock_delta(conn, meal_id, direction='deduct')

        conn.execute('UPDATE meals SET status=%s WHERE id=%s', (new_status, meal_id))
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
            conn.execute(
                'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s',
                (delta, r['ingredient_id'])
            )

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
