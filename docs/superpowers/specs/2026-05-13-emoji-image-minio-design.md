# 이모지 이미지 MinIO 저장 설계

**날짜**: 2026-05-13  
**범위**: babyMeal — 재료 이모지를 Twemoji PNG로 변환하여 MinIO에 저장하고 DB에 URL 기록

---

## 목표

재료(ingredient)에 저장된 이모지 문자를 실제 PNG 이미지로 변환해 NAS MinIO에 캐싱하고, DB에 `image_url`을 저장해 프론트에서 이미지로 표시한다.

---

## 아키텍처

### 데이터 흐름

```
재료 저장 (POST/PUT /api/ingredients)
  │
  ├─ emoji 문자 → 코드포인트 hex 변환 (예: 🥕 → "1f955")
  │
  ├─ MinIO에 emoji/1f955.png 존재 확인
  │    ├─ 있으면: 재사용 (업로드 스킵)
  │    └─ 없으면: Twemoji CDN → 다운로드 → MinIO 업로드
  │
  └─ DB ingredients.image_url = "/api/emoji/1f955"

GET /api/emoji/<codepoint>
  └─ MinIO에서 가져와 이미지 응답 (Cache-Control 7일)
```

### 파일 구성

| 파일 | 역할 |
|---|---|
| `minio_storage.py` | animation 프로젝트에서 복사. MinIO 클라이언트, 업로드/다운로드 유틸 |
| `emoji_image.py` | 이모지 → 코드포인트 변환, Twemoji 다운로드, MinIO 저장 |
| `web/app.py` | `/api/emoji/<codepoint>` proxy route 추가, POST/PUT ingredients 수정 |
| `backfill_emoji_images.py` | 기존 재료 전체 일괄 처리 스크립트 |
| `migrate_image_url.sql` | DB 마이그레이션 |
| `config.example.json` | `minio` 섹션 추가 |

---

## DB 변경

```sql
ALTER TABLE ingredients
  ADD COLUMN image_url VARCHAR(255) DEFAULT NULL;
```

---

## 신규 모듈: `emoji_image.py`

```python
# 핵심 함수 시그니처

def emoji_to_codepoint(emoji: str) -> str:
    """이모지 문자 → Twemoji 파일명 hex 문자열 (ZWJ 시퀀스 포함)"""
    # 예: 🥕 → "1f955"
    # 예: 👨‍🍳 → "1f468-200d-1f373"

def fetch_twemoji_png(codepoint: str) -> bytes | None:
    """Twemoji CDN에서 PNG 다운로드. 실패/미지원 시 None"""
    # URL: https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/72x72/{codepoint}.png

def save_emoji_image(minio_client, bucket: str, emoji: str) -> str | None:
    """MinIO에 업로드하고 proxy URL 반환. 실패 시 None"""
    # MinIO key: emoji/{codepoint}.png
    # 반환: "/api/emoji/{codepoint}"
    # 이미 존재하면 업로드 스킵하고 URL만 반환
```

**코드포인트 변환 규칙**:
- 단일 이모지: `1f955`
- ZWJ 시퀀스: 각 코드포인트를 `-`로 연결 (Twemoji 파일명 규칙 그대로)
- VS16(`️`) 제거 (Twemoji는 VS16 없는 이름 사용)
- Twemoji가 지원하지 않는 이모지(Unicode 16.0 등, 예: `🫜`)는 `None` 반환 → `image_url = NULL` 유지

---

## API 변경

### POST/PUT `/api/ingredients`

기존 저장 로직 뒤에 추가:

```python
image_url = save_emoji_image(minio_client, bucket, form['emoji'])
if image_url:
    cur.execute('UPDATE ingredients SET image_url=%s WHERE id=%s', (image_url, ing_id))
```

응답 JSON에 `image_url` 포함.

### 신규: GET `/api/emoji/<codepoint>`

```python
@app.get('/api/emoji/<codepoint>')
def api_emoji_image(codepoint):
    # MinIO에서 emoji/{codepoint}.png 조회
    # 성공: image/png 응답, Cache-Control: public, max-age=604800
    # 실패: 404
```

---

## 프론트엔드 변경

### 큐브카드 (`inventory.html`)

```html
<!-- 변경 전 -->
<div class="cube-icon" x-text="ing.emoji"></div>

<!-- 변경 후 -->
<div class="cube-icon">
  <img x-show="ing.image_url" :src="ing.image_url"
       width="40" height="40" style="object-fit:contain">
  <span x-show="!ing.image_url" x-text="ing.emoji"></span>
</div>
```

### 모달 이모지 선택 미리보기 (`app.js`)

선택된 이모지 미리보기 영역도 동일 패턴 적용. 단, 모달에서는 이미지가 아직 없을 수 있으므로 이모지 텍스트를 항상 표시하고 이미지는 보조로.

---

## 배치 스크립트: `backfill_emoji_images.py`

```
기존 ingredients 중 image_url IS NULL인 항목 전체 처리
각 재료: save_emoji_image() → DB UPDATE
처리 결과 요약 출력 (성공/실패/스킵 카운트)
```

실행: `python backfill_emoji_images.py`

---

## config.example.json 추가

```json
"minio": {
  "endpoint": "192.168.0.34:9000",
  "access_key": "YOUR_MINIO_ACCESS_KEY",
  "secret_key": "YOUR_MINIO_SECRET_KEY",
  "bucket": "babymeal",
  "secure": false
}
```

---

## 에러 처리

- MinIO 미설정(config에 `minio` 없음): `save_emoji_image` 가 `None` 반환, image_url은 NULL. 앱은 정상 동작.
- Twemoji 미지원 이모지: `None` 반환, image_url NULL, 이모지 텍스트 폴백.
- MinIO 연결 실패: 로그 경고 후 None 반환. 재료 저장 자체는 실패하지 않음.

---

## 테스트 포인트

- `emoji_to_codepoint()` 단위 테스트: 단일 이모지, ZWJ, VS16 제거
- `save_emoji_image()`: MinIO mock으로 업로드/캐시 히트 검증
- POST /api/ingredients: image_url 포함 여부 확인
- GET /api/emoji/<codepoint>: 이미지 응답 및 404 처리
- 프론트: image_url 있을 때 img 표시, 없을 때 텍스트 폴백
