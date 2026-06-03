# babymeal 프로젝트 가이드

## 작업 완료 후 필수 사항

- 작업이 끝나면 항상 커밋 → 푸시까지 완료할 것
- **PR 생성은 모바일 환경에서 작업할 때만** 수행할 것 (PC에서는 PR 생성 불필요)
- **Flutter 앱 변경 시 반드시 릴리즈 APK 빌드 + 에뮬레이터 APK 빌드 → Firebase App Distribution 배포까지 완료할 것**

## Firebase App Distribution 배포

앱 변경이 있을 때마다 아래 순서로 배포한다.

### 1. pubspec.yaml 버전 올리기

`flutter/babymeal_app/pubspec.yaml` 의 version 줄을 수정:
```
version: X.X.X+N   (뒤 빌드번호 N은 항상 이전보다 +1)
```

### 2. APK 빌드 (릴리즈 + 에뮬레이터)

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
# 릴리즈 빌드 (실기기용)
flutter build apk --release
# 에뮬레이터 빌드 (x86_64)
flutter build apk --debug --target-platform android-arm64
```

### 3. Firebase App Distribution 업로드

```bash
# 릴리즈 APK
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --project babymeal-4f6f7 \
  --app "1:1045238419165:android:1d1bf34ccc50a275009534" \
  --release-notes "변경 내용 요약"

# 에뮬레이터 APK
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-debug.apk \
  --project babymeal-4f6f7 \
  --app "1:1045238419165:android:1d1bf34ccc50a275009534" \
  --release-notes "변경 내용 요약 (에뮬레이터용)"
```

### Firebase 정보 (변경 금지)

| 항목 | 값 |
|---|---|
| Project ID | `babymeal-4f6f7` |
| Android App ID | `1:1045238419165:android:1d1bf34ccc50a275009534` |
| 로그인 계정 | `daero52@gmail.com` |
| 패키지명 | `com.babymeal.babymeal_app` |

### 전체 자동 배포 명령 (한 번에)

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app && \
flutter build apk --release && \
flutter build apk --debug --target-platform android-arm64 && \
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --project babymeal-4f6f7 \
  --app "1:1045238419165:android:1d1bf34ccc50a275009534" \
  --release-notes "릴리즈 노트" && \
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-debug.apk \
  --project babymeal-4f6f7 \
  --app "1:1045238419165:android:1d1bf34ccc50a275009534" \
  --release-notes "릴리즈 노트 (에뮬레이터용)"
```
