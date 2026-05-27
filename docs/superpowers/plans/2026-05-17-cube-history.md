# 큐브 이력 히스토리 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 재고현황의 각 큐브 카드에 📋 히스토리 버튼을 추가하여 제작·먹힘·보충 이력을 모달로 확인할 수 있게 한다.

**Architecture:** `ingredient_logs` 테이블을 신규 생성해 이벤트를 기록한다. 재료 추가 시 'created', 식단 확인(먹었어요) 시 'fed', total_cubes 수정 시 'replenished' 이벤트를 남긴다. 프론트엔드는 Alpine.js + 기존 모달 패턴으로 히스토리를 표시한다.

**Tech Stack:** Python/Flask (백엔드), MySQL (DB), Alpine.js (프론트), Jinja2 (템플릿)

---

## 파일 맵

| 파일 | 작업 |
|---|---|
| `migrate_ingredient_logs.sql` | 신규 생성 — 테이블 + 기존 데이터 시딩 |
| `web/app.py` | 수정 — `_log_ingredient_event` 헬퍼, 로깅 훅 3곳, GET logs 엔드포인트 |
| `web/static/app.js` | 수정 — `inventoryPage()`에 히스토리 상태·메서드 추가 |
| `web/templates/inventory.html` | 수정 — 📋 버튼, 히스토리 모달 템플릿 |
| `tests/test_api.py` | 수정 — GET logs 엔드포인트 테스트 추가 |

---

## Task 1: DB 마이그레이션 파일 생성

**Files:**
- Create: `migrate_ingredient_logs.sql`

- [ ] **Step 1: 마이그레이션 파일 작성**

`migrate_ingredient_logs.sql` 생성:

```sql
CREATE TABLE IF NOT EXISTS ingredient_logs (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    ingredient_id INT NOT NULL,
    user_id       INT NOT NULL,
    event_type    ENUM('created','fed','replenished') NOT NULL,
    delta         INT NOT NULL,
    note          VARCHAR(255) DEFAULT NULL,
    logged_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ing_id (ingredient_id),
    INDEX idx_user_id (user_id)
);

-- 기존 재료를 'created' 이벤트로 시딩 (이미 이력이 있는 재료는 건너뜀)
INSERT INTO ingredient_logs (ingredient_id, user_id, event_type, delta, note, logged_at)
SELECT id, user_id, 'created', total_cubes, '기존 데이터', created_at
FROM ingredients
WHERE id NOT IN (SELECT DISTINCT ingredient_id FROM ingredient_logs);
```

- [ ] **Step 2: 서버에서 마이그레이션 실행**

```bash
mysql -u <USER> -p <DB_NAME> < migrate_ingredient_logs.sql
```

Expected: 오류 없이 완료, `ingredient_logs` 테이블 생성 및 기존 재료 시딩됨

- [ ] **Step 3: 커밋**

```bash
git add migrate_ingredient_logs.sql
git commit -m "feat: ingredient_logs 마이그레이션 파일 추가"
```

---

## Task 2: GET 로그 엔드포인트 — TDD

**Files:**
- Modify: `tests/test_api.py`
- Modify: `web/app.py`

- [ ] **Step 1: 실패 테스트 작성**

`tests/test_api.py` 끝에 추가:

```python
def test_api_ingredient_logs(authed_client):
    from datetime import datetime
    log_rows = [
        {'id': 1, 'event_type': 'created', 'delta': 10,
         'note': None, 'logged_at': datetime(2026, 5, 1, 0, 0, 0)},
        {'id': 2, 'event_type': 'fed', 'delta': -2,
         'note': '2026-05-10 lunch', 'logged_at': datetime(2026, 5, 10, 12, 0, 0)},
    ]
    cur = make_cursor(log_rows)
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        resp = authed_client.get('/api/ingredients/1/logs')
    assert resp.status_code == 200
    data = json.loads(resp.data)
    assert len(data) == 2
    assert data[0]['event_type'] == 'created'
    assert data[0]['delta'] == 10
    assert data[0]['logged_at'] == '2026-05-01 00:00'
    assert data[1]['event_type'] == 'fed'
    assert data[1]['delta'] == -2
    assert data[1]['note'] == '2026-05-10 lunch'


def test_api_ingredient_logs_requires_auth(app):
    client = app.test_client()
    resp = client.get('/api/ingredients/1/logs')
    assert resp.status_code == 302
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd /Users/idaelo/project/babyMeal && python -m pytest tests/test_api.py::test_api_ingredient_logs -v
```

Expected: FAIL — `404 Not Found` (엔드포인트 없음)

- [ ] **Step 3: GET /api/ingredients/<id>/logs 엔드포인트 구현**

`web/app.py` 에서 `# ─── 이모지 이미지 API` 주석 바로 앞 (line 565 근처)에 추가:

```python
    @app.get('/api/ingredients/<int:ing_id>/logs')
    @login_required
    def api_ingredient_logs(ing_id):
        cur = _mod.get_db().cursor()
        cur.execute(
            'SELECT id, event_type, delta, note, logged_at '
            'FROM ingredient_logs WHERE ingredient_id=%s AND user_id=%s ORDER BY logged_at DESC',
            (ing_id, get_view_user_id())
        )
        rows = cur.fetchall()
        return jsonify([{**r, 'logged_at': str(r['logged_at'])[:16]} for r in rows])
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
python -m pytest tests/test_api.py::test_api_ingredient_logs tests/test_api.py::test_api_ingredient_logs_requires_auth -v
```

Expected: PASS 2개

- [ ] **Step 5: 전체 테스트 통과 확인**

```bash
python -m pytest tests/ -v
```

Expected: 모든 기존 테스트 PASS

- [ ] **Step 6: 커밋**

```bash
git add web/app.py tests/test_api.py
git commit -m "feat: GET /api/ingredients/<id>/logs 엔드포인트 추가"
```

---

## Task 3: 이벤트 로깅 헬퍼 + 재료 생성/보충 로깅

**Files:**
- Modify: `web/app.py`

- [ ] **Step 1: `_log_ingredient_event` 헬퍼 추가**

`web/app.py`의 `def _fmt_ingredient(row):` 다음 줄(line 445 근처)에 삽입:

```python
    def _log_ingredient_event(conn, ingredient_id, user_id, event_type, delta, note=None):
        conn.cursor().execute(
            'INSERT INTO ingredient_logs (ingredient_id, user_id, event_type, delta, note)'
            ' VALUES (%s, %s, %s, %s, %s)',
            (ingredient_id, user_id, event_type, delta, note)
        )
```

- [ ] **Step 2: `api_ingredients_add`에 'created' 이벤트 로깅 추가**

`web/app.py` line 487 근처, INSERT 실행 후 `conn.commit()` 바로 앞에 로깅 추가:

기존 코드:
```python
        cur.execute("""
            INSERT INTO ingredients
              (name, emoji, color, created_at, weight_per_cube, total_cubes, current_cubes, unit_type, user_id)
            VALUES (%(name)s, %(emoji)s, %(color)s, %(created_at)s,
                    %(weight_per_cube)s, %(total_cubes)s, %(total_cubes)s, %(unit_type)s, %(user_id)s)
        """, {**d, 'user_id': get_view_user_id()})
        conn.commit()
```

변경 후:
```python
        cur.execute("""
            INSERT INTO ingredients
              (name, emoji, color, created_at, weight_per_cube, total_cubes, current_cubes, unit_type, user_id)
            VALUES (%(name)s, %(emoji)s, %(color)s, %(created_at)s,
                    %(weight_per_cube)s, %(total_cubes)s, %(total_cubes)s, %(unit_type)s, %(user_id)s)
        """, {**d, 'user_id': get_view_user_id()})
        _log_ingredient_event(conn, cur.lastrowid, get_view_user_id(), 'created', d['total_cubes'])
        conn.commit()
```

- [ ] **Step 3: `api_ingredients_update`에 'replenished' 이벤트 로깅 추가**

`web/app.py` line 516 근처, UPDATE 실행 직후 `conn.commit()` 바로 앞에 추가:

기존 코드:
```python
        cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s AND user_id=%(uid)s',
                    {**d, 'id': ing_id, 'uid': get_view_user_id()})
        conn.commit()
```

변경 후:
```python
        cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s AND user_id=%(uid)s',
                    {**d, 'id': ing_id, 'uid': get_view_user_id()})
        if 'total_cubes' in d:
            _log_ingredient_event(conn, ing_id, get_view_user_id(), 'replenished', d['total_cubes'])
        conn.commit()
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
python -m pytest tests/ -v
```

Expected: 전체 PASS (TESTING=True 모드에서 ingredient_logs INSERT는 MagicMock cursor가 처리)

- [ ] **Step 5: 커밋**

```bash
git add web/app.py
git commit -m "feat: 재료 생성/보충 시 ingredient_logs 이벤트 기록"
```

---

## Task 4: 식단 먹힘(fed) 이벤트 로깅

**Files:**
- Modify: `web/app.py` — `_apply_stock_delta`, `api_meals_status`

- [ ] **Step 1: `_apply_stock_delta` 수정**

`web/app.py` line 727의 `_apply_stock_delta` 함수를 아래와 같이 교체:

기존:
```python
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
```

변경 후:
```python
    def _apply_stock_delta(conn, meal_id, direction, user_id=None):
        cur = conn.cursor()
        cur.execute("""
            SELECT mi.ingredient_id, mi.grams, i.weight_per_cube,
                   m.date AS meal_date, m.meal_time
            FROM meal_ingredients mi
            JOIN ingredients i ON i.id = mi.ingredient_id
            JOIN meals m ON m.id = mi.meal_id
            WHERE mi.meal_id=%s
        """, (meal_id,))
        for r in cur.fetchall():
            cubes = round(r['grams'] / r['weight_per_cube'])
            delta = -cubes if direction == 'deduct' else cubes
            cur.execute(
                'UPDATE ingredients SET current_cubes = GREATEST(0, current_cubes + %s) WHERE id=%s',
                (delta, r['ingredient_id'])
            )
            if direction == 'deduct' and user_id is not None:
                note = f"{r['meal_date']} {r['meal_time']}"
                _log_ingredient_event(conn, r['ingredient_id'], user_id, 'fed', delta, note)
```

- [ ] **Step 2: `api_meals_status`에서 `_apply_stock_delta` deduct 호출에 user_id 전달**

`web/app.py` line 712 근처:

기존:
```python
            _apply_stock_delta(conn, meal_id, direction='deduct')
```

변경 후:
```python
            _apply_stock_delta(conn, meal_id, direction='deduct', user_id=get_view_user_id())
```

(restore 호출 line 710은 변경 없음 — 복구 시 로깅 불필요)

- [ ] **Step 3: 테스트 통과 확인**

```bash
python -m pytest tests/ -v
```

Expected: 전체 PASS

- [ ] **Step 4: 커밋**

```bash
git add web/app.py
git commit -m "feat: 식단 먹었어요 처리 시 fed 이벤트 ingredient_logs 기록"
```

---

## Task 5: UI — 히스토리 버튼 + 모달 (Alpine.js)

**Files:**
- Modify: `web/static/app.js`
- Modify: `web/templates/inventory.html`

- [ ] **Step 1: `inventoryPage()`에 히스토리 상태·메서드 추가**

`web/static/app.js` line 83 근처, `inventoryPage()` return 객체의 `onSaved()` 메서드 다음에 추가:

기존:
```javascript
        async onSaved() {
            this.showAddModal = false;
            this.editTarget = null;
            await this.load();
        },
    };
}
```

변경 후:
```javascript
        async onSaved() {
            this.showAddModal = false;
            this.editTarget = null;
            await this.load();
        },

        historyIng: null,
        historyLogs: [],
        showHistoryModal: false,

        async openHistory(ing) {
            this.historyIng = ing;
            this.showHistoryModal = true;
            this.historyLogs = await api(`/api/ingredients/${ing.id}/logs`) || [];
        },

        historyLabel(log) {
            const icons  = { created: '🆕', fed: '🍼', replenished: '🔁' };
            const labels = { created: '제작', fed: '먹힘', replenished: '보충' };
            return `${icons[log.event_type] || '•'} ${labels[log.event_type] || log.event_type}`;
        },
    };
}
```

- [ ] **Step 2: 큐브 카드에 📋 버튼 추가**

`web/templates/inventory.html` line 37–40 근처, 버튼 영역:

기존:
```html
          <div style="display:flex;gap:.25rem;">
            <button class="btn btn-sm btn-muted" @click="openEdit(ing)" style="padding:.2rem .5rem;">✏️</button>
            <button class="btn btn-sm btn-danger" @click="deleteIngredient(ing)" style="padding:.2rem .5rem;">🗑</button>
          </div>
```

변경 후:
```html
          <div style="display:flex;gap:.25rem;">
            <button class="btn btn-sm btn-muted" @click="openHistory(ing)" style="padding:.2rem .5rem;" title="이력 보기">📋</button>
            <button class="btn btn-sm btn-muted" @click="openEdit(ing)" style="padding:.2rem .5rem;">✏️</button>
            <button class="btn btn-sm btn-danger" @click="deleteIngredient(ing)" style="padding:.2rem .5rem;">🗑</button>
          </div>
```

- [ ] **Step 3: 히스토리 모달 템플릿 추가**

`web/templates/inventory.html` 에서 `</div>` (line 144 — Alpine x-data 닫는 태그) 바로 앞, 기존 `showAddModal` 모달 `</template>` 다음에 추가:

```html
  <template x-if="showHistoryModal">
    <div class="modal-overlay" @click.self="showHistoryModal = false">
      <div class="modal-box">
        <p class="modal-title" x-text="`📋 ${historyIng?.name} 이력`"></p>
        <template x-if="historyLogs.length === 0">
          <p style="color:var(--text-muted);text-align:center;padding:1rem 0;">이력이 없습니다</p>
        </template>
        <div style="max-height:380px;overflow-y:auto;">
          <template x-for="log in historyLogs" :key="log.id">
            <div style="display:flex;justify-content:space-between;align-items:center;
                        padding:.5rem 0;border-bottom:1px solid var(--border);">
              <div>
                <span x-text="historyLabel(log)"></span>
                <template x-if="log.note">
                  <span style="font-size:.8rem;color:var(--text-muted);"
                        x-text="` (${log.note})`"></span>
                </template>
              </div>
              <div style="display:flex;gap:1rem;align-items:center;">
                <span :style="log.delta > 0 ? 'color:#27ae60;font-weight:600' : 'color:#e74c3c;font-weight:600'"
                      x-text="(log.delta > 0 ? '+' : '') + log.delta + '개'"></span>
                <span style="font-size:.78rem;color:var(--text-muted);" x-text="log.logged_at"></span>
              </div>
            </div>
          </template>
        </div>
        <div class="form-actions">
          <button class="btn btn-muted" @click="showHistoryModal = false">닫기</button>
        </div>
      </div>
    </div>
  </template>
```

- [ ] **Step 4: 커밋**

```bash
git add web/static/app.js web/templates/inventory.html
git commit -m "feat: 재고현황 큐브 카드에 히스토리 버튼·모달 추가"
```

---

## Task 6: 배포 및 확인

- [ ] **Step 1: 서버에 마이그레이션 실행 (Task 1이 아직 안 된 경우)**

```bash
mysql -u <USER> -p <DB_NAME> < migrate_ingredient_logs.sql
```

- [ ] **Step 2: 코드 푸시**

```bash
git push origin main
```

- [ ] **Step 3: 서버에서 재시작**

```bash
sudo systemctl restart babymeal
```

- [ ] **Step 4: 동작 확인**
  - 재고현황 페이지 열기
  - 큐브 카드에 📋 버튼 확인
  - 📋 클릭 → 이력 모달 오픈 확인
  - 제작 이력(기존 데이터 시딩)이 표시되는지 확인
  - 식단에서 "먹었어요" 처리 후 해당 재료 이력에 '먹힘' 이벤트 추가되는지 확인
  - 재료 수정 (total_cubes 변경) 후 '보충' 이벤트 추가되는지 확인
