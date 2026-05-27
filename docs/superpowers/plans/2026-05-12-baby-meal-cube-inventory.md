# 치밀한 이유식 — 큐브 재고 관리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이유식 큐브 재고를 식단표와 자동 연동하여 차감·경고·유통기한 관리를 제공하는 Flask 웹앱 구축 및 NAS 자동 배포

**Architecture:** Python + Flask (백엔드 API + Jinja2 렌더링), Alpine.js (프론트 반응형), MySQL 192.168.0.34 `babymeal` DB, session 기반 로그인(CSRF·브루트포스 방지), GitHub Actions → Synology NAS self-hosted runner 배포. animation 프로젝트와 동일한 구조·배포 파이프라인.

**Tech Stack:** Python 3, Flask, PyMySQL, Werkzeug, Alpine.js (CDN), Vanilla CSS (CSS Variables), Pretendard font, pytest, GitHub Actions + self-hosted runner

---

## 개발 스펙 (animation 프로젝트와 동일)

| 카테고리 | 선택 | 비고 |
|---|---|---|
| 백엔드 | Python 3 + Flask | animation 동일 |
| DB | MySQL 192.168.0.34 / `babymeal` | animation 동일 서버, DB 분리 |
| 인증 | session + Werkzeug hash + CSRF + 브루트포스 방지 | animation 동일 패턴 |
| 프론트 | Alpine.js CDN | animation 동일 |
| CSS | Vanilla + CSS Variables (파스텔 테마) | animation 동일 구조 |
| 폰트 | Pretendard CDN | animation 동일 |
| 테스트 | pytest + unittest.mock | animation 동일 |
| 배포 | GitHub Actions → NAS self-hosted runner | animation 동일 |
| 서비스 | systemd, 포트 8990 | animation(8989)과 충돌 없음 |
| NAS 경로 | `/volume1/DR_DATA1/babyMeal/` | animation 동일 패턴 |

---

## DB 스키마 (이미 생성 완료)

```
babymeal DB
├── users            ← 로그인 계정
├── ingredients      ← 재료 재고
├── meals            ← 식단 스케줄
└── meal_ingredients ← 식단-재료 매핑
```

---

## File Structure

```
babyMeal/
  web/
    app.py                  - Flask 앱 전체 (라우트 + API + 인증)
    templates/
      _base.html            - 탭 네비게이션 레이아웃 (로그인 시에만 표시)
      login.html            - 로그인 페이지
      inventory.html        - 재고현황 탭
      schedule.html         - 식단표 탭
    static/
      style.css             - CSS Variables 파스텔 테마 + 컴포넌트
      app.js                - Alpine.js 컴포넌트 + api() 헬퍼
  db.py                     - MySQL 연결 유틸 (animation db.py 동일 패턴)
  deduction.py              - 자동 차감 순수 로직 (DB 의존 없음)
  config.json               - 실 설정 (gitignore)
  config.example.json       - 설정 예시
  requirements.txt
  babymeal.service
  deploy.sh
  .github/workflows/deploy.yml
  tests/
    test_deduction.py       - 자동 차감 로직 유닛 테스트 (mock 불필요)
    test_api.py             - Flask API 테스트 (DB mock)
  .gitignore
```

---

### Task 1: 프로젝트 초기 구조

**Files:**
- Create: `.gitignore`, `requirements.txt`, `config.example.json`

- [ ] **Step 1: 디렉토리 생성**

```bash
mkdir -p web/templates web/static tests .github/workflows
```

- [ ] **Step 2: .gitignore 작성**

`.gitignore`:
```
config.json
logs/
__pycache__/
*.pyc
.DS_Store
*.log
.pytest_cache/
```

- [ ] **Step 3: requirements.txt 작성**

`requirements.txt`:
```
flask>=2.3
pymysql>=1.1
werkzeug>=2.3
```

- [ ] **Step 4: config.example.json 작성**

`config.example.json`:
```json
{
  "db": {
    "host": "192.168.0.34",
    "port": 3306,
    "user": "root",
    "password": "YOUR_DB_PASSWORD",
    "database": "babymeal"
  },
  "secret_key": "CHANGE_ME_RANDOM_STRING",
  "port": 8990,
  "debug": false,
  "discord_webhook": "",
  "web": {
    "trusted_proxies": []
  }
}
```

- [ ] **Step 5: 커밋**

```bash
git init
git add .gitignore requirements.txt config.example.json
git commit -m "chore: project scaffold"
```

---

### Task 2: db.py (animation 동일 패턴, MySQL)

**Files:**
- Create: `db.py`

- [ ] **Step 1: db.py 작성**

`db.py`:
```python
"""DB 연결 유틸리티 — animation db.py와 동일 패턴"""

import json
import pymysql
from pathlib import Path


def load_config(config_path=None):
    if config_path is None:
        config_path = Path(__file__).parent / "config.json"
    with open(config_path, encoding="utf-8") as f:
        return json.load(f)


def get_connection(config=None):
    if config is None:
        config = load_config()
    db = config["db"]
    return pymysql.connect(
        host=db["host"],
        port=db["port"],
        user=db["user"],
        password=db["password"],
        database=db["database"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
    )
```

- [ ] **Step 2: 커밋**

```bash
git add db.py
git commit -m "feat: add MySQL db connection util (animation 패턴)"
```

---

### Task 3: 자동 차감 로직 (deduction.py)

**Files:**
- Create: `deduction.py`
- Create: `tests/test_deduction.py`

순수 함수 — DB·Flask 의존 없음, 테스트가 mock 없이 가능.

- [ ] **Step 1: 테스트 먼저 작성**

`tests/test_deduction.py`:
```python
import pytest
from datetime import datetime
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from deduction import compute_deductions, MEAL_HOURS


def meal(mid, date, meal_time, status='upcoming', ingredients=None):
    return {'id': mid, 'date': date, 'meal_time': meal_time,
            'status': status, 'ingredients': ingredients or []}


def ing(iid, weight_per_cube=20):
    return {'id': iid, 'weight_per_cube': weight_per_cube}


def test_past_upcoming_meal_is_auto_consumed():
    m = meal(1, '2020-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert updates[1] == 'auto-consumed'
    assert deltas[10] == -1


def test_future_meal_not_deducted():
    m = meal(2, '2099-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert 2 not in updates
    assert 10 not in deltas


def test_already_consumed_skipped():
    m = meal(3, '2020-01-01', 'morning', status='auto-consumed',
             ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert 3 not in updates


def test_grams_to_cubes_rounds():
    m = meal(4, '2020-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 40}])
    updates, deltas = compute_deductions([m], [ing(10, weight_per_cube=20)])
    assert deltas[10] == -2


def test_multiple_meals_accumulate():
    m1 = meal(5, '2020-01-01', 'morning', ingredients=[{'ingredient_id': 10, 'grams': 20}])
    m2 = meal(6, '2020-01-02', 'lunch',   ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m1, m2], [ing(10)])
    assert deltas[10] == -2


def test_skipped_not_deducted():
    m = meal(7, '2020-01-01', 'morning', status='skipped',
             ingredients=[{'ingredient_id': 10, 'grams': 20}])
    updates, deltas = compute_deductions([m], [ing(10)])
    assert 7 not in updates
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

```bash
python -m pytest tests/test_deduction.py -v
```
Expected: FAIL — "No module named 'deduction'"

- [ ] **Step 3: deduction.py 구현**

`deduction.py`:
```python
from datetime import datetime

MEAL_HOURS = {'morning': 8, 'lunch': 12, 'snack': 15, 'dinner': 18}


def is_overdue(date_str, meal_time):
    hour = MEAL_HOURS[meal_time]
    meal_dt = datetime.strptime(date_str, '%Y-%m-%d').replace(hour=hour)
    return meal_dt < datetime.now()


def compute_deductions(meals, ingredients):
    """
    meals:       [{'id', 'date', 'meal_time', 'status', 'ingredients': [{'ingredient_id', 'grams'}]}]
    ingredients: [{'id', 'weight_per_cube'}]
    Returns:
      updates: {meal_id: 'auto-consumed'}
      deltas:  {ingredient_id: negative_int}
    """
    ing_map = {i['id']: i for i in ingredients}
    updates, deltas = {}, {}

    for meal in meals:
        if meal['status'] != 'upcoming':
            continue
        if not is_overdue(meal['date'], meal['meal_time']):
            continue
        updates[meal['id']] = 'auto-consumed'
        for mi in meal.get('ingredients', []):
            i = ing_map.get(mi['ingredient_id'])
            if not i:
                continue
            cubes = round(mi['grams'] / i['weight_per_cube'])
            deltas[mi['ingredient_id']] = deltas.get(mi['ingredient_id'], 0) - cubes

    return updates, deltas
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
python -m pytest tests/test_deduction.py -v
```
Expected: PASS (6 tests)

- [ ] **Step 5: 커밋**

```bash
git add deduction.py tests/test_deduction.py
git commit -m "feat: add pure deduction engine"
```

---

### Task 4: Flask 앱 — 인증 + API (web/app.py)

**Files:**
- Create: `web/app.py`
- Create: `tests/test_api.py`

인증 구조는 animation `web/app.py`와 동일: session, CSRF, 브루트포스 방지, `--init-admin`.

- [ ] **Step 1: 테스트 먼저 작성**

`tests/test_api.py`:
```python
import pytest
import json
from unittest.mock import patch, MagicMock
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))


def make_cursor(rows=None, lastrowid=1):
    cur = MagicMock()
    cur.fetchall.return_value = rows or []
    cur.fetchone.return_value = rows[0] if rows else None
    cur.lastrowid = lastrowid
    return cur


def make_conn(cursor):
    conn = MagicMock()
    conn.cursor.return_value = cursor
    return conn


@pytest.fixture
def app():
    with patch('web.app.get_connection'):
        from web.app import create_app
        application = create_app({'TESTING': True, 'SECRET_KEY': 'test'})
        return application


@pytest.fixture
def authed_client(app):
    client = app.test_client()
    with client.session_transaction() as sess:
        sess['logged_in'] = True
        sess['username'] = 'admin'
        sess['csrf_token'] = 'testtoken'
    return client


def test_login_page_accessible(app):
    client = app.test_client()
    resp = client.get('/login')
    assert resp.status_code == 200


def test_unauthenticated_redirects_to_login(app):
    client = app.test_client()
    resp = client.get('/')
    assert resp.status_code == 302
    assert '/login' in resp.headers['Location']


def test_api_ingredients_requires_auth(app):
    client = app.test_client()
    resp = client.get('/api/ingredients')
    assert resp.status_code == 302


def test_api_ingredients_list(authed_client):
    rows = [{'id': 1, 'name': '소고기', 'emoji': '🥩', 'color': '#C0392B',
             'created_at': '2026-05-01', 'weight_per_cube': 20,
             'total_cubes': 10, 'current_cubes': 10}]
    cur = make_cursor(rows)
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        resp = authed_client.get('/api/ingredients')
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert data[0]['name'] == '소고기'


def test_api_add_ingredient(authed_client):
    new_ing = {'id': 1, 'name': '파프리카', 'emoji': '🫑', 'color': '#E74C3C',
               'created_at': '2026-05-01', 'weight_per_cube': 10,
               'total_cubes': 8, 'current_cubes': 8}
    cur = make_cursor([new_ing], lastrowid=1)
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        resp = authed_client.post(
            '/api/ingredients',
            data=json.dumps({'name': '파프리카', 'emoji': '🫑', 'color': '#E74C3C',
                             'created_at': '2026-05-01', 'weight_per_cube': 10, 'total_cubes': 8}),
            content_type='application/json',
            headers={'X-CSRF-Token': 'testtoken'},
        )
    assert resp.status_code == 201


def test_api_adjust_stock(authed_client):
    updated = {'id': 1, 'name': '소고기', 'emoji': '🥩', 'color': '#C0392B',
               'created_at': '2026-05-01', 'weight_per_cube': 20,
               'total_cubes': 10, 'current_cubes': 7}
    cur = make_cursor([updated])
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        resp = authed_client.post(
            '/api/ingredients/1/adjust',
            data=json.dumps({'delta': -3}),
            content_type='application/json',
            headers={'X-CSRF-Token': 'testtoken'},
        )
    assert resp.status_code == 200
    assert json.loads(resp.data)['current_cubes'] == 7
```

- [ ] **Step 2: 테스트 실행하여 실패 확인**

```bash
python -m pytest tests/test_api.py -v
```
Expected: FAIL — "cannot import name 'create_app'"

- [ ] **Step 3: web/app.py 구현**

`web/app.py`:
```python
#!/usr/bin/env python3
"""치밀한 이유식 — Flask 앱 (animation 구조 동일)"""

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

# ─── App Factory ──────────────────────────────────────────

def create_app(config=None):
    app = Flask(__name__)
    app.config['SECRET_KEY'] = 'dev'
    app.config['TESTING'] = False

    if config:
        app.config.update(config)

    # ─── DB ───────────────────────────────────────────────

    def get_db():
        if 'db' not in g:
            if app.config.get('TESTING'):
                from unittest.mock import MagicMock
                g.db = MagicMock()
            else:
                g.db = _db.get_connection()
        return g.db

    # 테스트에서 패치 가능하도록 모듈 레벨 노출
    import web.app as _self
    _self.get_db = get_db

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
                if request.path.startswith('/api/'):
                    return jsonify({'error': '로그인 필요'}), 401
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

        conn = get_db()
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
        _run_auto_deduction(get_db())
        return render_template('inventory.html',
                               username=session.get('username'))

    @app.route('/schedule')
    @login_required
    def schedule_page():
        _run_auto_deduction(get_db())
        return render_template('schedule.html',
                               username=session.get('username'))

    # ─── 자동 차감 ────────────────────────────────────────

    def _run_auto_deduction(conn):
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
        _run_auto_deduction(get_db())
        return jsonify({'ok': True})

    # ─── 재고 API ─────────────────────────────────────────

    @app.get('/api/ingredients')
    @login_required
    def api_ingredients_list():
        cur = get_db().cursor()
        cur.execute('SELECT * FROM ingredients ORDER BY name')
        return jsonify([dict(r) for r in cur.fetchall()])

    @app.post('/api/ingredients')
    @login_required
    def api_ingredients_add():
        d = request.get_json()
        conn = get_db()
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
        conn = get_db()
        cur  = conn.cursor()
        sets = ', '.join(f'{k}=%({k})s' for k in d)
        cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s', {**d, 'id': ing_id})
        conn.commit()
        cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))
        return jsonify(dict(cur.fetchone()))

    @app.delete('/api/ingredients/<int:ing_id>')
    @login_required
    def api_ingredients_delete(ing_id):
        conn = get_db()
        conn.execute('DELETE FROM ingredients WHERE id=%s', (ing_id,))
        conn.commit()
        return jsonify({'ok': True})

    @app.post('/api/ingredients/<int:ing_id>/adjust')
    @login_required
    def api_ingredients_adjust(ing_id):
        delta = request.get_json()['delta']
        conn  = get_db()
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
        conn = get_db()
        cur  = conn.cursor()
        cur.execute('SELECT id FROM meals ORDER BY date, meal_time')
        return jsonify([_meal_with_ingredients(conn, r['id']) for r in cur.fetchall()])

    @app.post('/api/meals')
    @login_required
    def api_meals_add():
        d    = request.get_json()
        conn = get_db()
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
        conn = get_db()
        conn.execute('DELETE FROM meals WHERE id=%s', (meal_id,))
        conn.commit()
        return jsonify({'ok': True})

    @app.post('/api/meals/<int:meal_id>/status')
    @login_required
    def api_meals_status(meal_id):
        new_status = request.get_json()['status']
        conn = get_db()
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
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
python -m pytest tests/test_api.py -v
```
Expected: PASS (7 tests)

- [ ] **Step 5: 커밋**

```bash
git add web/app.py tests/test_api.py
git commit -m "feat: add Flask app with MySQL, session auth, CSRF, brute-force protection"
```

---

### Task 5: CSS 파스텔 디자인 시스템 (web/static/style.css)

animation CSS variables 구조 동일, 파스텔 테마 + 로그인 페이지 스타일 추가.

**Files:**
- Create: `web/static/style.css`

- [ ] **Step 1: style.css 작성**

`web/static/style.css`:
```css
/* ─── 치밀한 이유식 — Pastel Design System ─── */
@import url('https://cdn.jsdelivr.net/gh/orioncactus/pretendard/dist/web/static/pretendard.css');

:root {
  --background:     #FAFAF7;
  --card:           #FFFFFF;
  --border:         #EAE8E3;
  --border-hover:   #D4D0C8;

  --text-primary:   #2D2D2D;
  --text-secondary: #6B6B6B;
  --text-muted:     #9E9E9E;

  --accent-green:     #52C47A;
  --accent-green-bg:  #D6F5E3;
  --accent-blue:      #4BA3E3;
  --accent-blue-bg:   #D6EEFF;
  --accent-pink:      #E07A5F;
  --accent-pink-bg:   #FFE8E3;

  --warning:        #F5A623;
  --warning-bg:     #FFF3CC;
  --danger:         #E53E3E;
  --danger-bg:      #FFF0F0;
  --success:        #38A169;
  --success-bg:     #E6F7EE;
  --muted-bg:       #F0EDE8;

  --radius:         14px;
  --radius-sm:      8px;
  --topbar-height:  56px;
  font-family: 'Pretendard', system-ui, sans-serif;
}

* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: var(--background); color: var(--text-primary); font-size: 14px; line-height: 1.5; }

/* ─── 로그인 ─── */

.login-wrap {
  min-height: 100vh;
  display: flex; align-items: center; justify-content: center;
  padding: 1rem;
}

.login-box {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 2rem 1.75rem;
  width: 100%; max-width: 360px;
}

.login-brand { text-align: center; margin-bottom: 1.75rem; }
.login-brand .icon { font-size: 2.5rem; margin-bottom: .5rem; }
.login-brand h1 { font-size: 1.25rem; font-weight: 700; }
.login-brand p  { font-size: .8rem; color: var(--text-muted); margin-top: .25rem; }

.flash-error {
  background: var(--danger-bg);
  border: 1px solid #FEB2B2;
  border-radius: var(--radius-sm);
  padding: .6rem .875rem;
  font-size: .8rem;
  color: var(--danger);
  margin-bottom: 1rem;
}

/* ─── 레이아웃 ─── */

.topbar {
  position: sticky; top: 0; z-index: 100;
  background: var(--card);
  border-bottom: 1px solid var(--border);
  height: var(--topbar-height);
  display: flex; align-items: stretch;
  padding: 0 1rem; gap: 0;
}

.topbar-brand {
  display: flex; align-items: center; gap: .5rem;
  font-weight: 700; font-size: 1rem;
  color: var(--text-primary); text-decoration: none;
  padding-right: 1.5rem; flex-shrink: 0;
}

.topbar-right {
  margin-left: auto;
  display: flex; align-items: center; gap: .5rem;
}

.topbar-user { font-size: .8rem; color: var(--text-muted); }

.tab-nav { display: flex; align-items: stretch; }

.tab-btn {
  display: flex; align-items: center; gap: .35rem;
  padding: 0 1rem;
  font-size: .875rem; font-weight: 500;
  color: var(--text-secondary);
  border: none; background: none; cursor: pointer;
  border-bottom: 2px solid transparent;
  transition: color .15s, border-color .15s;
  text-decoration: none;
}
.tab-btn:hover { color: var(--text-primary); }
.tab-btn.active { color: var(--accent-green); border-bottom-color: var(--accent-green); }

.main { max-width: 640px; margin: 0 auto; padding: 1.25rem 1rem; }

/* ─── 큐브 그리드 ─── */

.cube-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: .75rem;
}
@media (min-width: 480px) { .cube-grid { grid-template-columns: repeat(3, 1fr); } }

.cube-card {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 1rem;
  display: flex; flex-direction: column; gap: .5rem;
  transition: border-color .15s;
}
.cube-card:hover { border-color: var(--border-hover); }

.cube-icon {
  width: 48px; height: 48px;
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 1.5rem;
}
.cube-name { font-weight: 600; font-size: .875rem; }
.cube-unit { font-size: .75rem; color: var(--text-muted); }

.cube-count-row {
  display: flex; align-items: center; justify-content: space-between;
  margin-top: auto; padding-top: .25rem;
}
.cube-count { font-size: 1.75rem; font-weight: 700; color: var(--text-primary); }
.cube-count.low { color: var(--danger); }

.adj-btn {
  width: 30px; height: 30px; border-radius: 50%;
  border: 1px solid var(--border); background: var(--muted-bg);
  font-size: 1rem; font-weight: 700; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  color: var(--text-secondary); transition: background .15s;
}
.adj-btn:hover { background: var(--border); }

.cube-add-btn {
  background: var(--card);
  border: 2px dashed var(--border);
  border-radius: var(--radius);
  min-height: 150px;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  gap: .5rem;
  color: var(--text-muted); font-size: .8rem; font-weight: 500;
  cursor: pointer; transition: border-color .15s, color .15s;
}
.cube-add-btn:hover { border-color: var(--accent-green); color: var(--accent-green); }

/* ─── 뱃지 ─── */

.badge {
  display: inline-flex; align-items: center; gap: .25rem;
  font-size: .7rem; font-weight: 600;
  padding: .15rem .5rem; border-radius: 999px;
}
.badge-warning { background: var(--warning-bg); color: #92550A; }
.badge-danger  { background: var(--danger-bg);  color: var(--danger); }
.badge-success { background: var(--success-bg); color: var(--success); }
.badge-muted   { background: var(--muted-bg);   color: var(--text-muted); }
.badge-blue    { background: var(--accent-blue-bg); color: #1A5FA0; }

/* ─── 재고 경고 배너 ─── */

.stock-warning {
  background: var(--danger-bg);
  border: 1px solid #FEB2B2;
  border-radius: var(--radius);
  padding: .75rem 1rem;
  display: flex; gap: .75rem; align-items: flex-start;
  margin-bottom: .75rem;
}
.stock-warning-icon  { font-size: 1.25rem; flex-shrink: 0; }
.stock-warning-title { font-weight: 600; font-size: .875rem; color: var(--danger); }
.stock-warning-body  { font-size: .8rem; color: #C53030; margin-top: .15rem; }

/* ─── 식단 스케줄러 ─── */

.date-group { margin-bottom: 1.25rem; }

.date-label {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: .5rem;
}
.date-label-text { font-weight: 600; font-size: .875rem; color: var(--text-primary); }
.date-label-text.past { color: var(--text-muted); }

.meal-row {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: .875rem 1rem;
  margin-bottom: .5rem;
}
.meal-row.skipped { opacity: .5; }

.meal-row-header {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: .5rem;
}
.meal-time-label { font-weight: 600; font-size: .875rem; }

.meal-ingredients { display: flex; flex-wrap: wrap; gap: .35rem; margin-bottom: .75rem; }
.meal-ing-chip {
  font-size: .75rem;
  background: var(--muted-bg); border: 1px solid var(--border);
  border-radius: 999px; padding: .2rem .6rem;
  color: var(--text-secondary);
}
.meal-actions { display: flex; gap: .5rem; }

/* ─── 버튼 ─── */

.btn {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .5rem 1rem;
  border-radius: var(--radius-sm);
  border: 1px solid transparent;
  font-size: .8rem; font-weight: 600;
  cursor: pointer; transition: opacity .15s;
  text-decoration: none;
}
.btn:hover { opacity: .85; }
.btn-sm     { padding: .3rem .7rem; font-size: .75rem; }
.btn-green  { background: var(--accent-green-bg); color: #1A6B3A; }
.btn-blue   { background: var(--accent-blue-bg);  color: #1A4F7A; }
.btn-muted  { background: var(--muted-bg);        color: var(--text-secondary); }
.btn-danger { background: var(--danger-bg);       color: var(--danger); }
.btn-primary {
  background: var(--accent-green); color: #fff;
  width: 100%; justify-content: center;
  padding: .75rem; font-size: .9rem;
}
.btn-add-date {
  width: 100%; padding: 1rem;
  background: var(--card);
  border: 2px dashed var(--border);
  border-radius: var(--radius);
  color: var(--text-muted); font-size: .875rem; font-weight: 500;
  cursor: pointer; transition: border-color .15s, color .15s;
}
.btn-add-date:hover { border-color: var(--accent-blue); color: var(--accent-blue); }

/* ─── 모달 ─── */

.modal-overlay {
  position: fixed; inset: 0;
  background: rgba(0,0,0,.3);
  display: flex; align-items: flex-end;
  z-index: 200;
}
@media (min-width: 480px) { .modal-overlay { align-items: center; justify-content: center; } }

.modal-box {
  background: var(--card);
  border-radius: var(--radius) var(--radius) 0 0;
  padding: 1.5rem 1rem 2rem;
  width: 100%; max-height: 90vh; overflow-y: auto;
}
@media (min-width: 480px) {
  .modal-box { border-radius: var(--radius); max-width: 460px; padding: 1.5rem; }
}
.modal-title { font-weight: 700; font-size: 1rem; margin-bottom: 1.25rem; }

/* ─── 폼 ─── */

.form-group  { margin-bottom: 1rem; }
.form-label  { font-size: .8rem; color: var(--text-secondary); margin-bottom: .35rem; display: block; }

.form-input {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  padding: .5rem .75rem;
  font-size: .875rem; font-family: inherit;
  background: var(--card); color: var(--text-primary);
  transition: border-color .15s;
}
.form-input:focus { outline: none; border-color: var(--accent-green); }

.emoji-grid { display: flex; flex-wrap: wrap; gap: .4rem; }
.emoji-btn {
  width: 36px; height: 36px;
  border-radius: var(--radius-sm);
  background: var(--muted-bg);
  border: 2px solid transparent;
  font-size: 1.1rem; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
}
.emoji-btn.selected { border-color: var(--accent-green); background: var(--accent-green-bg); }

.color-grid { display: flex; flex-wrap: wrap; gap: .4rem; }
.color-btn {
  width: 28px; height: 28px; border-radius: 50%;
  border: 2px solid transparent; cursor: pointer; transition: transform .15s;
}
.color-btn.selected { border-color: var(--text-primary); transform: scale(1.15); }

.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: .75rem; }

.ing-row { display: flex; align-items: center; gap: .75rem; margin-bottom: .5rem; }
.ing-row-emoji { font-size: 1.2rem; width: 28px; flex-shrink: 0; }
.ing-row-name  { flex: 1; font-size: .875rem; }
.ing-row-input {
  width: 64px; border: 1px solid var(--border);
  border-radius: var(--radius-sm); padding: .35rem .5rem;
  text-align: right; font-size: .875rem; font-family: inherit;
  background: var(--card); color: var(--text-primary);
}
.ing-row-input:focus { outline: none; border-color: var(--accent-blue); }
.ing-row-unit { font-size: .75rem; color: var(--text-muted); width: 14px; }

.form-actions { display: flex; gap: .75rem; margin-top: 1.25rem; }
.form-actions .btn { flex: 1; justify-content: center; }

/* ─── 빈 상태 ─── */

.empty-state { text-align: center; padding: 3rem 1rem; color: var(--text-muted); }
.empty-state-icon { font-size: 3rem; margin-bottom: .75rem; }
.empty-state-text { font-size: .875rem; }
```

- [ ] **Step 2: 커밋**

```bash
git add web/static/style.css
git commit -m "feat: add pastel CSS design system with login styles"
```

---

### Task 6: Alpine.js (web/static/app.js)

**Files:**
- Create: `web/static/app.js`

- [ ] **Step 1: app.js 작성**

`web/static/app.js`:
```js
/* ─── 치밀한 이유식 — Alpine.js Components ─── */

// ─── API Helper (animation 동일 패턴) ───
async function api(url, options = {}) {
    const defaults = {
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': window._csrfToken || '',
        },
    };
    const opts = { ...defaults, ...options };
    if (options.headers) opts.headers = { ...defaults.headers, ...options.headers };
    if (opts.body && typeof opts.body === 'object') opts.body = JSON.stringify(opts.body);
    let resp;
    try { resp = await fetch(url, opts); }
    catch (e) { console.error('API 오류:', url, e); return null; }
    if (resp.status === 401) { window.location.href = '/login'; return null; }
    try { return await resp.json(); } catch { return null; }
}

// ─── 재고현황 ───
function inventoryPage() {
    return {
        ingredients: [],
        showAddModal: false,
        editTarget: null,

        async init() {
            await api('/api/deduct', { method: 'POST' });
            await this.load();
        },

        async load() {
            this.ingredients = await api('/api/ingredients') || [];
        },

        get lowStockItems() {
            return this.ingredients.filter(i => i.current_cubes <= 3);
        },

        expiryStatus(createdAt) {
            const days = Math.floor((Date.now() - new Date(createdAt)) / 86400000);
            if (days > 30) return 'danger';
            if (days >= 14) return 'warning';
            return 'fresh';
        },

        expiryDays(createdAt) {
            return Math.floor((Date.now() - new Date(createdAt)) / 86400000);
        },

        async adjust(id, delta) {
            const updated = await api(`/api/ingredients/${id}/adjust`, { method: 'POST', body: { delta } });
            if (updated) {
                const idx = this.ingredients.findIndex(i => i.id === id);
                if (idx !== -1) this.ingredients[idx] = updated;
            }
        },

        openEdit(ing) { this.editTarget = { ...ing }; this.showAddModal = true; },
        openAdd()     { this.editTarget = null;        this.showAddModal = true; },

        async onSaved() {
            this.showAddModal = false;
            this.editTarget = null;
            await this.load();
        },
    };
}

// ─── 재료 모달 ───
const PRESET_EMOJIS = ['🥩','🐟','🥕','🥦','🌽','🍠','🥬','🫑','🧅','🍗','🥚','🧀','🍖','🫛','🥑'];
const PRESET_COLORS = ['#C0392B','#E67E22','#F1C40F','#27AE60','#2980B9','#8E44AD','#1ABC9C','#E74C3C'];

function ingredientModal(editTarget) {
    return {
        form: {
            name:           editTarget?.name           || '',
            emoji:          editTarget?.emoji          || '🥩',
            color:          editTarget?.color          || '#C0392B',
            created_at:     editTarget?.created_at     || new Date().toISOString().split('T')[0],
            weight_per_cube: editTarget?.weight_per_cube || 20,
            total_cubes:    editTarget?.total_cubes    || 10,
        },
        editId:       editTarget?.id || null,
        presetEmojis: PRESET_EMOJIS,
        presetColors: PRESET_COLORS,

        async submit() {
            if (this.editId) {
                await api(`/api/ingredients/${this.editId}`, { method: 'PUT', body: this.form });
            } else {
                await api('/api/ingredients', { method: 'POST', body: this.form });
            }
            this.$dispatch('saved');
        },
    };
}

// ─── 식단표 ───
const MEAL_LABELS = { morning:'아침', lunch:'점심', snack:'간식', dinner:'저녁' };
const MEAL_ORDER  = ['morning','lunch','snack','dinner'];

function schedulePage() {
    return {
        meals: [],
        ingredients: [],
        showAddModal: false,
        addDefaultDate: '',

        async init() {
            await api('/api/deduct', { method: 'POST' });
            await this.load();
        },

        async load() {
            [this.meals, this.ingredients] = await Promise.all([
                api('/api/meals')       || [],
                api('/api/ingredients') || [],
            ]);
        },

        get groupedMeals() {
            const g = {};
            for (const m of this.meals) {
                if (!g[m.date]) g[m.date] = [];
                g[m.date].push(m);
            }
            for (const d in g) {
                g[d].sort((a, b) => MEAL_ORDER.indexOf(a.meal_time) - MEAL_ORDER.indexOf(b.meal_time));
            }
            return g;
        },

        get sortedDates() { return Object.keys(this.groupedMeals).sort(); },

        dateLabel(dateStr) {
            const d    = new Date(dateStr + 'T00:00:00');
            const today = new Date(); today.setHours(0,0,0,0);
            const diff  = Math.round((d - today) / 86400000);
            if (diff === 0) return '오늘';
            if (diff === 1) return '내일';
            return d.toLocaleDateString('ko-KR', { month:'long', day:'numeric', weekday:'short' });
        },

        isPast(dateStr) { return new Date(dateStr + 'T23:59:59') < new Date(); },

        mealLabel(t) { return MEAL_LABELS[t] || t; },

        statusBadge(s) {
            return {
                upcoming:        { cls:'badge-blue',    text:'예정' },
                'auto-consumed': { cls:'badge-success', text:'자동 차감됨' },
                confirmed:       { cls:'badge-success', text:'먹었어요 ✅' },
                skipped:         { cls:'badge-muted',   text:'건너뜀' },
            }[s] || { cls:'badge-muted', text:s };
        },

        async setStatus(meal, newStatus) {
            const updated = await api(`/api/meals/${meal.id}/status`,
                { method:'POST', body:{ status: newStatus } });
            if (updated) {
                const idx = this.meals.findIndex(m => m.id === meal.id);
                if (idx !== -1) this.meals[idx] = updated;
                this.ingredients = await api('/api/ingredients') || [];
            }
        },

        openAddMeal(date = '') {
            this.addDefaultDate = date || new Date().toISOString().split('T')[0];
            this.showAddModal = true;
        },

        async onMealSaved() { this.showAddModal = false; await this.load(); },
    };
}

// ─── 식단 추가 모달 ───
function mealModal(defaultDate, ingredients) {
    return {
        date:      defaultDate || new Date().toISOString().split('T')[0],
        mealTime: 'morning',
        grams:    {},
        mealTimes: [
            { value:'morning', label:'아침' },
            { value:'lunch',   label:'점심' },
            { value:'snack',   label:'간식' },
            { value:'dinner',  label:'저녁' },
        ],
        ingredients,

        get hasIngredients() { return Object.values(this.grams).some(g => g > 0); },

        async submit() {
            const items = Object.entries(this.grams)
                .filter(([, g]) => g > 0)
                .map(([id, grams]) => ({ ingredient_id: parseInt(id), grams }));
            if (!items.length) return;
            await api('/api/meals', {
                method:'POST',
                body:{ date: this.date, meal_time: this.mealTime, ingredients: items }
            });
            this.$dispatch('meal-saved');
        },
    };
}
```

- [ ] **Step 2: 커밋**

```bash
git add web/static/app.js
git commit -m "feat: add Alpine.js components with CSRF header injection"
```

---

### Task 7: HTML 템플릿 4개

**Files:**
- Create: `web/templates/login.html`
- Create: `web/templates/_base.html`
- Create: `web/templates/inventory.html`
- Create: `web/templates/schedule.html`

- [ ] **Step 1: login.html 작성**

`web/templates/login.html`:
```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>로그인 — 치밀한 이유식</title>
  <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}?v=1">
</head>
<body>
<div class="login-wrap">
  <div class="login-box">
    <div class="login-brand">
      <div class="icon">🍼</div>
      <h1>치밀한 이유식</h1>
      <p>큐브 재고 관리</p>
    </div>

    {% with messages = get_flashed_messages(with_categories=true) %}
      {% for category, message in messages %}
        <div class="flash-error">{{ message }}</div>
      {% endfor %}
    {% endwith %}

    <form method="POST" action="{{ url_for('login_page') }}">
      <div class="form-group">
        <label class="form-label">아이디</label>
        <input type="text" name="username" class="form-input"
               placeholder="admin" autofocus required>
      </div>
      <div class="form-group">
        <label class="form-label">비밀번호</label>
        <input type="password" name="password" class="form-input"
               placeholder="비밀번호를 입력하세요" required>
      </div>
      <button type="submit" class="btn btn-primary">로그인</button>
    </form>
  </div>
</div>
</body>
</html>
```

- [ ] **Step 2: _base.html 작성**

`web/templates/_base.html`:
```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{% block title %}치밀한 이유식{% endblock %}</title>
  <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}?v=1">
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
  <script src="{{ url_for('static', filename='app.js') }}?v=1"></script>
  <script>window._csrfToken = {{ csrf_token()|tojson }};</script>
</head>
<body>

<header class="topbar">
  <a href="/" class="topbar-brand">
    <span>🍼</span><span>치밀한 이유식</span>
  </a>
  <nav class="tab-nav">
    <a href="/"         class="tab-btn {% if active_tab == 'inventory' %}active{% endif %}">🧊 재고현황</a>
    <a href="/schedule" class="tab-btn {% if active_tab == 'schedule'  %}active{% endif %}">📅 식단표</a>
  </nav>
  <div class="topbar-right">
    <span class="topbar-user">{{ username }}</span>
    <a href="/logout" class="btn btn-sm btn-muted">로그아웃</a>
  </div>
</header>

<main class="main">
  {% block content %}{% endblock %}
</main>

</body>
</html>
```

- [ ] **Step 3: inventory.html 작성**

`web/templates/inventory.html`:
```html
{% extends "_base.html" %}
{% set active_tab = 'inventory' %}
{% block title %}재고현황 — 치밀한 이유식{% endblock %}

{% block content %}
<div x-data="inventoryPage()" x-init="init()">

  <template x-if="lowStockItems.length > 0">
    <div class="stock-warning">
      <span class="stock-warning-icon">🚨</span>
      <div>
        <p class="stock-warning-title">재고 부족 알림</p>
        <p class="stock-warning-body">
          <template x-for="i in lowStockItems" :key="i.id">
            <span x-text="`${i.emoji} ${i.name} (${i.current_cubes}개 남음)  `"></span>
          </template>
        </p>
      </div>
    </div>
  </template>

  <div class="cube-grid">
    <template x-for="ing in ingredients" :key="ing.id">
      <div class="cube-card">
        <div style="display:flex;align-items:flex-start;justify-content:space-between;">
          <div class="cube-icon" :style="`background-color:${ing.color}22`" x-text="ing.emoji"></div>
          <button class="btn btn-sm btn-muted" @click="openEdit(ing)" style="padding:.2rem .5rem;">✏️</button>
        </div>
        <div>
          <p class="cube-name" x-text="ing.name"></p>
          <p class="cube-unit" x-text="`${ing.weight_per_cube}g / 큐브`"></p>
        </div>
        <template x-if="expiryStatus(ing.created_at) === 'warning'">
          <span class="badge badge-warning" x-text="`⚠️ ${expiryDays(ing.created_at)}일 경과`"></span>
        </template>
        <template x-if="expiryStatus(ing.created_at) === 'danger'">
          <span class="badge badge-danger" x-text="`🚨 ${expiryDays(ing.created_at)}일 경과`"></span>
        </template>
        <div class="cube-count-row">
          <button class="adj-btn" @click="adjust(ing.id, -1)">−</button>
          <span class="cube-count" :class="ing.current_cubes <= 3 ? 'low' : ''"
                x-text="ing.current_cubes + (ing.current_cubes <= 3 ? ' 🚨' : '')"></span>
          <button class="adj-btn" @click="adjust(ing.id, +1)">+</button>
        </div>
      </div>
    </template>

    <button class="cube-add-btn" @click="openAdd()">
      <span style="font-size:1.75rem;">+</span>
      <span>재료 추가</span>
    </button>
  </div>

  <template x-if="showAddModal">
    <div class="modal-overlay" @click.self="showAddModal = false">
      <div class="modal-box"
           x-data="ingredientModal(editTarget)"
           @saved="$parent.onSaved()">
        <p class="modal-title" x-text="editId ? '재료 수정' : '새 재료 추가'"></p>
        <div class="form-group">
          <label class="form-label">식재료명</label>
          <input class="form-input" x-model="form.name" placeholder="예: 소고기" required>
        </div>
        <div class="form-group">
          <label class="form-label">이모지 선택</label>
          <div class="emoji-grid">
            <template x-for="e in presetEmojis" :key="e">
              <button class="emoji-btn" :class="form.emoji===e?'selected':''"
                      @click="form.emoji=e" type="button" x-text="e"></button>
            </template>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">큐브 색상</label>
          <div class="color-grid">
            <template x-for="c in presetColors" :key="c">
              <button class="color-btn" :class="form.color===c?'selected':''"
                      :style="`background-color:${c}`"
                      @click="form.color=c" type="button"></button>
            </template>
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label class="form-label">제작일</label>
            <input class="form-input" type="date" x-model="form.created_at" required>
          </div>
          <div class="form-group">
            <label class="form-label">1큐브 중량 (g)</label>
            <input class="form-input" type="number" x-model.number="form.weight_per_cube" min="1" required>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">총 제작 개수</label>
          <input class="form-input" type="number" x-model.number="form.total_cubes" min="1" required>
        </div>
        <div class="form-actions">
          <button class="btn btn-muted" @click="$parent.showAddModal=false">취소</button>
          <button class="btn btn-green" @click="submit()" x-text="editId?'수정 완료':'추가하기'"></button>
        </div>
      </div>
    </div>
  </template>

</div>
{% endblock %}
```

- [ ] **Step 4: schedule.html 작성**

`web/templates/schedule.html`:
```html
{% extends "_base.html" %}
{% set active_tab = 'schedule' %}
{% block title %}식단표 — 치밀한 이유식{% endblock %}

{% block content %}
<div x-data="schedulePage()" x-init="init()">

  <template x-if="sortedDates.length === 0">
    <div class="empty-state">
      <div class="empty-state-icon">🍱</div>
      <p class="empty-state-text">아직 등록된 식단이 없어요</p>
    </div>
  </template>

  <template x-for="date in sortedDates" :key="date">
    <div class="date-group">
      <div class="date-label">
        <span class="date-label-text" :class="isPast(date)?'past':''" x-text="dateLabel(date)"></span>
        <button class="btn btn-sm btn-blue" @click="openAddMeal(date)">+ 끼니 추가</button>
      </div>

      <template x-for="meal in groupedMeals[date]" :key="meal.id">
        <div class="meal-row" :class="meal.status==='skipped'?'skipped':''">
          <div class="meal-row-header">
            <span class="meal-time-label" x-text="mealLabel(meal.meal_time)"></span>
            <span class="badge" :class="statusBadge(meal.status).cls"
                  x-text="statusBadge(meal.status).text"></span>
          </div>
          <div class="meal-ingredients">
            <template x-for="mi in meal.ingredients" :key="mi.ingredient_id">
              <span class="meal-ing-chip" x-text="`${mi.emoji} ${mi.name} ${mi.grams}g`"></span>
            </template>
          </div>
          <div class="meal-actions">
            <template x-if="meal.status==='upcoming'||meal.status==='skipped'">
              <button class="btn btn-sm btn-green" @click="setStatus(meal,'confirmed')">✅ 먹었어요</button>
            </template>
            <template x-if="meal.status==='auto-consumed'||meal.status==='confirmed'">
              <button class="btn btn-sm btn-muted" @click="setStatus(meal,'skipped')">↩ 안 먹었어요</button>
            </template>
          </div>
        </div>
      </template>
    </div>
  </template>

  <button class="btn-add-date" @click="openAddMeal()">+ 날짜 식단 추가</button>

  <template x-if="showAddModal">
    <div class="modal-overlay" @click.self="showAddModal=false">
      <div class="modal-box"
           x-data="mealModal(addDefaultDate, ingredients)"
           @meal-saved="$parent.onMealSaved()">
        <p class="modal-title">식단 추가</p>
        <div class="form-row">
          <div class="form-group">
            <label class="form-label">날짜</label>
            <input class="form-input" type="date" x-model="date" required>
          </div>
          <div class="form-group">
            <label class="form-label">끼니</label>
            <select class="form-input" x-model="mealTime">
              <template x-for="mt in mealTimes" :key="mt.value">
                <option :value="mt.value" x-text="mt.label"></option>
              </template>
            </select>
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">재료 용량 (g)</label>
          <template x-if="ingredients.length===0">
            <p style="font-size:.8rem;color:var(--text-muted);padding:.5rem 0;">
              먼저 재고 탭에서 재료를 추가해주세요
            </p>
          </template>
          <template x-for="ing in ingredients" :key="ing.id">
            <div class="ing-row">
              <span class="ing-row-emoji" x-text="ing.emoji"></span>
              <span class="ing-row-name"  x-text="ing.name"></span>
              <input class="ing-row-input" type="number" min="0" placeholder="0"
                     :value="grams[ing.id]||''"
                     @input="grams[ing.id]=parseInt($event.target.value)||0">
              <span class="ing-row-unit">g</span>
            </div>
          </template>
        </div>
        <div class="form-actions">
          <button class="btn btn-muted" @click="$parent.showAddModal=false">취소</button>
          <button class="btn btn-blue"  @click="submit()" :disabled="!hasIngredients">추가하기</button>
        </div>
      </div>
    </div>
  </template>

</div>
{% endblock %}
```

- [ ] **Step 5: 커밋**

```bash
git add web/templates/
git commit -m "feat: add login, base, inventory, schedule templates"
```

---

### Task 8: 배포 설정

**Files:**
- Create: `babymeal.service`
- Create: `deploy.sh`
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 1: babymeal.service**

`babymeal.service`:
```ini
[Unit]
Description=치밀한 이유식 - Baby Meal Cube Manager
After=network.target mysqld.service

[Service]
Type=simple
User=daero52
WorkingDirectory=/volume1/DR_DATA1/babyMeal
ExecStart=/usr/bin/python3 /volume1/DR_DATA1/babyMeal/web/app.py --port 8990
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 2: deploy.sh**

`deploy.sh`:
```bash
#!/bin/bash
set -e
cd /volume1/DR_DATA1/babyMeal
git pull origin main
pip3 install -r requirements.txt --quiet
sudo systemctl restart babymeal
echo "배포 완료: $(date)"
```

- [ ] **Step 3: .github/workflows/deploy.yml (animation 동일 구조)**

`.github/workflows/deploy.yml`:
```yaml
name: Deploy to NAS

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Sync to NAS
        run: |
          rsync -a --exclude='.git' --exclude='config.json' --exclude='logs/' \
            $GITHUB_WORKSPACE/ /volume1/DR_DATA1/babyMeal/
          nsenter --target 1 --mount --uts --ipc --net --pid -- \
            chown -R daero52:users /volume1/DR_DATA1/babyMeal/
          nsenter --target 1 --mount --uts --ipc --net --pid -- \
            chmod -R 755 /volume1/DR_DATA1/babyMeal/

      - name: Install dependencies
        run: pip3 install -r /volume1/DR_DATA1/babyMeal/requirements.txt --quiet

      - name: Restart service
        run: |
          nsenter --target 1 --mount --uts --ipc --net --pid -- \
            systemctl restart babymeal

      - name: Discord notify
        if: always()
        env:
          COMMIT_MSG: ${{ github.event.head_commit.message }}
          JOB_STATUS: ${{ job.status }}
          RUN_URL: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
        run: |
          PAYLOAD=$(python3 << 'PYEOF'
          import json, datetime, os
          status = os.environ.get('JOB_STATUS', 'failure')
          msg    = os.environ.get('COMMIT_MSG', '').split('\n')[0]
          if status == 'success':
              color, title, desc = 3066993, '🍼 이유식 앱 배포 완료', f'**{msg}**'
          else:
              color, title = 15158332, '🍼 이유식 앱 배포 실패'
              desc = f'[로그 확인]({os.environ.get("RUN_URL","")})'
          now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
          print(json.dumps({'embeds':[{'title':title,'description':desc,'color':color,'footer':{'text':now}}]}))
          PYEOF
          )
          WEBHOOK=$(python3 -c "import json; print(json.load(open('/volume1/DR_DATA1/babyMeal/config.json')).get('discord_webhook',''))" 2>/dev/null || echo "")
          [ -n "$WEBHOOK" ] && curl -s -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK" || true
```

- [ ] **Step 4: 커밋**

```bash
git add babymeal.service deploy.sh .github/workflows/deploy.yml
git commit -m "chore: add systemd service and GitHub Actions deploy"
```

---

### Task 9: NAS 초기 세팅 (1회성)

- [ ] **Step 1: config.json 생성 (NAS에서, gitignore됨)**

`/volume1/DR_DATA1/babyMeal/config.json`:
```json
{
  "db": {
    "host": "192.168.0.34",
    "port": 3306,
    "user": "root",
    "password": "실제비밀번호",
    "database": "babymeal"
  },
  "secret_key": "랜덤_문자열_32자_이상",
  "port": 8990,
  "debug": false,
  "discord_webhook": ""
}
```

- [ ] **Step 2: systemd 서비스 등록**

```bash
cp /volume1/DR_DATA1/babyMeal/babymeal.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable babymeal
```

- [ ] **Step 3: 관리자 계정 초기 생성**

```bash
cd /volume1/DR_DATA1/babyMeal
python3 web/app.py --init-admin
# 아이디/비밀번호 입력
```

- [ ] **Step 4: 서비스 시작 및 확인**

```bash
systemctl start babymeal
systemctl status babymeal
# 브라우저에서 http://192.168.0.34:8990 확인
```

---

## 최종 테스트

```bash
python -m pytest -v
```

Expected:
```
tests/test_deduction.py::test_past_upcoming_meal_is_auto_consumed  PASSED
tests/test_deduction.py::test_future_meal_not_deducted             PASSED
tests/test_deduction.py::test_already_consumed_skipped             PASSED
tests/test_deduction.py::test_grams_to_cubes_rounds                PASSED
tests/test_deduction.py::test_multiple_meals_accumulate            PASSED
tests/test_deduction.py::test_skipped_not_deducted                 PASSED
tests/test_api.py::test_login_page_accessible                      PASSED
tests/test_api.py::test_unauthenticated_redirects_to_login         PASSED
tests/test_api.py::test_api_ingredients_requires_auth              PASSED
tests/test_api.py::test_api_ingredients_list                       PASSED
tests/test_api.py::test_api_add_ingredient                         PASSED
tests/test_api.py::test_api_adjust_stock                           PASSED
```
