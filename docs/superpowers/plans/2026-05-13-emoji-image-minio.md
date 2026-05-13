# Emoji Image MinIO Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 재료 저장 시 이모지를 Twemoji PNG로 변환해 MinIO에 캐싱하고, DB `image_url`에 저장하며, 큐브카드에서 이미지로 표시한다.

**Architecture:** `emoji_image.py`가 이모지→코드포인트 변환, Twemoji CDN 다운로드, MinIO 업로드를 담당한다. POST/PUT `/api/ingredients` 저장 후 자동으로 이미지 캐싱, GET `/api/emoji/<codepoint>` 프록시 라우트로 서빙한다. MinIO 미설정 시 graceful fallback (image_url = NULL, 텍스트 이모지 표시).

**Tech Stack:** Python `minio` SDK, Twemoji CDN (cdnjs.cloudflare.com/libs/twemoji/14.0.2/72x72), MinIO (NAS Docker), Flask, Alpine.js

---

## 파일 구조

| 파일 | 변경 |
|---|---|
| `minio_storage.py` | 신규 — animation 프로젝트에서 복사 |
| `emoji_image.py` | 신규 — 이모지 변환 + MinIO 저장 |
| `tests/test_emoji_image.py` | 신규 — emoji_image 단위 테스트 |
| `migrate_image_url.sql` | 신규 — DB 마이그레이션 |
| `web/app.py` | 수정 — imports, proxy route, POST/PUT 수정 |
| `tests/test_api.py` | 수정 — proxy route 테스트 추가 |
| `web/templates/inventory.html` | 수정 — cube-icon 이미지/텍스트 토글 |
| `backfill_emoji_images.py` | 신규 — 기존 재료 일괄 처리 |
| `config.example.json` | 수정 — minio 섹션 추가 |
| `requirements.txt` | 수정 — minio 추가 |

---

### Task 1: minio_storage.py 복사 + requirements.txt 업데이트

**Files:**
- Create: `minio_storage.py`
- Modify: `requirements.txt`

- [ ] **Step 1: animation 프로젝트에서 minio_storage.py 복사**

```bash
cp /Users/idaelo/project/animation/minio_storage.py /Users/idaelo/project/babyMeal/minio_storage.py
```

- [ ] **Step 2: requirements.txt에 minio 추가**

`requirements.txt` 끝에 추가:
```
minio>=7.2
```

- [ ] **Step 3: 설치 확인**

```bash
cd /Users/idaelo/project/babyMeal && pip install minio --quiet && python -c "import minio_storage; print('OK')"
```
Expected: `OK`

- [ ] **Step 4: 커밋**

```bash
git add minio_storage.py requirements.txt
git commit -m "feat: add minio_storage utility (ported from animation project)"
```

---

### Task 2: emoji_to_codepoint TDD

**Files:**
- Create: `tests/test_emoji_image.py`
- Create: `emoji_image.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_emoji_image.py` 생성:
```python
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from emoji_image import emoji_to_codepoint


def test_single_codepoint():
    assert emoji_to_codepoint('🥕') == '1f955'


def test_single_codepoint_pumpkin():
    assert emoji_to_codepoint('🎃') == '1f383'


def test_vs16_stripped():
    # ❤️ = U+2764 U+FE0F — VS16 must be removed
    assert emoji_to_codepoint('❤️') == '2764'


def test_zwj_sequence():
    # 👨‍🍳 = U+1F468 U+200D U+1F373
    assert emoji_to_codepoint('👨‍🍳') == '1f468-200d-1f373'
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/idaelo/project/babyMeal && python -m pytest tests/test_emoji_image.py -v 2>&1 | head -20
```
Expected: `ImportError` 또는 `ModuleNotFoundError`

- [ ] **Step 3: emoji_image.py 최소 구현**

프로젝트 루트에 `emoji_image.py` 생성:
```python
import logging
import urllib.request

logger = logging.getLogger('emoji_image')

TWEMOJI_BASE = 'https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/72x72'


def emoji_to_codepoint(emoji: str) -> str:
    """이모지 문자 → Twemoji 파일명. VS16(U+FE0F) 제거."""
    return '-'.join(f'{ord(c):x}' for c in emoji if ord(c) != 0xFE0F)
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
python -m pytest tests/test_emoji_image.py -v
```
Expected: 4 tests PASSED

- [ ] **Step 5: 커밋**

```bash
git add emoji_image.py tests/test_emoji_image.py
git commit -m "feat: add emoji_to_codepoint (Twemoji naming convention)"
```

---

### Task 3: fetch_twemoji_png + save_emoji_image TDD

**Files:**
- Modify: `tests/test_emoji_image.py`
- Modify: `emoji_image.py`

- [ ] **Step 1: 실패하는 테스트 추가** (`tests/test_emoji_image.py` 에 append)

```python
from unittest.mock import patch, MagicMock
from emoji_image import fetch_twemoji_png, save_emoji_image


def test_fetch_twemoji_png_success():
    fake_data = b'\x89PNG\r\n'
    mock_resp = MagicMock()
    mock_resp.read.return_value = fake_data
    with patch('urllib.request.urlopen', return_value=mock_resp):
        result = fetch_twemoji_png('1f955')
    assert result == fake_data


def test_fetch_twemoji_png_failure():
    with patch('urllib.request.urlopen', side_effect=Exception('timeout')):
        result = fetch_twemoji_png('1f955')
    assert result is None


def test_save_emoji_image_no_client():
    assert save_emoji_image(None, 'babymeal', '🥕') is None


def test_save_emoji_image_already_cached():
    mc = MagicMock()
    mc.stat_object.return_value = MagicMock()  # exists
    result = save_emoji_image(mc, 'babymeal', '🥕')
    assert result == '/api/emoji/1f955'
    mc.stat_object.assert_called_once_with('babymeal', 'emoji/1f955.png')


def test_save_emoji_image_new_upload():
    mc = MagicMock()
    mc.stat_object.side_effect = Exception('not found')
    with patch('emoji_image.fetch_twemoji_png', return_value=b'PNG'), \
         patch('emoji_image.upload_bytes', return_value=True):
        result = save_emoji_image(mc, 'babymeal', '🥕')
    assert result == '/api/emoji/1f955'


def test_save_emoji_image_twemoji_unavailable():
    mc = MagicMock()
    mc.stat_object.side_effect = Exception('not found')
    with patch('emoji_image.fetch_twemoji_png', return_value=None):
        result = save_emoji_image(mc, 'babymeal', '🥕')
    assert result is None
```

- [ ] **Step 2: 실패 확인**

```bash
python -m pytest tests/test_emoji_image.py -v 2>&1 | tail -15
```
Expected: `ImportError: cannot import name 'fetch_twemoji_png'`

- [ ] **Step 3: emoji_image.py 완성**

`emoji_image.py` 전체를 다음으로 교체:
```python
import logging
import urllib.request

logger = logging.getLogger('emoji_image')

TWEMOJI_BASE = 'https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/72x72'


def emoji_to_codepoint(emoji: str) -> str:
    """이모지 문자 → Twemoji 파일명. VS16(U+FE0F) 제거."""
    return '-'.join(f'{ord(c):x}' for c in emoji if ord(c) != 0xFE0F)


def fetch_twemoji_png(codepoint: str) -> bytes | None:
    url = f'{TWEMOJI_BASE}/{codepoint}.png'
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        resp = urllib.request.urlopen(req, timeout=10)
        return resp.read()
    except Exception as e:
        logger.debug(f'Twemoji fetch failed [{codepoint}]: {e}')
        return None


def save_emoji_image(minio_client, bucket: str, emoji: str) -> str | None:
    """MinIO에 이모지 PNG를 캐싱하고 프록시 URL을 반환. 실패 시 None."""
    if not minio_client:
        return None
    from minio_storage import upload_bytes
    codepoint = emoji_to_codepoint(emoji)
    key = f'emoji/{codepoint}.png'
    proxy_url = f'/api/emoji/{codepoint}'
    try:
        minio_client.stat_object(bucket, key)
        return proxy_url
    except Exception:
        pass
    data = fetch_twemoji_png(codepoint)
    if not data:
        return None
    if upload_bytes(minio_client, bucket, key, data, 'image/png'):
        return proxy_url
    return None
```

- [ ] **Step 4: 전체 테스트 통과 확인**

```bash
python -m pytest tests/test_emoji_image.py -v
```
Expected: 10 tests PASSED

- [ ] **Step 5: 커밋**

```bash
git add emoji_image.py tests/test_emoji_image.py
git commit -m "feat: add fetch_twemoji_png and save_emoji_image"
```

---

### Task 4: DB 마이그레이션

**Files:**
- Create: `migrate_image_url.sql`

- [ ] **Step 1: 마이그레이션 파일 생성**

`migrate_image_url.sql` 생성:
```sql
ALTER TABLE ingredients
  ADD COLUMN image_url VARCHAR(255) DEFAULT NULL;
```

- [ ] **Step 2: DB에 적용**

```bash
mysql -h 192.168.0.34 -u root -p babymeal < migrate_image_url.sql
```
Expected: 오류 없이 완료. 이미 적용됐다면 `Duplicate column name 'image_url'` 오류 — 무시.

- [ ] **Step 3: 적용 확인**

```bash
mysql -h 192.168.0.34 -u root -p babymeal -e "DESCRIBE ingredients;"
```
Expected: `image_url` 컬럼이 목록에 있어야 함.

- [ ] **Step 4: 커밋**

```bash
git add migrate_image_url.sql
git commit -m "feat: add image_url column to ingredients table"
```

---

### Task 5: GET /api/emoji/<codepoint> 프록시 라우트 TDD

**Files:**
- Modify: `web/app.py` (imports + 라우트 추가)
- Modify: `tests/test_api.py`

- [ ] **Step 1: 실패하는 테스트 추가** (`tests/test_api.py` 끝에 append)

```python
def test_api_emoji_image_found(authed_client):
    with patch('web.app._db.load_config', return_value={'minio': {'bucket': 'babymeal'}}), \
         patch('web.app.minio_storage.get_minio_client', return_value=MagicMock()), \
         patch('web.app.minio_storage.get_bytes', return_value=(b'\x89PNG', 'image/png')):
        resp = authed_client.get('/api/emoji/1f955')
    assert resp.status_code == 200
    assert resp.content_type == 'image/png'
    assert resp.data == b'\x89PNG'


def test_api_emoji_image_not_found(authed_client):
    with patch('web.app._db.load_config', return_value={'minio': {}}), \
         patch('web.app.minio_storage.get_minio_client', return_value=None), \
         patch('web.app.minio_storage.get_bytes', return_value=(None, None)):
        resp = authed_client.get('/api/emoji/unknown')
    assert resp.status_code == 404
```

- [ ] **Step 2: 실패 확인**

```bash
python -m pytest tests/test_api.py::test_api_emoji_image_found tests/test_api.py::test_api_emoji_image_not_found -v
```
Expected: `404` (라우트 없음)

- [ ] **Step 3: web/app.py — imports 수정**

`web/app.py` 상단 flask import에 `make_response` 추가:
```python
# 변경 전
from flask import (
    Flask, render_template, request, redirect,
    url_for, session, jsonify, flash, g,
)

# 변경 후
from flask import (
    Flask, render_template, request, redirect,
    url_for, session, jsonify, flash, g, make_response,
)
```

`import db as _db` 아래에 추가:
```python
import minio_storage
from emoji_image import save_emoji_image
```

- [ ] **Step 4: 재료 adjust 라우트(line ~424) 바로 뒤에 프록시 라우트 추가**

`# ─── 식단 API` 주석 바로 앞에 삽입:
```python
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
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
python -m pytest tests/test_api.py::test_api_emoji_image_found tests/test_api.py::test_api_emoji_image_not_found -v
```
Expected: 2 tests PASSED

- [ ] **Step 6: 전체 테스트 통과 확인**

```bash
python -m pytest tests/ -v
```
Expected: 전체 PASSED (기존 테스트 깨지지 않아야 함)

- [ ] **Step 7: 커밋**

```bash
git add web/app.py tests/test_api.py
git commit -m "feat: add GET /api/emoji/<codepoint> MinIO proxy route"
```

---

### Task 6: POST/PUT /api/ingredients → 이모지 이미지 저장

**Files:**
- Modify: `web/app.py` (POST + PUT 핸들러)

- [ ] **Step 1: POST 핸들러 수정** (`api_ingredients_add`)

`conn.commit()` 이후, `return jsonify(...)` 직전에 다음 코드 추가:

```python
    # 변경 전 (현재 코드)
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
    return jsonify(_fmt_ingredient(cur.fetchone())), 201

    # 변경 후
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
```

- [ ] **Step 2: PUT 핸들러 수정** (`api_ingredients_update`)

```python
    # 변경 전
    cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s', {**d, 'id': ing_id})
    conn.commit()
    cur.execute('SELECT * FROM ingredients WHERE id=%s', (ing_id,))
    return jsonify(_fmt_ingredient(cur.fetchone()))

    # 변경 후
    cur.execute(f'UPDATE ingredients SET {sets} WHERE id=%(id)s', {**d, 'id': ing_id})
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
```

- [ ] **Step 3: 전체 테스트 통과 확인**

```bash
python -m pytest tests/ -v
```
Expected: 전체 PASSED

- [ ] **Step 4: 커밋**

```bash
git add web/app.py
git commit -m "feat: save emoji image to MinIO on ingredient create/update"
```

---

### Task 7: 프론트엔드 — 큐브카드 이미지 표시

**Files:**
- Modify: `web/templates/inventory.html`

- [ ] **Step 1: cube-icon 수정**

`inventory.html` line 28:
```html
<!-- 변경 전 -->
<div class="cube-icon" :style="`background-color:${ing.color}22`" x-text="ing.emoji"></div>

<!-- 변경 후 -->
<div class="cube-icon" :style="`background-color:${ing.color}22`">
  <template x-if="ing.image_url">
    <img :src="ing.image_url" width="40" height="40"
         style="object-fit:contain;display:block;" alt="">
  </template>
  <template x-if="!ing.image_url">
    <span x-text="ing.emoji"></span>
  </template>
</div>
```

- [ ] **Step 2: 개발 서버 실행 후 브라우저 확인**

```bash
cd /Users/idaelo/project/babyMeal && python web/app.py
```

브라우저에서 `http://localhost:8990` 접속:
- MinIO 설정이 있는 재료: 이모지 PNG 이미지 표시
- image_url이 없는 재료: 기존 텍스트 이모지 표시 (폴백 정상)

- [ ] **Step 3: 커밋**

```bash
git add web/templates/inventory.html
git commit -m "feat: show emoji PNG image in cube-card, fallback to text"
```

---

### Task 8: config.example.json + backfill 스크립트

**Files:**
- Modify: `config.example.json`
- Create: `backfill_emoji_images.py`

- [ ] **Step 1: config.example.json에 minio 섹션 추가**

`config.example.json`을 열어 최상위 객체에 추가:
```json
{
  "db": { ... },
  "secret_key": "CHANGE_ME_RANDOM_STRING",
  "port": 8990,
  "debug": false,
  "discord_webhook": "",
  "web": { "trusted_proxies": [] },
  "minio": {
    "endpoint": "192.168.0.34:9000",
    "access_key": "YOUR_MINIO_ACCESS_KEY",
    "secret_key": "YOUR_MINIO_SECRET_KEY",
    "bucket": "babymeal",
    "secure": false
  }
}
```

- [ ] **Step 2: backfill_emoji_images.py 생성**

프로젝트 루트에 `backfill_emoji_images.py` 생성:
```python
#!/usr/bin/env python3
"""기존 재료의 이모지 이미지를 MinIO에 일괄 업로드한다."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import db as _db
import minio_storage
from emoji_image import save_emoji_image


def main():
    cfg = _db.load_config()
    mc = minio_storage.get_minio_client(cfg)
    if not mc:
        print('MinIO 미설정 또는 연결 실패. config.json의 minio 섹션을 확인하세요.')
        sys.exit(1)

    bucket = cfg.get('minio', {}).get('bucket', 'babymeal')
    minio_storage.ensure_bucket(mc, bucket)
    print(f'버킷: {bucket}')

    conn = _db.get_connection(cfg)
    cur = conn.cursor()
    cur.execute('SELECT id, name, emoji FROM ingredients WHERE image_url IS NULL')
    rows = cur.fetchall()
    print(f'처리 대상: {len(rows)}건\n')

    ok = fail = 0
    for row in rows:
        img_url = save_emoji_image(mc, bucket, row['emoji'])
        if img_url:
            cur.execute('UPDATE ingredients SET image_url=%s WHERE id=%s', (img_url, row['id']))
            conn.commit()
            print(f'  ✓ {row["name"]} {row["emoji"]} → {img_url}')
            ok += 1
        else:
            print(f'  ✗ {row["name"]} {row["emoji"]} (Twemoji 미지원)')
            fail += 1

    print(f'\n완료: {ok}건 성공, {fail}건 실패')


if __name__ == '__main__':
    main()
```

- [ ] **Step 3: 스크립트 실행 (프로덕션 DB)**

```bash
cd /Users/idaelo/project/babyMeal && python backfill_emoji_images.py
```
Expected:
```
버킷: babymeal
처리 대상: N건

  ✓ 당근 🥕 → /api/emoji/1f955
  ...
완료: N건 성공, 0건 실패
```

- [ ] **Step 4: 커밋**

```bash
git add config.example.json backfill_emoji_images.py
git commit -m "feat: add backfill script and minio config example"
```

---

## 완료 체크리스트

- [ ] `python -m pytest tests/ -v` 전체 통과
- [ ] 브라우저에서 큐브카드 이모지 이미지 표시 확인
- [ ] 새 재료 추가 → MinIO에 이미지 저장 확인
- [ ] image_url 없는 재료 → 텍스트 이모지 폴백 확인
- [ ] backfill 스크립트 실행 완료
