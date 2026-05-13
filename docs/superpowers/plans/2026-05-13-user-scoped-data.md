# User-Scoped Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ingredients/meals를 로그인 계정별로 분리하고, 관리자는 네비게이션에서 다른 사용자로 전환해 해당 계정 데이터를 조회/수정할 수 있게 한다.

**Architecture:** `session['view_as_user_id']`로 현재 보는 사용자 컨텍스트를 관리. 모든 ingredients/meals 쿼리에 `user_id` 필터 추가. 관리자 전용 `POST /api/admin/switch-user`로 전환, `_base.html`에 사용자 선택 드롭다운과 "다른 계정 보는 중" 배너 표시.

**Tech Stack:** Flask session, MySQL, Jinja2, vanilla JS fetch

---

## 파일 구조

| 파일 | 변경 |
|---|---|
| `migrate_user_scoped.sql` | 신규 — DB 마이그레이션 |
| `web/app.py` | 수정 — 세션, 헬퍼, 쿼리 전반, API 2개 추가 |
| `web/templates/_base.html` | 수정 — 사용자 스위처 + 배너 |
| `tests/test_api.py` | 수정 — fixture user_id 추가, switch-user 테스트 |

---

### Task 1: DB 마이그레이션 파일 생성

**Files:**
- Create: `migrate_user_scoped.sql`

- [ ] **Step 1: 마이그레이션 파일 생성**

`/Users/idaelo/project/babyMeal/migrate_user_scoped.sql`:
```sql
ALTER TABLE ingredients ADD COLUMN user_id INT DEFAULT NULL;
UPDATE ingredients
  SET user_id = (SELECT id FROM users WHERE is_admin=1 ORDER BY id LIMIT 1)
  WHERE user_id IS NULL;
ALTER TABLE ingredients
  MODIFY COLUMN user_id INT NOT NULL,
  ADD CONSTRAINT fk_ing_user FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE meals ADD COLUMN user_id INT DEFAULT NULL;
UPDATE meals
  SET user_id = (SELECT id FROM users WHERE is_admin=1 ORDER BY id LIMIT 1)
  WHERE user_id IS NULL;
ALTER TABLE meals
  MODIFY COLUMN user_id INT NOT NULL,
  ADD CONSTRAINT fk_meal_user FOREIGN KEY (user_id) REFERENCES users(id);
```

- [ ] **Step 2: DB에 적용 (DB 비밀번호 필요 — 직접 실행)**

config.json에서 비밀번호를 확인한 뒤 실행:
```bash
mysql -h 192.168.0.34 -u root -p babymeal < migrate_user_scoped.sql
```
Expected: 오류 없이 완료.

- [ ] **Step 3: 적용 확인**

```bash
mysql -h 192.168.0.34 -u root -p babymeal -e "DESCRIBE ingredients; DESCRIBE meals;"
```
Expected: 두 테이블 모두 `user_id` 컬럼 포함.

- [ ] **Step 4: 커밋**

```bash
cd /Users/idaelo/project/babyMeal && git add migrate_user_scoped.sql && git commit -m "feat: add user_id to ingredients and meals tables"
```

---

### Task 2: 세션 초기화 + get_view_user_id 헬퍼 TDD

**Files:**
- Modify: `tests/test_api.py` (fixture 업데이트)
- Modify: `web/app.py` (로그인 세션, 헬퍼 추가)

- [ ] **Step 1: authed_client fixture에 user_id 추가**

`tests/test_api.py`의 `authed_client` fixture를 다음으로 교체:
```python
@pytest.fixture
def authed_client(app):
    client = app.test_client()
    with client.session_transaction() as sess:
        sess['logged_in'] = True
        sess['username'] = 'admin'
        sess['user_id'] = 1
        sess['view_as_user_id'] = 1
        sess['is_admin'] = True
        sess['csrf_token'] = 'testtoken'
    return client
```

- [ ] **Step 2: 기존 테스트 통과 확인**

```bash
cd /Users/idaelo/project/babyMeal && python3 -m pytest tests/ -v 2>&1 | tail -10
```
Expected: 전체 PASSED (fixture 변경이 기존 테스트를 깨지 않아야 함)

- [ ] **Step 3: switch-user 관련 테스트 추가** (`tests/test_api.py` 끝에 append)

```python
@pytest.fixture
def non_admin_client(app):
    client = app.test_client()
    with client.session_transaction() as sess:
        sess['logged_in'] = True
        sess['username'] = 'user1'
        sess['user_id'] = 2
        sess['view_as_user_id'] = 2
        sess['is_admin'] = False
        sess['csrf_token'] = 'testtoken'
    return client


def test_switch_user_requires_admin(non_admin_client):
    resp = non_admin_client.post(
        '/api/admin/switch-user',
        data=json.dumps({'user_id': 1}),
        content_type='application/json',
        headers={'X-CSRF-Token': 'testtoken'},
    )
    assert resp.status_code in (302, 403)


def test_switch_user_success(authed_client):
    target = {'id': 2, 'username': 'user1'}
    cur = make_cursor([target])
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        resp = authed_client.post(
            '/api/admin/switch-user',
            data=json.dumps({'user_id': 2}),
            content_type='application/json',
            headers={'X-CSRF-Token': 'testtoken'},
        )
    assert resp.status_code == 200
    assert json.loads(resp.data)['username'] == 'user1'


def test_switch_user_reset(authed_client):
    resp = authed_client.delete(
        '/api/admin/switch-user',
        headers={'X-CSRF-Token': 'testtoken'},
    )
    assert resp.status_code == 200
    assert json.loads(resp.data)['ok'] is True
```

- [ ] **Step 4: 새 테스트 실패 확인**

```bash
python3 -m pytest tests/test_api.py::test_switch_user_success -v 2>&1 | tail -5
```
Expected: 404 (라우트 없음)

- [ ] **Step 5: web/app.py — 로그인 세션에 view_as_user_id 추가**

`session['is_admin'] = bool(user['is_admin'])` 바로 다음 줄에 추가:
```python
session['view_as_user_id'] = user['id']
```

- [ ] **Step 6: web/app.py — get_view_user_id 헬퍼 추가**

`create_app` 함수 내부, `_mod.get_db = _get_db` 바로 아래에 추가:
```python
def get_view_user_id():
    return session.get('view_as_user_id', session['user_id'])
```

- [ ] **Step 7: web/app.py — switch-user API 추가**

`# ─── 식단 API` 주석 앞(api_emoji_image 라우트 뒤)에 삽입:
```python
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
```

- [ ] **Step 8: 새 테스트 통과 + 전체 통과 확인**

```bash
python3 -m pytest tests/ -v 2>&1 | tail -15
```
Expected: 전체 PASSED

- [ ] **Step 9: 커밋**

```bash
git add web/app.py tests/test_api.py && git commit -m "feat: add get_view_user_id helper and switch-user API"
```

---

### Task 3: Ingredients 쿼리 user_id 필터 TDD

**Files:**
- Modify: `web/app.py` (ingredients 관련 라우트 5개)
- Modify: `tests/test_api.py`

- [ ] **Step 1: 테스트 추가** (`tests/test_api.py` 끝에 append)

```python
def test_ingredients_list_filtered_by_user(authed_client):
    rows = [{'id': 1, 'name': '소고기', 'emoji': '🥩', 'color': '#C0392B',
             'created_at': '2026-05-01', 'weight_per_cube': 20,
             'total_cubes': 10, 'current_cubes': 10, 'image_url': None,
             'user_id': 1}]
    cur = make_cursor(rows)
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        resp = authed_client.get('/api/ingredients')
    assert resp.status_code == 200
    # user_id 필터가 동작하는지: execute 호출 인자에 user_id 포함 확인
    call_args = cur.execute.call_args_list[0]
    assert '1' in str(call_args) or 1 in str(call_args)
```

- [ ] **Step 2: web/app.py — api_ingredients_list 수정**

```python
# 변경 전
cur.execute('SELECT * FROM ingredients ORDER BY name')

# 변경 후
cur.execute('SELECT * FROM ingredients WHERE user_id=%s ORDER BY name',
            (get_view_user_id(),))
```

- [ ] **Step 3: api_ingredients_add 수정**

INSERT 쿼리에 `user_id` 추가:
```python
# 변경 전
cur.execute("""
    INSERT INTO ingredients
      (name, emoji, color, created_at, weight_per_cube, total_cubes, current_cubes)
    VALUES (%(name)s, %(emoji)s, %(color)s, %(created_at)s,
            %(weight_per_cube)s, %(total_cubes)s, %(total_cubes)s)
""", d)

# 변경 후
cur.execute("""
    INSERT INTO ingredients
      (name, emoji, color, created_at, weight_per_cube, total_cubes, current_cubes, user_id)
    VALUES (%(name)s, %(emoji)s, %(color)s, %(created_at)s,
            %(weight_per_cube)s, %(total_cubes)s, %(total_cubes)s, %(user_id)s)
""", {**d, 'user_id': session['user_id']})
```

- [ ] **Step 4: api_ingredients_update 수정**

```python
# 변경 전
cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s', {**d, 'id': ing_id})
conn.commit()
cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))

# 변경 후
cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s AND user_id=%(uid)s',
            {**d, 'id': ing_id, 'uid': get_view_user_id()})
conn.commit()
cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))
```

- [ ] **Step 5: api_ingredients_delete 수정**

```python
# 변경 전
cur.execute('DELETE FROM ingredients WHERE id=%s', (ing_id,))

# 변경 후
cur.execute('DELETE FROM ingredients WHERE id=%s AND user_id=%s',
            (ing_id, get_view_user_id()))
```

- [ ] **Step 6: api_ingredients_adjust 수정**

```python
# 변경 전
cur.execute(
    'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s',
    (delta, ing_id)
)

# 변경 후
cur.execute(
    'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s AND user_id=%s',
    (delta, ing_id, get_view_user_id())
)
```

- [ ] **Step 7: 전체 테스트 통과 확인**

```bash
python3 -m pytest tests/ -v 2>&1 | tail -10
```
Expected: 전체 PASSED

- [ ] **Step 8: 커밋**

```bash
git add web/app.py tests/test_api.py && git commit -m "feat: filter ingredients queries by user_id"
```

---

### Task 4: Meals 쿼리 user_id 필터

**Files:**
- Modify: `web/app.py` (meals 관련 라우트 4개 + _meal_with_ingredients)

- [ ] **Step 1: api_meals_list 수정**

```python
# 변경 전
cur.execute('SELECT id FROM meals ORDER BY date, meal_time')

# 변경 후
cur.execute('SELECT id FROM meals WHERE user_id=%s ORDER BY date, meal_time',
            (get_view_user_id(),))
```

- [ ] **Step 2: api_meals_add 수정**

```python
# 변경 전
cur.execute(
    'INSERT INTO meals (date, meal_time, note) VALUES (%s, %s, %s)',
    (d['date'], d['meal_time'], d.get('note', ''))
)

# 변경 후
cur.execute(
    'INSERT INTO meals (date, meal_time, note, user_id) VALUES (%s, %s, %s, %s)',
    (d['date'], d['meal_time'], d.get('note', ''), session['user_id'])
)
```

- [ ] **Step 3: api_meals_delete 수정**

```python
# 변경 전
cur.execute('DELETE FROM meals WHERE id=%s', (meal_id,))

# 변경 후
cur.execute('DELETE FROM meals WHERE id=%s AND user_id=%s',
            (meal_id, get_view_user_id()))
```

- [ ] **Step 4: api_meals_status 수정**

```python
# 변경 전
cur.execute('SELECT status FROM meals WHERE id=%s', (meal_id,))
...
cur.execute('UPDATE meals SET status=%s WHERE id=%s', (new_status, meal_id))

# 변경 후
cur.execute('SELECT status FROM meals WHERE id=%s AND user_id=%s',
            (meal_id, get_view_user_id()))
...
cur.execute('UPDATE meals SET status=%s WHERE id=%s AND user_id=%s',
            (new_status, meal_id, get_view_user_id()))
```

- [ ] **Step 5: 전체 테스트 통과 확인**

```bash
python3 -m pytest tests/ -v 2>&1 | tail -10
```
Expected: 전체 PASSED

- [ ] **Step 6: 커밋**

```bash
git add web/app.py && git commit -m "feat: filter meals queries by user_id"
```

---

### Task 5: _page_ctx 헬퍼 + _base.html 사용자 스위처 UI

**Files:**
- Modify: `web/app.py` (page route render_template 통일)
- Modify: `web/templates/_base.html` (사용자 스위처 + 배너)

- [ ] **Step 1: _page_ctx 헬퍼 추가**

`web/app.py`에서 `_run_auto_deduction` 함수 정의 바로 위에 추가:
```python
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
```

- [ ] **Step 2: 페이지 라우트 3개를 _page_ctx() 사용으로 수정**

```python
# inventory_page — 변경 후
return render_template('inventory.html', **_page_ctx())

# schedule_page — 변경 후
return render_template('schedule.html', **_page_ctx())

# settings_page — 변경 후
return render_template('settings.html', **_page_ctx())
```

- [ ] **Step 3: _base.html 사용자 스위처 + 배너 추가**

`web/templates/_base.html`에서 `<div class="sidebar-bottom">` 블록 앞에 삽입:
```html
    {% if is_admin and all_users %}
    <div style="padding:.5rem 1rem;">
      <select onchange="switchUser(this.value)"
              style="width:100%;padding:.3rem .5rem;border-radius:6px;border:1px solid var(--border);background:var(--surface);color:var(--text);font-size:.8rem;cursor:pointer;">
        {% for u in all_users %}
        <option value="{{ u.id }}" {% if u.id == view_user_id %}selected{% endif %}>
          {{ u.username }}{% if u.id == view_user_id %} ✓{% endif %}
        </option>
        {% endfor %}
      </select>
    </div>
    {% endif %}
```

`</aside>` 바로 앞(sidebar-bottom 닫힌 뒤)에 추가:
```html
  {% if is_viewing_other %}
  <div onclick="resetUser()"
       style="position:fixed;top:0;left:0;right:0;z-index:999;background:#e67e22;color:#fff;
              text-align:center;padding:.4rem;font-size:.85rem;cursor:pointer;">
    👁 <strong>{{ view_username }}</strong> 계정 보는 중 — 클릭하여 본인으로 복귀
  </div>
  {% endif %}
```

`</body>` 바로 앞에 스크립트 추가:
```html
  <script>
  function switchUser(userId) {
    fetch('/api/admin/switch-user', {
      method: 'POST',
      headers: {'Content-Type':'application/json','X-CSRF-Token': window._csrfToken || ''},
      body: JSON.stringify({user_id: parseInt(userId)})
    }).then(r => r.ok && location.reload());
  }
  function resetUser() {
    fetch('/api/admin/switch-user', {
      method: 'DELETE',
      headers: {'X-CSRF-Token': window._csrfToken || ''}
    }).then(r => r.ok && location.reload());
  }
  </script>
```

- [ ] **Step 4: 전체 테스트 통과 확인**

```bash
python3 -m pytest tests/ -v 2>&1 | tail -10
```
Expected: 전체 PASSED

- [ ] **Step 5: 커밋**

```bash
git add web/app.py web/templates/_base.html && git commit -m "feat: add user switcher UI and page context helper"
```

---

## 완료 체크리스트

- [ ] DB에 `ingredients.user_id`, `meals.user_id` 컬럼 추가됨
- [ ] 일반 사용자는 본인 재료/식단표만 보임
- [ ] 관리자 사이드바에 사용자 드롭다운 표시
- [ ] 다른 계정 전환 시 주황색 배너 표시
- [ ] 본인으로 복귀 동작
- [ ] `python3 -m pytest tests/ -v` 전체 통과
