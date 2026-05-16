# 치밀한 이유식 🍼

아기 이유식 큐브 재고·식단·알러지 테스트를 한 곳에서 관리하는 홈서버용 웹앱입니다.

## 주요 기능

| 탭 | 기능 |
|---|---|
| **재고현황** | 큐브 재료별 재고 확인, +/- 버튼으로 실시간 조정, 유통기한(제작일 기준) 경고 |
| **식단표** | 월간 캘린더 식단 계획, 먹었어요/안먹었어요/건너뜀 3단계 상태 관리, 상태 변경 시 자동 재고 차감/복원 |
| **알러지 테스트** | 새 재료 첫 시도 날짜·반응 기록, 월간 캘린더 뷰 |
| **통계** | 재료별 재고 현황 바차트 |
| **설정** | Discord 웹훅 URL, 재고 알림 기준치 설정, 수동 알림 테스트 |

### Discord 실시간 알림
- 재고 −/+ 조정 후 기준치 이하가 되면 즉시 알림
- 식단에서 "먹었어요" 처리 시 차감 후 기준치 이하 재료 즉시 알림

## 기술 스택

- **Backend**: Python / Flask, PyMySQL, APScheduler
- **Frontend**: Alpine.js, Chart.js, Twemoji
- **DB**: MySQL
- **이미지 저장**: MinIO (선택)
- **배포**: systemd 서비스, GitHub Actions self-hosted runner

## 설치 및 실행

### 1. 저장소 클론

```bash
git clone https://github.com/leedaero/babymeal.git
cd babymeal
pip3 install -r requirements.txt
```

### 2. DB 생성

```sql
CREATE DATABASE babymeal CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

테이블은 앱 첫 실행 시 자동 생성됩니다.

### 3. 설정 파일

```bash
cp config.example.json config.json
```

`config.json` 수정:

```json
{
  "db": {
    "host": "DB_HOST",
    "port": 3306,
    "user": "DB_USER",
    "password": "DB_PASSWORD",
    "database": "babymeal"
  },
  "secret_key": "랜덤_시크릿_키",
  "port": 8990,
  "minio": {
    "endpoint": "MINIO_HOST:9000",
    "access_key": "ACCESS_KEY",
    "secret_key": "SECRET_KEY",
    "bucket": "babymeal",
    "secure": false
  }
}
```

> Discord 웹훅 URL은 앱 내 설정 탭에서 입력합니다 (DB 저장, git pull에 덮어씌워지지 않음).

### 4. 실행

```bash
python3 web/app.py --port 8990
```

## systemd 서비스 등록 (홈서버)

```bash
sudo cp babymeal.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now babymeal
```

`babymeal.service` 내 경로(`WorkingDirectory`, `ExecStart`)와 `User`를 환경에 맞게 수정하세요.

## 자동 배포 (GitHub Actions)

`docker-compose.yml`의 self-hosted runner가 `main` 브랜치 push를 감지하면 `deploy.sh`를 실행합니다.

```bash
# deploy.sh 내용
git pull origin main
pip3 install -r requirements.txt --quiet
sudo systemctl restart babymeal
```

runner 등록 시 필요한 환경 변수:

```
ACCESS_TOKEN=GitHub Personal Access Token
```

## 재고 상태 로직

```
먹었어요 (confirmed)   → 큐브 차감, 파란색
안먹었어요 (upcoming)  → 차감 없음, 노란색 (아직 먹일 예정)
건너뜀 (skipped)       → 차감 없음, 빨간색 (해당 식단 취소)
```

상태를 `confirmed → upcoming/skipped`으로 되돌리면 차감된 큐브가 자동 복원됩니다.

## MinIO (이미지 저장, 선택)

설정하지 않아도 동작합니다. 설정 시 재료 이모지가 Twemoji PNG로 MinIO에 저장되어 오프라인 환경에서도 이미지가 표시됩니다.
