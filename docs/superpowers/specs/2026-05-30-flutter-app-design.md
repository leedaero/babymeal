# 치밀한 이유식 — Flutter 안드로이드 앱 설계

**날짜:** 2026-05-30  
**범위:** 기존 Flask 웹앱(babymeal)의 안드로이드 네이티브 앱 구현  
**방식:** 기존 Flask에 JWT 인증 추가 + Flutter 앱 신규 개발

---

## 1. 목표

기존 홈서버 웹앱(치밀한 이유식)을 안드로이드 앱으로 제공한다.  
웹앱과 동일한 기능을 네이티브 UI로 구현하고, FCM 백그라운드 푸시 알림을 지원한다.  
기존 Flask 웹앱은 변경 없이 그대로 동작해야 한다.

---

## 2. 아키텍처 개요

```
┌─────────────────────────────────────────────┐
│  안드로이드 앱 (Flutter)                      │
│  ┌─────────┐  JWT Bearer  ┌───────────────┐ │
│  │   Dio   │ ───────────▶ │  Flask API    │ │
│  │ client  │              │  (기존 + JWT) │ │
│  └─────────┘              └───────┬───────┘ │
│                                   │         │
│  ┌──────────────┐        ┌────────▼──────┐  │
│  │ firebase_    │◀───────│  FCM send     │  │
│  │ messaging   │  push   │  (신규)       │  │
│  └──────────────┘        └───────────────┘  │
└─────────────────────────────────────────────┘
         Cloudflare Tunnel (외부 접속)
```

- Flutter 앱 → Cloudflare Tunnel 도메인 → Flask 서버 (내부 192.168.0.34:8990)
- 인증: JWT Access Token (1시간) + Refresh Token (30일)
- 푸시: Flask → Firebase Admin SDK → FCM → 안드로이드

---

## 3. 레포 구조

```
babymeal/
├── web/                    ← 기존 Flask 웹앱 (변경 최소화)
│   └── app.py              ← JWT 인증 + FCM 발송 로직 추가
├── flutter/                ← 신규 Flutter 프로젝트
│   └── babymeal_app/
│       ├── lib/
│       │   ├── main.dart
│       │   ├── core/
│       │   │   ├── api/        ← Dio client, interceptors
│       │   │   ├── auth/       ← JWT 저장/갱신
│       │   │   └── push/       ← FCM 초기화
│       │   ├── features/
│       │   │   ├── login/
│       │   │   ├── inventory/
│       │   │   ├── schedule/
│       │   │   ├── allergy/
│       │   │   ├── stats/
│       │   │   └── settings/
│       │   └── shared/
│       │       └── widgets/    ← 공통 컴포넌트
│       ├── android/
│       │   └── app/google-services.json  ← Firebase 설정 (gitignore)
│       └── pubspec.yaml
└── requirements.txt         ← PyJWT, firebase-admin 추가
```

---

## 4. 백엔드 변경 (Flask)

### 4.1 신규 엔드포인트

| 메서드 | 경로 | 역할 |
|--------|------|------|
| POST | `/api/auth/login` | username+password → access_token + refresh_token |
| POST | `/api/auth/refresh` | refresh_token → 새 access_token |
| POST | `/api/auth/logout` | refresh_token 무효화 |
| POST | `/api/push/fcm-token` | FCM 디바이스 토큰 DB 저장 |
| DELETE | `/api/push/fcm-token` | FCM 토큰 삭제 |

### 4.2 기존 API 수정

모든 `@login_required` 데코레이터가 세션 쿠키 외에 `Authorization: Bearer <JWT>` 헤더도 인식하도록 수정한다.  
기존 세션 방식(웹앱)은 그대로 유지된다.

### 4.3 FCM 발송

- `_send_realtime_alert()` 및 `_send_low_stock_notification()` 내부에서  
  Discord 웹훅 발송 직후 FCM 발송도 실행한다.
- FCM 토큰은 `push_subscriptions_fcm` 테이블에 저장 (user_id, token, created_at).
- `firebase-admin` SDK로 발송. Firebase 서비스 계정 JSON 경로는 `config.json`에 추가.

### 4.4 JWT 스펙

```
Access Token:  HS256, exp=1h,  payload: {user_id, username, is_admin}
Refresh Token: HS256, exp=30d, payload: {user_id, jti(고유ID)}
```

Refresh Token은 DB에 저장하여 로그아웃 시 무효화 가능.  
SECRET_KEY는 기존 Flask `SECRET_KEY` 재사용.

### 4.5 의존성 추가

```
PyJWT>=2.8.0
firebase-admin>=6.5.0
```

---

## 5. Flutter 앱 상세 설계

### 5.1 기술 스택

| 역할 | 패키지 |
|------|--------|
| 상태 관리 | `flutter_riverpod` |
| HTTP 클라이언트 | `dio` |
| 보안 저장소 | `flutter_secure_storage` |
| 푸시 알림 | `firebase_messaging` |
| 달력 UI | `table_calendar` |
| 차트 | `fl_chart` |
| 로컬 알림 표시 | `flutter_local_notifications` |

### 5.2 화면 목록

```
SplashScreen         ← 토큰 유무 확인, 자동 로그인
└── LoginScreen      ← username / password 입력, 서버 URL 설정
    └── MainShell    ← BottomNavigationBar (5탭)
        ├── InventoryScreen    ← 재고현황
        ├── ScheduleScreen     ← 식단표
        ├── AllergyScreen      ← 알러지 테스트
        ├── StatsScreen        ← 통계
        └── SettingsScreen     ← 설정 + 사용자 관리(admin)
```

### 5.3 화면별 기능

**InventoryScreen (재고현황)**
- 재료 목록: 이모지 + 이름 + 현재 재고 큐브 수
- 유통기한 경고 (제작일 기준 지난 재료 빨간 표시)
- 각 재료 행에서 +/- 버튼으로 재고 즉시 조정
- 재료 추가/수정/삭제 (다이얼로그)
- 재료 탭 → 로그 히스토리 조회

**ScheduleScreen (식단표)**
- 월간 캘린더 (`table_calendar`)
- 날짜 선택 시 해당 날 식단 목록 표시
- 각 식단: 먹었어요(파랑) / 안먹었어요(노랑) / 건너뜀(빨강) 상태 변경
- 상태 변경 시 재고 자동 차감/복원
- 식단 추가/수정/삭제

**AllergyScreen (알러지 테스트)**
- 월간 캘린더
- 날짜 선택 시 해당 날 테스트 목록 표시
- 새 재료 첫 시도 날짜 + 이모지 + 메모(자유 텍스트) 기록
- CRUD

**StatsScreen (통계)**
- 재료별 현재 재고 바차트 (`fl_chart`)
- 가로 스크롤 지원

**SettingsScreen (설정)**
- 서버 URL 변경
- Discord 웹훅 URL 입력/저장
- 재고 알림 기준치 설정
- 수동 알림 테스트 버튼
- FCM 푸시 알림 ON/OFF
- [admin만 노출] 사용자 관리 (추가/삭제/활성화)
- 로그아웃

### 5.4 인증 플로우

```
앱 시작
  → flutter_secure_storage에서 access_token 로드
  → 토큰 없음 → LoginScreen
  → 토큰 있음 → 유효성 검사 → 유효 → MainShell
                              → 만료 → refresh_token으로 갱신 시도
                                       → 성공 → MainShell
                                       → 실패 → LoginScreen
```

Dio 인터셉터가 401 응답 시 자동으로 토큰 갱신 후 재요청.

### 5.5 서버 URL 설정

최초 실행 시 또는 LoginScreen에서 서버 URL 입력 가능.  
예: `https://babymeal.example.com`  
`flutter_secure_storage`에 저장.

### 5.6 FCM 설정

- 앱 시작 시 FCM 토큰 취득 → `/api/push/fcm-token`에 저장
- `firebase_messaging` 핸들러:
  - Foreground: `flutter_local_notifications`로 배너 표시
  - Background/Terminated: 시스템 알림으로 자동 표시

---

## 6. 데이터베이스 변경

```sql
-- Refresh Token 저장
CREATE TABLE refresh_tokens (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    jti        VARCHAR(64) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    revoked    TINYINT(1) DEFAULT 0
);

-- FCM 토큰 저장
CREATE TABLE push_subscriptions_fcm (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT NOT NULL,
    token      TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 7. config.json 변경

```json
{
  "firebase": {
    "service_account_path": "/path/to/firebase-service-account.json"
  }
}
```

`google-services.json` (Flutter용) 및 `firebase-service-account.json` (Flask용)은 `.gitignore`에 추가.

---

## 8. 구현 단계

| 단계 | 내용 | 예상 시간 |
|------|------|---------|
| 1 | Flask JWT 인증 추가 (`/api/auth/*`, login_required 수정) | 1일 |
| 2 | Flask FCM 발송 추가 (테이블, 엔드포인트, 알림 연동) | 0.5일 |
| 3 | Flutter 프로젝트 생성 + 기본 구조 + 인증 화면 | 1일 |
| 4 | InventoryScreen 구현 | 1일 |
| 5 | ScheduleScreen 구현 (캘린더) | 1.5일 |
| 6 | AllergyScreen 구현 | 0.5일 |
| 7 | StatsScreen + SettingsScreen 구현 | 1일 |
| 8 | FCM 연동 + 테스트 | 0.5일 |
| **합계** | | **약 7일** |

---

## 9. 제외 범위

- iOS 지원 (안드로이드만)
- 플레이스토어 배포 (로컬 APK 빌드만)
- 오프라인 캐시 (인터넷 연결 필수)
- 관리자 유저 전환 기능 (admin switch-user) — 웹에서만 사용
