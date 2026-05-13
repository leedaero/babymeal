# 계정별 데이터 분리 설계

**날짜**: 2026-05-13  
**범위**: babyMeal — ingredients/meals를 계정별로 분리, 관리자 사용자 전환 기능

---

## 목표

로그인 계정마다 자신의 재료(ingredients)와 식단표(meals)만 보이도록 분리한다. 관리자는 네비게이션에서 다른 사용자로 전환해 해당 계정의 데이터를 조회/수정할 수 있다.

---

## DB 변경

### 마이그레이션 (`migrate_user_scoped.sql`)

```sql
-- ingredients에 user_id 추가
ALTER TABLE ingredients ADD COLUMN user_id INT DEFAULT NULL;
UPDATE ingredients
  SET user_id = (SELECT id FROM users WHERE is_admin=1 ORDER BY id LIMIT 1)
  WHERE user_id IS NULL;
ALTER TABLE ingredients
  MODIFY COLUMN user_id INT NOT NULL,
  ADD CONSTRAINT fk_ing_user FOREIGN KEY (user_id) REFERENCES users(id);

-- meals에 user_id 추가
ALTER TABLE meals ADD COLUMN user_id INT DEFAULT NULL;
UPDATE meals
  SET user_id = (SELECT id FROM users WHERE is_admin=1 ORDER BY id LIMIT 1)
  WHERE user_id IS NULL;
ALTER TABLE meals
  MODIFY COLUMN user_id INT NOT NULL,
  ADD CONSTRAINT fk_meal_user FOREIGN KEY (user_id) REFERENCES users(id);
```

기존 데이터는 첫 번째 관리자 계정(id 오름차순)에 귀속된다.

---

## 세션 구조

| 키 | 설명 |
|---|---|
| `session['user_id']` | 로그인한 실제 사용자 ID (불변) |
| `session['view_as_user_id']` | 현재 보는 사용자 ID (관리자가 전환 가능) |

로그인 시 두 값을 동일하게 초기화한다. 일반 사용자는 `view_as_user_id`를 변경할 수 없다.

---

## 백엔드 변경 (`web/app.py`)

### 헬퍼 함수 (`create_app` 내부)

```python
def get_view_user_id():
    return session.get('view_as_user_id', session['user_id'])
```

### 로그인 핸들러 추가

```python
session['view_as_user_id'] = user['id']
```

### 쿼리 변경

| 위치 | 변경 내용 |
|---|---|
| `SELECT * FROM ingredients` | `WHERE user_id = get_view_user_id()` 추가 |
| `INSERT INTO ingredients` | `user_id = session['user_id']` 추가 |
| `UPDATE/DELETE ingredients` | `AND user_id = get_view_user_id()` 추가 |
| `SELECT * FROM meals` | `WHERE user_id = get_view_user_id()` 추가 |
| `INSERT INTO meals` | `user_id = session['user_id']` 추가 |
| `UPDATE/DELETE meals` | `AND user_id = get_view_user_id()` 추가 |
| Discord 저재고 알림 | `WHERE user_id = get_view_user_id()` 추가 |

### 신규 관리자 API

```
POST /api/admin/switch-user
  body: {"user_id": N}
  → session['view_as_user_id'] = N
  → 200 {"username": "..."}
  → 403 if not admin

DELETE /api/admin/switch-user
  → session['view_as_user_id'] = session['user_id']
  → 200 {"ok": true}
```

---

## 프론트엔드 변경

### 서버 사이드 (`_base.html` 또는 각 페이지 템플릿)

- `is_admin` 이면 네비게이션에 사용자 전환 `<select>` 드롭다운 표시
- 드롭다운 선택 시 `POST /api/admin/switch-user` 호출 후 `location.reload()`
- `view_as_user_id != user_id` 이면 상단 배너 표시:
  `👁 [username] 계정 보는 중 — 클릭하여 본인 계정으로 복귀`

### 렌더링에 필요한 템플릿 변수

Flask `render_template` 호출에 다음 추가:
```python
view_username=<현재 view_as 계정의 username>,
is_viewing_other=(session['view_as_user_id'] != session['user_id']),
all_users=<admin이면 전체 users 목록, 아니면 None>
```

---

## 에러 처리

- 일반 사용자가 `POST /api/admin/switch-user` 호출 시 → 403
- `view_as_user_id`에 존재하지 않는 user_id가 들어오면 → 400
- DELETE/PUT 시 `user_id` 불일치(다른 계정 데이터 접근) → 404 반환 (정보 노출 방지)

---

## 테스트 포인트

- 일반 사용자 A가 B의 재료를 볼 수 없음
- 관리자가 B로 전환 후 B의 재료 조회 가능
- 관리자가 B로 전환 중 재료 추가 시 → B 계정 소유 재료로 생성
- 본인 복귀 후 자기 데이터만 보임
- 일반 사용자의 switch-user 호출 → 403
