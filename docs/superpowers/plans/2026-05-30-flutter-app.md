# Flutter 안드로이드 앱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 Flask 웹앱(치밀한 이유식)을 안드로이드 네이티브 앱으로 구현하고 FCM 푸시 알림을 지원한다.

**Architecture:** 기존 Flask에 JWT Bearer 인증 엔드포인트를 추가하고, Flutter 앱이 Dio + Riverpod으로 모든 기존 API를 호출한다. FCM은 Firebase Admin SDK를 통해 Flask가 직접 발송한다.

**Tech Stack:** Flask + PyJWT + firebase-admin (백엔드) / Flutter + Riverpod + Dio + firebase_messaging (앱)

**Spec:** `docs/superpowers/specs/2026-05-30-flutter-app-design.md`

---

## PART A — Flask 백엔드

### Task 1: PyJWT 의존성 + JWT 헬퍼 + DB 테이블

**Files:**
- Modify: `requirements.txt`
- Modify: `web/app.py` (create_app 상단 헬퍼 함수 추가)
- Test: `tests/test_api.py`

- [ ] **Step 1: requirements.txt에 PyJWT 추가**

```
flask>=2.3
pymysql>=1.1
werkzeug>=2.3
apscheduler>=3.10
minio>=7.2
pywebpush>=2.0
PyJWT>=2.8.0
firebase-admin>=6.5.0
```

- [ ] **Step 2: `web/app.py`의 `create_app` 안, `_get_db` 정의 직전에 JWT 헬퍼 추가**

`web/app.py`의 57번째 줄 `def _get_db():` 바로 위에 다음을 삽입:

```python
    def _ensure_auth_tables(conn):
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS refresh_tokens (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                user_id    INT NOT NULL,
                jti        VARCHAR(64) NOT NULL UNIQUE,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                expires_at DATETIME NOT NULL,
                revoked    TINYINT(1) DEFAULT 0,
                INDEX idx_user (user_id)
            ) DEFAULT CHARSET=utf8mb4
        """)
        conn.commit()

    def _make_tokens(user_id, username, is_admin):
        import jwt as _jwt
        now = datetime.utcnow()
        jti = secrets.token_hex(32)
        access = _jwt.encode(
            {'user_id': user_id, 'username': username, 'is_admin': is_admin,
             'exp': now + timedelta(hours=1)},
            app.config['SECRET_KEY'], algorithm='HS256'
        )
        refresh = _jwt.encode(
            {'user_id': user_id, 'jti': jti,
             'exp': now + timedelta(days=30)},
            app.config['SECRET_KEY'], algorithm='HS256'
        )
        return access, refresh, jti

    def _decode_access_token(token):
        import jwt as _jwt
        return _jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])

    def _jwt_user_from_request():
        auth = request.headers.get('Authorization', '')
        if not auth.startswith('Bearer '):
            return None
        try:
            return _decode_access_token(auth[7:])
        except Exception:
            return None

```

- [ ] **Step 3: 실패 테스트 작성 (`tests/test_api.py` 맨 아래에 추가)**

```python
def test_jwt_helper_make_and_decode(app):
    with app.app_context():
        from web.app import create_app
        # Access token이 만들어지고 decode되는지 확인
        import jwt as _jwt
        secret = 'test'
        import secrets as _s
        from datetime import datetime, timedelta
        jti = _s.token_hex(32)
        access = _jwt.encode(
            {'user_id': 1, 'username': 'admin', 'is_admin': True,
             'exp': datetime.utcnow() + timedelta(hours=1)},
            secret, algorithm='HS256'
        )
        payload = _jwt.decode(access, secret, algorithms=['HS256'])
        assert payload['user_id'] == 1
        assert payload['username'] == 'admin'
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
cd /Users/idaelo/project/babyMeal
python -m pytest tests/test_api.py::test_jwt_helper_make_and_decode -v
```

Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add requirements.txt web/app.py tests/test_api.py
git commit -m "feat: PyJWT 의존성 + JWT 헬퍼 함수 추가"
```

---

### Task 2: `/api/auth/*` 엔드포인트

**Files:**
- Modify: `web/app.py` (login_page 라우트 직전에 추가)
- Test: `tests/test_api.py`

- [ ] **Step 1: 실패 테스트 작성 (`tests/test_api.py`)**

```python
def test_api_auth_login_success(app):
    cur = make_cursor([{
        'id': 1, 'password_hash': generate_password_hash('pw'),
        'is_admin': True, 'is_active': True
    }])
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        client = app.test_client()
        resp = client.post('/api/auth/login',
                           json={'username': 'admin', 'password': 'pw'})
        assert resp.status_code == 200
        data = resp.get_json()
        assert 'access_token' in data
        assert 'refresh_token' in data

def test_api_auth_login_wrong_password(app):
    from werkzeug.security import generate_password_hash
    cur = make_cursor([{
        'id': 1, 'password_hash': generate_password_hash('correct'),
        'is_admin': False, 'is_active': True
    }])
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        client = app.test_client()
        resp = client.post('/api/auth/login',
                           json={'username': 'u', 'password': 'wrong'})
        assert resp.status_code == 401
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
python -m pytest tests/test_api.py::test_api_auth_login_success -v
```

Expected: FAIL (no route /api/auth/login)

- [ ] **Step 3: `web/app.py`에 auth 엔드포인트 추가 — `@app.route('/login'...)` 바로 위**

```python
    # ─── JWT 인증 API ─────────────────────────────────────────

    @app.post('/api/auth/login')
    def api_auth_login():
        d = request.get_json() or {}
        username = d.get('username', '').strip()
        password = d.get('password', '').strip()
        if not username or not password:
            return jsonify({'error': '아이디와 비밀번호를 입력하세요'}), 400
        ip = _client_ip()
        if _is_blocked(ip):
            return jsonify({'error': f'로그인 시도 초과. {_BLOCK_MINUTES}분 후 재시도하세요'}), 429
        conn = _mod.get_db()
        cur = conn.cursor()
        cur.execute(
            'SELECT id, password_hash, is_admin, is_active FROM users WHERE username=%s',
            (username,)
        )
        user = cur.fetchone()
        if not user or not user['is_active'] or not check_password_hash(user['password_hash'], password):
            _record_failure(ip)
            return jsonify({'error': '아이디 또는 비밀번호가 올바르지 않습니다'}), 401
        _clear_attempts(ip)
        access, refresh, jti = _make_tokens(user['id'], username, bool(user['is_admin']))
        _ensure_auth_tables(conn)
        expires_at = datetime.utcnow() + timedelta(days=30)
        cur.execute(
            'INSERT INTO refresh_tokens (user_id, jti, expires_at) VALUES (%s, %s, %s)',
            (user['id'], jti, expires_at)
        )
        conn.commit()
        return jsonify({
            'access_token': access,
            'refresh_token': refresh,
            'username': username,
            'is_admin': bool(user['is_admin']),
        })

    @app.post('/api/auth/refresh')
    def api_auth_refresh():
        import jwt as _jwt
        d = request.get_json() or {}
        token = d.get('refresh_token', '')
        if not token:
            return jsonify({'error': 'refresh_token 필요'}), 400
        try:
            payload = _jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
        except _jwt.ExpiredSignatureError:
            return jsonify({'error': '리프레시 토큰 만료'}), 401
        except _jwt.InvalidTokenError:
            return jsonify({'error': '유효하지 않은 토큰'}), 401
        conn = _mod.get_db()
        _ensure_auth_tables(conn)
        cur = conn.cursor()
        cur.execute(
            'SELECT id, revoked FROM refresh_tokens WHERE jti=%s AND user_id=%s',
            (payload['jti'], payload['user_id'])
        )
        row = cur.fetchone()
        if not row or row['revoked']:
            return jsonify({'error': '무효화된 토큰'}), 401
        cur.execute(
            'SELECT id, username, is_admin FROM users WHERE id=%s AND is_active=1',
            (payload['user_id'],)
        )
        user = cur.fetchone()
        if not user:
            return jsonify({'error': '사용자 없음'}), 401
        access, new_refresh, new_jti = _make_tokens(user['id'], user['username'], bool(user['is_admin']))
        cur.execute('UPDATE refresh_tokens SET revoked=1 WHERE jti=%s', (payload['jti'],))
        expires_at = datetime.utcnow() + timedelta(days=30)
        cur.execute(
            'INSERT INTO refresh_tokens (user_id, jti, expires_at) VALUES (%s, %s, %s)',
            (user['id'], new_jti, expires_at)
        )
        conn.commit()
        return jsonify({'access_token': access, 'refresh_token': new_refresh})

    @app.post('/api/auth/logout')
    def api_auth_logout():
        import jwt as _jwt
        d = request.get_json() or {}
        token = d.get('refresh_token', '')
        if token:
            try:
                payload = _jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
                conn = _mod.get_db()
                _ensure_auth_tables(conn)
                cur = conn.cursor()
                cur.execute('UPDATE refresh_tokens SET revoked=1 WHERE jti=%s', (payload['jti'],))
                conn.commit()
            except Exception:
                pass
        return jsonify({'ok': True})
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
python -m pytest tests/test_api.py::test_api_auth_login_success tests/test_api.py::test_api_auth_login_wrong_password -v
```

Expected: PASS (2 tests)

- [ ] **Step 5: 커밋**

```bash
git add web/app.py tests/test_api.py
git commit -m "feat: JWT 인증 엔드포인트 /api/auth/* 추가"
```

---

### Task 3: `login_required` / `admin_required` JWT 지원

**Files:**
- Modify: `web/app.py` (login_required, admin_required, get_view_user_id 수정)
- Test: `tests/test_api.py`

- [ ] **Step 1: 실패 테스트 작성**

```python
def test_api_ingredients_with_bearer_token(app):
    import jwt as _jwt
    from datetime import datetime, timedelta
    token = _jwt.encode(
        {'user_id': 1, 'username': 'admin', 'is_admin': True,
         'exp': datetime.utcnow() + timedelta(hours=1)},
        'test', algorithm='HS256'
    )
    cur = make_cursor([])
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        client = app.test_client()
        resp = client.get('/api/ingredients',
                          headers={'Authorization': f'Bearer {token}'})
        assert resp.status_code == 200
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
python -m pytest tests/test_api.py::test_api_ingredients_with_bearer_token -v
```

Expected: FAIL (302 redirect, not 200)

- [ ] **Step 3: `web/app.py`의 `login_required` 함수 교체**

기존 `login_required` (151-157줄)를 아래로 교체:

```python
    def login_required(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if session.get('logged_in'):
                return f(*args, **kwargs)
            jwt_user = _jwt_user_from_request()
            if jwt_user:
                g.jwt_user = jwt_user
                return f(*args, **kwargs)
            if request.path.startswith('/api/'):
                return jsonify({'error': '인증 필요'}), 401
            return redirect(url_for('login_page'))
        return wrapper
```

- [ ] **Step 4: `admin_required` 함수 교체**

기존 `admin_required` (159-169줄)를 아래로 교체:

```python
    def admin_required(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if session.get('logged_in') and session.get('is_admin'):
                return f(*args, **kwargs)
            jwt_user = _jwt_user_from_request()
            if jwt_user and jwt_user.get('is_admin'):
                g.jwt_user = jwt_user
                return f(*args, **kwargs)
            if request.path.startswith('/api/'):
                return jsonify({'error': '관리자 권한 필요'}), 403
            return redirect(url_for('inventory_page'))
        return wrapper
```

- [ ] **Step 5: `get_view_user_id` 함수 수정**

기존 `get_view_user_id` (69-70줄)를 아래로 교체:

```python
    def get_view_user_id():
        if hasattr(g, 'jwt_user'):
            return g.jwt_user['user_id']
        return session.get('view_as_user_id') or session.get('user_id')
```

- [ ] **Step 6: `api_meals_status` 내 username 참조 수정**

`api_meals_status` 안의 `_username = session.get('username', '')` 줄을 아래로 교체:

```python
        _username = getattr(g, 'jwt_user', {}).get('username') or session.get('username', '')
```

- [ ] **Step 7: 전체 테스트 실행**

```bash
python -m pytest tests/ -v
```

Expected: 전체 PASS (기존 테스트 깨지지 않아야 함)

- [ ] **Step 8: 커밋**

```bash
git add web/app.py tests/test_api.py
git commit -m "feat: login_required/admin_required에 JWT Bearer 인증 지원 추가"
```

---

### Task 4: FCM 테이블 + 엔드포인트 + `_send_fcm_to_all`

**Files:**
- Modify: `web/app.py`
- Modify: `config.example.json`
- Modify: `.gitignore`
- Test: `tests/test_api.py`

- [ ] **Step 1: `.gitignore`에 Firebase 파일 추가**

`.gitignore` 맨 아래에 추가:

```
# Firebase
flutter/babymeal_app/android/app/google-services.json
firebase-service-account.json
```

- [ ] **Step 2: `config.example.json` 업데이트**

`config.example.json`에 `"firebase"` 키 추가:

```json
{
  "db": { ... },
  "secret_key": "CHANGE_ME_RANDOM_STRING",
  "port": 8990,
  "debug": false,
  "discord_webhook": "",
  "firebase": {
    "service_account_path": ""
  },
  "web": { "trusted_proxies": [] },
  "minio": { ... }
}
```

- [ ] **Step 3: `web/app.py`에 FCM 헬퍼 추가 — `_send_web_push_to_all` 함수 바로 위**

```python
    def _ensure_fcm_table(conn):
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS push_subscriptions_fcm (
                id         INT AUTO_INCREMENT PRIMARY KEY,
                user_id    INT NOT NULL,
                token      TEXT NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY uniq_token (token(255))
            ) DEFAULT CHARSET=utf8mb4
        """)
        conn.commit()

    def _send_fcm_to_all(title, body):
        try:
            import firebase_admin
            from firebase_admin import messaging, credentials
        except ImportError:
            logging.warning('firebase-admin 미설치 — FCM 푸시 불가')
            return
        cfg = _db.load_config()
        sa_path = cfg.get('firebase', {}).get('service_account_path', '').strip()
        if not sa_path:
            logging.warning('Firebase 서비스 계정 미설정 — FCM 푸시 불가')
            return
        if not firebase_admin._apps:
            try:
                cred = credentials.Certificate(sa_path)
                firebase_admin.initialize_app(cred)
            except Exception as e:
                logging.warning('Firebase 초기화 실패: %s', e)
                return
        conn = _db.get_connection()
        try:
            _ensure_fcm_table(conn)
            cur = conn.cursor()
            cur.execute('SELECT DISTINCT token FROM push_subscriptions_fcm')
            tokens = [r['token'] for r in cur.fetchall()]
        finally:
            conn.close()
        if not tokens:
            return
        msg = messaging.MulticastMessage(
            notification=messaging.Notification(title=title, body=body),
            tokens=tokens,
        )
        try:
            resp = messaging.send_each_for_multicast(msg)
            logging.info('FCM 전송: success=%d fail=%d', resp.success_count, resp.failure_count)
        except Exception as e:
            logging.warning('FCM 전송 실패: %s', e)
```

- [ ] **Step 4: FCM 토큰 엔드포인트 추가 — `_send_web_push_to_all` 바로 아래, `_send_realtime_alert` 바로 위**

```python
    @app.post('/api/push/fcm-token')
    @login_required
    def api_push_fcm_token_add():
        d = request.get_json() or {}
        token = d.get('token', '').strip()
        if not token:
            return jsonify({'error': 'token 필요'}), 400
        uid = get_view_user_id()
        conn = _mod.get_db()
        _ensure_fcm_table(conn)
        cur = conn.cursor()
        try:
            cur.execute(
                'INSERT INTO push_subscriptions_fcm (user_id, token) VALUES (%s, %s) '
                'ON DUPLICATE KEY UPDATE user_id=%s, created_at=NOW()',
                (uid, token, uid)
            )
            conn.commit()
        except Exception:
            conn.rollback()
        return jsonify({'ok': True})

    @app.delete('/api/push/fcm-token')
    @login_required
    def api_push_fcm_token_delete():
        d = request.get_json() or {}
        token = d.get('token', '').strip()
        if not token:
            return jsonify({'error': 'token 필요'}), 400
        conn = _mod.get_db()
        cur = conn.cursor()
        cur.execute('DELETE FROM push_subscriptions_fcm WHERE token=%s', (token,))
        conn.commit()
        return jsonify({'ok': True})
```

- [ ] **Step 5: `_send_realtime_alert` 마지막 줄 뒤에 FCM 호출 추가**

`_send_realtime_alert` 함수의 마지막 줄인 `_send_web_push_to_all(push_title, push_body, '/')` 바로 다음에:

```python
        _send_fcm_to_all(push_title, push_body)
```

- [ ] **Step 6: `_send_low_stock_notification` 마지막 줄 뒤에 FCM 호출 추가**

`_send_low_stock_notification` 함수의 마지막 줄인 `_send_web_push_to_all('🚨 재고 부족', ...)` 바로 다음에:

```python
        _send_fcm_to_all('🚨 재고 부족', f"{names} — 큐브를 보충해주세요")
```

- [ ] **Step 7: 테스트 작성 (FCM 토큰 엔드포인트)**

```python
def test_fcm_token_add_requires_auth(app):
    client = app.test_client()
    resp = client.post('/api/push/fcm-token', json={'token': 'abc'})
    assert resp.status_code == 401

def test_fcm_token_add_success(app, authed_client):
    cur = make_cursor([])
    conn = make_conn(cur)
    with patch('web.app.get_db', return_value=conn):
        resp = authed_client.post(
            '/api/push/fcm-token',
            json={'token': 'fake-fcm-token'},
            headers={'X-CSRF-Token': 'testtoken'},
        )
        assert resp.status_code == 200
        assert resp.get_json()['ok'] is True
```

- [ ] **Step 8: 전체 테스트 실행**

```bash
python -m pytest tests/ -v
```

Expected: 전체 PASS

- [ ] **Step 9: 커밋**

```bash
git add web/app.py config.example.json .gitignore tests/test_api.py
git commit -m "feat: FCM 토큰 관리 엔드포인트 + _send_fcm_to_all 알림 연동"
```

---

## PART B — Flutter 앱

### Task 5: Flutter 프로젝트 생성 + pubspec.yaml

**Files:**
- Create: `flutter/babymeal_app/` (Flutter project)
- Modify: `flutter/babymeal_app/pubspec.yaml`

- [ ] **Step 1: Flutter 프로젝트 생성**

```bash
cd /Users/idaelo/project/babyMeal
mkdir -p flutter
cd flutter
flutter create babymeal_app --org com.babymeal --platforms android
```

- [ ] **Step 2: `flutter/babymeal_app/pubspec.yaml` 의존성 교체**

`dependencies:` 섹션을 아래로 교체:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  dio: ^5.4.3
  flutter_secure_storage: ^9.2.2
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  flutter_local_notifications: ^17.2.2
  table_calendar: ^3.1.2
  fl_chart: ^0.69.0
  intl: ^0.19.0
```

- [ ] **Step 3: 패키지 설치**

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutter pub get
```

Expected: 오류 없이 완료

- [ ] **Step 4: 폴더 구조 생성**

```bash
cd lib
mkdir -p core/api core/auth core/push
mkdir -p features/login features/inventory features/schedule features/allergy features/stats features/settings features/splash
mkdir -p shared/widgets
```

- [ ] **Step 5: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "chore: Flutter 프로젝트 초기 생성 + 의존성 설정"
```

---

### Task 6: 코어 레이어 — AuthStorage + ApiClient + AuthNotifier

**Files:**
- Create: `flutter/babymeal_app/lib/core/auth/auth_storage.dart`
- Create: `flutter/babymeal_app/lib/core/api/api_client.dart`
- Create: `flutter/babymeal_app/lib/core/auth/auth_provider.dart`

- [ ] **Step 1: `auth_storage.dart` 작성**

```dart
// lib/core/auth/auth_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _s = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String username,
    required bool isAdmin,
  }) =>
      Future.wait([
        _s.write(key: 'access_token', value: accessToken),
        _s.write(key: 'refresh_token', value: refreshToken),
        _s.write(key: 'username', value: username),
        _s.write(key: 'is_admin', value: isAdmin.toString()),
      ]);

  static Future<void> saveServerUrl(String url) =>
      _s.write(key: 'server_url', value: url);

  static Future<String?> get accessToken => _s.read(key: 'access_token');
  static Future<String?> get refreshToken => _s.read(key: 'refresh_token');
  static Future<String?> get serverUrl => _s.read(key: 'server_url');
  static Future<String?> get username => _s.read(key: 'username');
  static Future<bool> get isAdmin async =>
      (await _s.read(key: 'is_admin')) == 'true';

  static Future<void> clear() => _s.deleteAll();
}
```

- [ ] **Step 2: `api_client.dart` 작성**

```dart
// lib/core/api/api_client.dart
import 'package:dio/dio.dart';
import '../auth/auth_storage.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  late final Dio dio;
  bool _refreshing = false;

  ApiClient._() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler h) async {
    final url = await AuthStorage.serverUrl ?? '';
    final token = await AuthStorage.accessToken;
    options.baseUrl = url;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    h.next(options);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    if (e.response?.statusCode == 401 && !_refreshing) {
      _refreshing = true;
      final ok = await _tryRefresh();
      _refreshing = false;
      if (ok) {
        final opts = e.requestOptions;
        opts.headers['Authorization'] = 'Bearer ${await AuthStorage.accessToken}';
        try {
          h.resolve(await dio.fetch(opts));
          return;
        } catch (_) {}
      }
    }
    h.next(e);
  }

  Future<bool> _tryRefresh() async {
    final serverUrl = await AuthStorage.serverUrl ?? '';
    final rt = await AuthStorage.refreshToken;
    if (rt == null || serverUrl.isEmpty) return false;
    try {
      final resp = await Dio()
          .post('$serverUrl/api/auth/refresh', data: {'refresh_token': rt});
      await AuthStorage.saveTokens(
        accessToken: resp.data['access_token'],
        refreshToken: resp.data['refresh_token'] ?? rt,
        username: await AuthStorage.username ?? '',
        isAdmin: await AuthStorage.isAdmin,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 3: `auth_provider.dart` 작성**

```dart
// lib/core/auth/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_storage.dart';
import '../api/api_client.dart';
import '../push/fcm_service.dart';

class AuthState {
  final bool isLoggedIn;
  final String username;
  final bool isAdmin;
  const AuthState({
    this.isLoggedIn = false,
    this.username = '',
    this.isAdmin = false,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> checkAuth() async {
    final token = await AuthStorage.accessToken;
    if (token == null) { state = const AuthState(); return; }
    state = AuthState(
      isLoggedIn: true,
      username: await AuthStorage.username ?? '',
      isAdmin: await AuthStorage.isAdmin,
    );
  }

  Future<void> login(String serverUrl, String username, String password) async {
    final cleanUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    await AuthStorage.saveServerUrl(cleanUrl);
    final resp = await ApiClient.instance.dio.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );
    await AuthStorage.saveTokens(
      accessToken: resp.data['access_token'],
      refreshToken: resp.data['refresh_token'],
      username: resp.data['username'],
      isAdmin: resp.data['is_admin'] ?? false,
    );
    await FcmService.registerToken();
    state = AuthState(
      isLoggedIn: true,
      username: resp.data['username'],
      isAdmin: resp.data['is_admin'] ?? false,
    );
  }

  Future<void> logout() async {
    final rt = await AuthStorage.refreshToken;
    if (rt != null) {
      try {
        await ApiClient.instance.dio
            .post('/api/auth/logout', data: {'refresh_token': rt});
      } catch (_) {}
    }
    await FcmService.unregisterToken();
    await AuthStorage.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
```

- [ ] **Step 4: `fcm_service.dart` 스텁 작성 (Task 14에서 완성)**

```dart
// lib/core/push/fcm_service.dart
class FcmService {
  static Future<void> init() async {}
  static Future<void> registerToken() async {}
  static Future<void> unregisterToken() async {}
}
```

- [ ] **Step 5: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "feat: Flutter 코어 레이어 — AuthStorage, ApiClient, AuthNotifier"
```

---

### Task 7: SplashScreen + LoginScreen

**Files:**
- Modify: `flutter/babymeal_app/lib/main.dart`
- Create: `flutter/babymeal_app/lib/features/splash/splash_screen.dart`
- Create: `flutter/babymeal_app/lib/features/login/login_screen.dart`

- [ ] **Step 1: `main.dart` 작성**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BabyMealApp()));
}

class BabyMealApp extends StatelessWidget {
  const BabyMealApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '치밀한 이유식',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF4BA3E3),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      );
}
```

- [ ] **Step 2: `splash_screen.dart` 작성**

```dart
// lib/features/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../login/login_screen.dart';
import '../shell/main_shell.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await ref.read(authProvider.notifier).checkAuth();
    if (!mounted) return;
    final auth = ref.read(authProvider);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => auth.isLoggedIn ? const MainShell() : const LoginScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}
```

- [ ] **Step 3: `login_screen.dart` 작성**

```dart
// lib/features/login/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_storage.dart';
import '../shell/main_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthStorage.serverUrl.then((v) {
      if (v != null && mounted) _serverCtrl.text = v;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        _serverCtrl.text.trim(),
        _userCtrl.text.trim(),
        _passCtrl.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } catch (e) {
      setState(() { _error = '로그인 실패: $e'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text('🍼 치밀한 이유식',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _serverCtrl,
                    decoration: const InputDecoration(
                      labelText: '서버 URL',
                      hintText: 'https://babymeal.example.com',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'URL을 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: '아이디',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '아이디를 입력하세요' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('로그인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _serverCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: MainShell 스텁 생성 (Task 8에서 완성)**

```bash
mkdir -p /Users/idaelo/project/babyMeal/flutter/babymeal_app/lib/features/shell
```

```dart
// lib/features/shell/main_shell.dart
import 'package:flutter/material.dart';
class MainShell extends StatelessWidget {
  const MainShell({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('메인 (준비 중)')));
}
```

- [ ] **Step 5: 빌드 확인**

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 6: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "feat: SplashScreen + LoginScreen 구현"
```

---

### Task 8: MainShell + InventoryScreen

**Files:**
- Create: `flutter/babymeal_app/lib/features/shell/main_shell.dart`
- Create: `flutter/babymeal_app/lib/features/inventory/inventory_screen.dart`
- Create: `flutter/babymeal_app/lib/features/inventory/ingredient_provider.dart`
- Create: `flutter/babymeal_app/lib/features/inventory/ingredient_model.dart`
- Create: `flutter/babymeal_app/lib/features/inventory/ingredient_dialog.dart`

- [ ] **Step 1: `ingredient_model.dart` 작성**

```dart
// lib/features/inventory/ingredient_model.dart
class Ingredient {
  final int id;
  final String name;
  final String emoji;
  final String color;
  final String createdAt;
  final int totalCubes;
  final int currentCubes;
  final int? weightPerCube;
  final String unitType;
  final String? imageUrl;

  const Ingredient({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.createdAt,
    required this.totalCubes,
    required this.currentCubes,
    this.weightPerCube,
    required this.unitType,
    this.imageUrl,
  });

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'],
        name: j['name'],
        emoji: j['emoji'] ?? '',
        color: j['color'] ?? '#4BA3E3',
        createdAt: j['created_at'] ?? '',
        totalCubes: j['total_cubes'] ?? 0,
        currentCubes: j['current_cubes'] ?? 0,
        weightPerCube: j['weight_per_cube'],
        unitType: j['unit_type'] ?? 'weight',
        imageUrl: j['image_url'],
      );

  // 글로벌 임계값은 notification_settings에서 관리. 여기서는 기본값 3 사용.
  bool get isLowStock => currentCubes <= 3;

  bool get isExpired {
    if (createdAt.isEmpty) return false;
    try {
      final made = DateTime.parse(createdAt);
      return DateTime.now().difference(made).inDays > 90;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 2: `ingredient_provider.dart` 작성**

```dart
// lib/features/inventory/ingredient_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'ingredient_model.dart';

final ingredientsProvider = FutureProvider<List<Ingredient>>((ref) async {
  final resp = await ApiClient.instance.dio.get('/api/ingredients');
  return (resp.data as List)
      .map((j) => Ingredient.fromJson(j as Map<String, dynamic>))
      .toList();
});

class IngredientActions {
  static Future<void> adjust(int id, int delta) async {
    await ApiClient.instance.dio.post(
      '/api/ingredients/$id/adjust',
      data: {'delta': delta},
    );
  }

  static Future<void> add(Map<String, dynamic> data) async {
    await ApiClient.instance.dio.post('/api/ingredients', data: data);
  }

  static Future<void> update(int id, Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put('/api/ingredients/$id', data: data);
  }

  static Future<void> delete(int id) async {
    await ApiClient.instance.dio.delete('/api/ingredients/$id');
  }

  static Future<List<Map<String, dynamic>>> logs(int id) async {
    final resp =
        await ApiClient.instance.dio.get('/api/ingredients/$id/logs');
    return List<Map<String, dynamic>>.from(resp.data as List);
  }
}
```

- [ ] **Step 3: `ingredient_dialog.dart` 작성**

```dart
// lib/features/inventory/ingredient_dialog.dart
import 'package:flutter/material.dart';
import 'ingredient_model.dart';

class IngredientDialog extends StatefulWidget {
  final Ingredient? existing;
  const IngredientDialog({super.key, this.existing});

  @override
  State<IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<IngredientDialog> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  String _unitType = 'weight';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _emojiCtrl.text = e.emoji;
      _totalCtrl.text = e.totalCubes.toString();
      _weightCtrl.text = e.weightPerCube?.toString() ?? '';
      _dateCtrl.text = e.createdAt;
      _unitType = e.unitType;
    } else {
      _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
    }
  }

  Map<String, dynamic> toData() => {
        'name': _nameCtrl.text.trim(),
        'emoji': _emojiCtrl.text.trim(),
        'color': '#4BA3E3',
        'created_at': _dateCtrl.text.trim(),
        'total_cubes': int.tryParse(_totalCtrl.text) ?? 0,
        'weight_per_cube': _unitType == 'weight'
            ? int.tryParse(_weightCtrl.text)
            : null,
        'unit_type': _unitType,
      };

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? '재료 추가' : '재료 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_emojiCtrl, '이모지', hint: '🥕'),
              _field(_nameCtrl, '이름'),
              _field(_dateCtrl, '제작일 (YYYY-MM-DD)'),
              _field(_totalCtrl, '총 큐브 수', keyboard: TextInputType.number),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'weight', label: Text('무게')),
                  ButtonSegment(value: 'quantity', label: Text('개수')),
                ],
                selected: {_unitType},
                onSelectionChanged: (s) =>
                    setState(() => _unitType = s.first),
              ),
              if (_unitType == 'weight')
                _field(_weightCtrl, '큐브당 무게 (g)', keyboard: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, toData()),
              child: const Text('저장')),
        ],
      );

  Widget _field(TextEditingController c, String label,
      {String? hint, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emojiCtrl, _totalCtrl, _weightCtrl, _dateCtrl]) {
      c.dispose();
    }
    super.dispose();
  }
}
```

- [ ] **Step 4: `inventory_screen.dart` 작성**

```dart
// lib/features/inventory/inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ingredient_provider.dart';
import 'ingredient_model.dart';
import 'ingredient_dialog.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ingredientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('재고현황')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addIngredient(context, ref),
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('등록된 재료가 없어요'))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) =>
                    _IngredientTile(item: items[i], onRefresh: () {
                      ref.invalidate(ingredientsProvider);
                    }),
              ),
      ),
    );
  }

  Future<void> _addIngredient(BuildContext context, WidgetRef ref) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const IngredientDialog(),
    );
    if (data == null) return;
    try {
      await IngredientActions.add(data);
      ref.invalidate(ingredientsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
      }
    }
  }
}

class _IngredientTile extends StatelessWidget {
  final Ingredient item;
  final VoidCallback onRefresh;
  const _IngredientTile({required this.item, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final expired = item.isExpired;
    final low = item.isLowStock;
    return ListTile(
      leading: Text(item.emoji, style: const TextStyle(fontSize: 28)),
      title: Text(item.name,
          style: TextStyle(color: expired ? Colors.red : null)),
      subtitle: Text('${item.currentCubes}개 남음'
          '${expired ? ' · 유통기한 초과' : ''}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (low)
            const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 18),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => _adjust(context, -1),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _adjust(context, 1),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('수정')),
              PopupMenuItem(value: 'logs', child: Text('로그')),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _adjust(BuildContext context, int delta) async {
    try {
      await IngredientActions.adjust(item.id, delta);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('조정 실패: $e')));
      }
    }
  }

  Future<void> _onMenu(BuildContext context, String action) async {
    if (action == 'edit') {
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => IngredientDialog(existing: item),
      );
      if (data == null) return;
      try {
        await IngredientActions.update(item.id, data);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('수정 실패: $e')));
        }
      }
    } else if (action == 'logs') {
      _showLogs(context);
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('재료 삭제'),
          content: Text('${item.name}을 삭제하시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await IngredientActions.delete(item.id);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      }
    }
  }

  Future<void> _showLogs(BuildContext context) async {
    final logs = await IngredientActions.logs(item.id);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${item.emoji} ${item.name} 로그',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final l = logs[i];
                return ListTile(
                  title: Text('${l['event_type']} ${l['delta'] > 0 ? '+' : ''}${l['delta']}'),
                  subtitle: Text(l['logged_at']?.toString().substring(0, 16) ?? ''),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: `main_shell.dart` 완성**

```dart
// lib/features/shell/main_shell.dart
import 'package:flutter/material.dart';
import '../inventory/inventory_screen.dart';
import '../schedule/schedule_screen.dart';
import '../allergy/allergy_screen.dart';
import '../stats/stats_screen.dart';
import '../settings/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _idx = 0;

  static const _tabs = [
    InventoryScreen(),
    ScheduleScreen(),
    AllergyScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _idx, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) => setState(() => _idx = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.kitchen), label: '재고'),
            NavigationDestination(icon: Icon(Icons.calendar_month), label: '식단'),
            NavigationDestination(icon: Icon(Icons.science), label: '알러지'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: '통계'),
            NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
          ],
        ),
      );
}
```

- [ ] **Step 6: 나머지 화면 스텁 생성**

각 파일에 아래 패턴으로 스텁 작성 (`schedule_screen.dart`, `allergy_screen.dart`, `stats_screen.dart`, `settings_screen.dart`):

```dart
// lib/features/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('식단표 (준비 중)')));
}
```

동일 패턴으로 나머지 3개 스텁도 생성.

- [ ] **Step 7: 빌드 확인**

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 8: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "feat: MainShell + InventoryScreen 구현"
```

---

### Task 9: ScheduleScreen

**Files:**
- Create: `flutter/babymeal_app/lib/features/schedule/schedule_screen.dart`
- Create: `flutter/babymeal_app/lib/features/schedule/meal_model.dart`
- Create: `flutter/babymeal_app/lib/features/schedule/meal_provider.dart`
- Create: `flutter/babymeal_app/lib/features/schedule/meal_dialog.dart`

- [ ] **Step 1: `meal_model.dart` 작성**

```dart
// lib/features/schedule/meal_model.dart

class MealIngredient {
  final int ingredientId;
  final int grams;
  final String name;
  final String emoji;
  const MealIngredient({
    required this.ingredientId,
    required this.grams,
    required this.name,
    required this.emoji,
  });
  factory MealIngredient.fromJson(Map<String, dynamic> j) => MealIngredient(
        ingredientId: j['ingredient_id'],
        grams: j['grams'] ?? 0,
        name: j['name'] ?? '',
        emoji: j['emoji'] ?? '',
      );
}

class Meal {
  final int id;
  final String date;
  final String mealTime;
  final String status;
  final String note;
  final List<MealIngredient> ingredients;

  const Meal({
    required this.id,
    required this.date,
    required this.mealTime,
    required this.status,
    required this.note,
    required this.ingredients,
  });

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: j['id'],
        date: j['date'] ?? '',
        mealTime: j['meal_time'] ?? '',
        status: j['status'] ?? 'upcoming',
        note: j['note'] ?? '',
        ingredients: (j['ingredients'] as List? ?? [])
            .map((i) => MealIngredient.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  static const mealTimeKo = {
    'morning': '아침',
    'morning_snack': '오전간식',
    'lunch': '점심',
    'snack': '오후간식',
    'dinner': '저녁',
    'tried': '알러지 테스트',
  };

  static const statusColor = {
    'confirmed': 0xFF1565C0,
    'upcoming': 0xFFF9A825,
    'skipped': 0xFFC62828,
    'auto-consumed': 0xFF1565C0,
  };

  String get mealTimeKoStr => mealTimeKo[mealTime] ?? mealTime;
  int get statusColorInt => statusColor[status] ?? 0xFF9E9E9E;
}
```

- [ ] **Step 2: `meal_provider.dart` 작성**

```dart
// lib/features/schedule/meal_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'meal_model.dart';

final mealsProvider = FutureProvider<List<Meal>>((ref) async {
  final resp = await ApiClient.instance.dio.get('/api/meals');
  return (resp.data as List)
      .map((j) => Meal.fromJson(j as Map<String, dynamic>))
      .toList();
});

class MealActions {
  static Future<Meal> add(Map<String, dynamic> data) async {
    final resp = await ApiClient.instance.dio.post('/api/meals', data: data);
    return Meal.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<Meal> updateStatus(int id, String status,
      {List<int>? consumedIds}) async {
    final resp = await ApiClient.instance.dio.post(
      '/api/meals/$id/status',
      data: {
        'status': status,
        if (consumedIds != null) 'consumed_ids': consumedIds,
      },
    );
    return Meal.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<void> delete(int id) async {
    await ApiClient.instance.dio.delete('/api/meals/$id');
  }
}
```

- [ ] **Step 3: `meal_dialog.dart` 작성**

```dart
// lib/features/schedule/meal_dialog.dart
import 'package:flutter/material.dart';
import '../inventory/ingredient_provider.dart';
import '../inventory/ingredient_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MealDialog extends ConsumerStatefulWidget {
  final String initialDate;
  const MealDialog({super.key, required this.initialDate});
  @override
  ConsumerState<MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends ConsumerState<MealDialog> {
  String _mealTime = 'morning';
  final _noteCtrl = TextEditingController();
  final Map<int, int> _selected = {}; // ingredientId → grams

  static const _times = [
    ('morning', '아침'), ('morning_snack', '오전간식'),
    ('lunch', '점심'), ('snack', '오후간식'),
    ('dinner', '저녁'),
  ];

  Map<String, dynamic> toData(List<Ingredient> allIngredients) => {
        'date': widget.initialDate,
        'meal_time': _mealTime,
        'note': _noteCtrl.text.trim(),
        'ingredients': _selected.entries
            .map((e) => {'ingredient_id': e.key, 'grams': e.value})
            .toList(),
      };

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    return AlertDialog(
      title: Text('식단 추가 (${widget.initialDate})'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _mealTime,
              items: _times
                  .map((t) =>
                      DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _mealTime = v!),
              decoration: const InputDecoration(
                  labelText: '끼니', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ingredientsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('재료 로드 실패: $e'),
              data: (items) => Wrap(
                spacing: 8,
                children: items
                    .map((ing) => FilterChip(
                          label: Text('${ing.emoji}${ing.name}'),
                          selected: _selected.containsKey(ing.id),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selected[ing.id] = 1;
                            } else {
                              _selected.remove(ing.id);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                  labelText: '메모', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            final data = toData([]); // ingredients resolved via _selected
            Navigator.pop(context, data);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }
}
```

- [ ] **Step 4: `schedule_screen.dart` 작성**

```dart
// lib/features/schedule/schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'meal_provider.dart';
import 'meal_model.dart';
import 'meal_dialog.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  String get _selectedStr =>
      _selected.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final mealsAsync = ref.watch(mealsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('식단표')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addMeal(context),
        child: const Icon(Icons.add),
      ),
      body: mealsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (meals) {
          final byDate = <String, List<Meal>>{};
          for (final m in meals) {
            byDate.putIfAbsent(m.date, () => []).add(m);
          }
          final dayMeals = byDate[_selectedStr] ?? [];
          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focused,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                onDaySelected: (sel, foc) =>
                    setState(() { _selected = sel; _focused = foc; }),
                eventLoader: (d) =>
                    byDate[d.toIso8601String().substring(0, 10)] ?? [],
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(formatButtonVisible: false),
              ),
              const Divider(),
              Expanded(
                child: dayMeals.isEmpty
                    ? const Center(child: Text('등록된 식단이 없어요'))
                    : ListView.builder(
                        itemCount: dayMeals.length,
                        itemBuilder: (_, i) => _MealTile(
                          meal: dayMeals[i],
                          onRefresh: () => ref.invalidate(mealsProvider),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addMeal(BuildContext context) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => MealDialog(initialDate: _selectedStr),
    );
    if (data == null) return;
    try {
      await MealActions.add(data);
      ref.invalidate(mealsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
      }
    }
  }
}

class _MealTile extends StatelessWidget {
  final Meal meal;
  final VoidCallback onRefresh;
  const _MealTile({required this.meal, required this.onRefresh});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(meal.statusColorInt),
          child: Text(meal.ingredients.isNotEmpty
              ? meal.ingredients.first.emoji
              : '🍽'),
        ),
        title: Text(meal.mealTimeKoStr),
        subtitle: Text(meal.ingredients.map((i) => i.name).join(', ')),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _onMenu(context, v),
          itemBuilder: (_) => [
            if (meal.status != 'confirmed')
              const PopupMenuItem(value: 'confirmed', child: Text('먹었어요')),
            if (meal.status != 'upcoming')
              const PopupMenuItem(value: 'upcoming', child: Text('안먹었어요')),
            if (meal.status != 'skipped')
              const PopupMenuItem(value: 'skipped', child: Text('건너뜀')),
            const PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
      );

  Future<void> _onMenu(BuildContext context, String action) async {
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: const Text('식단을 삭제하시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await MealActions.delete(meal.id);
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      }
    } else {
      try {
        await MealActions.updateStatus(
          meal.id, action,
          consumedIds: action == 'confirmed'
              ? meal.ingredients.map((i) => i.ingredientId).toList()
              : null,
        );
        onRefresh();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('상태 변경 실패: $e')));
        }
      }
    }
  }
}
```

- [ ] **Step 5: 빌드 확인**

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutter build apk --debug 2>&1 | tail -5
```

- [ ] **Step 6: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "feat: ScheduleScreen 구현 (월간 캘린더 + 식단 CRUD)"
```

---

### Task 10: AllergyScreen

**Files:**
- Create: `flutter/babymeal_app/lib/features/allergy/allergy_screen.dart`
- Create: `flutter/babymeal_app/lib/features/allergy/allergy_model.dart`
- Create: `flutter/babymeal_app/lib/features/allergy/allergy_provider.dart`

- [ ] **Step 1: `allergy_model.dart`**

```dart
// lib/features/allergy/allergy_model.dart
class AllergyTest {
  final int id;
  final String testDate;
  final String emoji;
  final String ingredientName;
  final String memo;

  const AllergyTest({
    required this.id,
    required this.testDate,
    required this.emoji,
    required this.ingredientName,
    required this.memo,
  });

  factory AllergyTest.fromJson(Map<String, dynamic> j) => AllergyTest(
        id: j['id'],
        testDate: j['test_date'] ?? '',
        emoji: j['emoji'] ?? '🧪',
        ingredientName: j['ingredient_name'] ?? '',
        memo: j['memo'] ?? '',
      );
}
```

- [ ] **Step 2: `allergy_provider.dart`**

```dart
// lib/features/allergy/allergy_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'allergy_model.dart';

final allergyProvider = FutureProvider<List<AllergyTest>>((ref) async {
  final resp = await ApiClient.instance.dio.get('/api/allergy');
  return (resp.data as List)
      .map((j) => AllergyTest.fromJson(j as Map<String, dynamic>))
      .toList();
});

class AllergyActions {
  static Future<void> add(Map<String, dynamic> data) async {
    await ApiClient.instance.dio.post('/api/allergy', data: data);
  }

  static Future<void> update(int id, Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put('/api/allergy/$id', data: data);
  }

  static Future<void> delete(int id) async {
    await ApiClient.instance.dio.delete('/api/allergy/$id');
  }
}
```

- [ ] **Step 3: `allergy_screen.dart`**

```dart
// lib/features/allergy/allergy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'allergy_provider.dart';
import 'allergy_model.dart';

class AllergyScreen extends ConsumerStatefulWidget {
  const AllergyScreen({super.key});
  @override
  ConsumerState<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends ConsumerState<AllergyScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  String get _selectedStr => _selected.toIso8601String().substring(0, 10);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allergyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('알러지 테스트')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add(context),
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (tests) {
          final byDate = <String, List<AllergyTest>>{};
          for (final t in tests) {
            byDate.putIfAbsent(t.testDate, () => []).add(t);
          }
          final dayTests = byDate[_selectedStr] ?? [];
          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focused,
                selectedDayPredicate: (d) => isSameDay(d, _selected),
                onDaySelected: (sel, foc) =>
                    setState(() { _selected = sel; _focused = foc; }),
                eventLoader: (d) =>
                    byDate[d.toIso8601String().substring(0, 10)] ?? [],
                calendarFormat: CalendarFormat.month,
                headerStyle: const HeaderStyle(formatButtonVisible: false),
              ),
              const Divider(),
              Expanded(
                child: dayTests.isEmpty
                    ? const Center(child: Text('이날 테스트가 없어요'))
                    : ListView.builder(
                        itemCount: dayTests.length,
                        itemBuilder: (_, i) => _AllergyTile(
                          test: dayTests[i],
                          onRefresh: () => ref.invalidate(allergyProvider),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final data = await _showDialog(context, null);
    if (data == null) return;
    try {
      await AllergyActions.add(data);
      ref.invalidate(allergyProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
      }
    }
  }

  Future<Map<String, dynamic>?> _showDialog(
      BuildContext context, AllergyTest? existing) {
    final emojiCtrl =
        TextEditingController(text: existing?.emoji ?? '🧪');
    final nameCtrl =
        TextEditingController(text: existing?.ingredientName ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? '테스트 추가' : '테스트 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emojiCtrl,
                decoration: const InputDecoration(labelText: '이모지', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl,
                decoration: const InputDecoration(labelText: '재료명', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: memoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '반응 메모', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'test_date': _selectedStr,
              'emoji': emojiCtrl.text.trim(),
              'ingredient_name': nameCtrl.text.trim(),
              'memo': memoCtrl.text.trim(),
            }),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _AllergyTile extends StatelessWidget {
  final AllergyTest test;
  final VoidCallback onRefresh;
  const _AllergyTile({required this.test, required this.onRefresh});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Text(test.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(test.ingredientName),
        subtitle: test.memo.isNotEmpty ? Text(test.memo) : null,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') {
              try {
                await AllergyActions.delete(test.id);
                onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
                }
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
      );
}
```

- [ ] **Step 4: 빌드 확인**

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutter build apk --debug 2>&1 | tail -5
```

- [ ] **Step 5: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "feat: AllergyScreen 구현"
```

---

### Task 11: StatsScreen + SettingsScreen

**Files:**
- Create: `flutter/babymeal_app/lib/features/stats/stats_screen.dart`
- Create: `flutter/babymeal_app/lib/features/settings/settings_screen.dart`
- Create: `flutter/babymeal_app/lib/features/settings/settings_provider.dart`

- [ ] **Step 1: `stats_screen.dart` 작성**

```dart
// lib/features/stats/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../inventory/ingredient_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingredientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('재료가 없어요'));
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: (items.length * 60.0).clamp(300, 1200),
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: items
                      .map((i) => i.totalCubes.toDouble())
                      .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barGroups: items.asMap().entries.map((e) {
                    final ing = e.value;
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: ing.currentCubes.toDouble(),
                          color: ing.isLowStock
                              ? Colors.orange
                              : const Color(0xFF4BA3E3),
                          width: 28,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= items.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(items[i].emoji,
                                style: const TextStyle(fontSize: 16)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: `settings_provider.dart` 작성**

```dart
// lib/features/settings/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

final notificationSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final resp =
      await ApiClient.instance.dio.get('/api/notification-settings');
  return Map<String, dynamic>.from(resp.data as Map);
});

class SettingsActions {
  static Future<void> saveNotificationSettings(
      Map<String, dynamic> data) async {
    await ApiClient.instance.dio.put('/api/notification-settings', data: data);
  }

  static Future<void> testNotification() async {
    await ApiClient.instance.dio
        .post('/api/notification-settings/test');
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final resp = await ApiClient.instance.dio.get('/api/users');
    return List<Map<String, dynamic>>.from(resp.data as List);
  }

  static Future<void> addUser(String username, String password) async {
    await ApiClient.instance.dio.post('/api/users',
        data: {'username': username, 'password': password});
  }

  static Future<void> deleteUser(int id) async {
    await ApiClient.instance.dio.delete('/api/users/$id');
  }

  static Future<void> toggleUser(int id) async {
    await ApiClient.instance.dio.post('/api/users/$id/toggle-active');
  }
}
```

- [ ] **Step 3: `settings_screen.dart` 작성**

```dart
// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_storage.dart';
import '../login/login_screen.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(auth.username),
            subtitle: auth.isAdmin ? const Text('관리자') : null,
          ),
          const Divider(),
          if (auth.isAdmin) ...[
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('알림 설정'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openNotificationSettings(context),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('사용자 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openUserManagement(context),
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('서버 URL 변경'),
            onTap: () => _changeServerUrl(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _changeServerUrl(BuildContext context) async {
    final current = await AuthStorage.serverUrl ?? '';
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('서버 URL 변경'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'URL', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('저장')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await AuthStorage.saveServerUrl(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('서버 URL 저장됨')));
      }
    }
  }

  Future<void> _openNotificationSettings(BuildContext context) async {
    final settingsAsync =
        await ref.read(notificationSettingsProvider.future).catchError((_) => <String, dynamic>{});
    if (!context.mounted) return;
    final webhookCtrl = TextEditingController(
        text: settingsAsync['discord_webhook'] ?? '');
    final thresholdCtrl = TextEditingController(
        text: (settingsAsync['notify_threshold'] ?? 3).toString());
    bool enabled = settingsAsync['enabled'] ?? false;
    int hour = settingsAsync['notify_hour'] ?? 8;
    int minute = settingsAsync['notify_minute'] ?? 0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('알림 설정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('매일 알림 사용'),
                  value: enabled,
                  onChanged: (v) => setSt(() => enabled = v),
                ),
                if (enabled)
                  Row(children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: hour,
                        items: List.generate(24, (i) => DropdownMenuItem(
                            value: i, child: Text('$i시'))),
                        onChanged: (v) => setSt(() => hour = v!),
                      ),
                    ),
                    Expanded(
                      child: DropdownButton<int>(
                        value: minute,
                        items: [0, 15, 30, 45].map((m) => DropdownMenuItem(
                            value: m, child: Text('$m분'))).toList(),
                        onChanged: (v) => setSt(() => minute = v!),
                      ),
                    ),
                  ]),
                TextField(
                  controller: thresholdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: '재고 부족 기준 큐브 수',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: webhookCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Discord 웹훅 URL',
                      border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () async {
                  try {
                    await SettingsActions.testNotification();
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('테스트 알림 전송됨')));
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx)
                          .showSnackBar(SnackBar(content: Text('실패: $e')));
                    }
                  }
                },
                child: const Text('테스트')),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SettingsActions.saveNotificationSettings({
                    'enabled': enabled,
                    'notify_hour': hour,
                    'notify_minute': minute,
                    'notify_threshold':
                        int.tryParse(thresholdCtrl.text) ?? 3,
                    'discord_webhook': webhookCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
                  }
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserManagement(BuildContext context) async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const _UserManagementScreen(),
    ));
  }
}

class _UserManagementScreen extends ConsumerStatefulWidget {
  const _UserManagementScreen();
  @override
  ConsumerState<_UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState
    extends ConsumerState<_UserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _users = await SettingsActions.getUsers();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('사용자 관리'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _addUser(context),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i];
                  return ListTile(
                    title: Text(u['username'] ?? ''),
                    subtitle: Text(u['is_active'] == 1 ? '활성' : '비활성'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(u['is_active'] == 1
                              ? Icons.block
                              : Icons.check_circle),
                          onPressed: () async {
                            await SettingsActions.toggleUser(u['id']);
                            _load();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await SettingsActions.deleteUser(u['id']);
                            _load();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      );

  Future<void> _addUser(BuildContext context) async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('사용자 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: userCtrl,
                decoration: const InputDecoration(labelText: '아이디', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: passCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              try {
                await SettingsActions.addUser(
                    userCtrl.text.trim(), passCtrl.text);
                if (context.mounted) Navigator.pop(context);
                _load();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('추가 실패: $e')));
                }
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 빌드 확인**

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutter build apk --debug 2>&1 | tail -5
```

- [ ] **Step 5: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "feat: StatsScreen + SettingsScreen 구현"
```

---

### Task 12: FCM 연동 (Firebase 초기화 + 실제 토큰 등록)

**Files:**
- Modify: `flutter/babymeal_app/lib/core/push/fcm_service.dart`
- Modify: `flutter/babymeal_app/lib/main.dart`
- Manual: `flutter/babymeal_app/android/app/google-services.json` (사용자가 직접 추가)

**전제 조건:**
Firebase Console에서 Android 앱을 등록하고 `google-services.json`을 `flutter/babymeal_app/android/app/` 에 복사해야 한다.
Package name은 `flutter create` 시 지정한 `com.babymeal.babymeal_app` 이다.

- [ ] **Step 1: `android/app/build.gradle`에 google-services 플러그인 확인**

`flutter/babymeal_app/android/app/build.gradle` 마지막 줄에 없으면 추가:

```gradle
apply plugin: 'com.google.gms.google-services'
```

`flutter/babymeal_app/android/build.gradle` 의 `dependencies` 블록에 없으면 추가:

```gradle
classpath 'com.google.gms:google-services:4.4.2'
```

- [ ] **Step 2: `fcm_service.dart` 완성**

```dart
// lib/core/push/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api/api_client.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {}

class FcmService {
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'babymeal_alerts',
    '치밀한 이유식 알림',
    importance: Importance.high,
  );

  static Future<void> init() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _localNotif.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id, _channel.name,
            importance: Importance.high,
          ),
        ),
      );
    });
    await FirebaseMessaging.instance.requestPermission();
  }

  static Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await ApiClient.instance.dio
          .post('/api/push/fcm-token', data: {'token': token});
    } catch (_) {}
  }

  static Future<void> unregisterToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await ApiClient.instance.dio
          .delete('/api/push/fcm-token', data: {'token': token});
    } catch (_) {}
    await FirebaseMessaging.instance.deleteToken();
  }
}
```

- [ ] **Step 3: `main.dart` Firebase 초기화 추가**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/push/fcm_service.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService.init();
  runApp(const ProviderScope(child: BabyMealApp()));
}

class BabyMealApp extends StatelessWidget {
  const BabyMealApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '치밀한 이유식',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF4BA3E3),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      );
}
```

- [ ] **Step 4: FlutterFire CLI로 `firebase_options.dart` 생성**

```bash
# FlutterFire CLI 설치 (미설치 시)
dart pub global activate flutterfire_cli

# Firebase 프로젝트에 연결 (google-services.json 추가 후 실행)
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutterfire configure
```

- [ ] **Step 5: 최종 릴리스 APK 빌드**

```bash
cd /Users/idaelo/project/babyMeal/flutter/babymeal_app
flutter build apk --release 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 6: 커밋**

```bash
cd /Users/idaelo/project/babyMeal
git add flutter/
git commit -m "feat: FCM 연동 + Firebase 초기화 완성"
```

---

## 마무리 체크리스트

- [ ] `pip3 install PyJWT firebase-admin` 서버에서 실행
- [ ] Firebase Console에서 Android 앱 등록 → `google-services.json` 추가
- [ ] Flask 서버의 `config.json`에 `firebase.service_account_path` 설정
- [ ] `sudo systemctl restart babymeal` 서버 재시작
- [ ] 앱에서 서버 URL(Cloudflare Tunnel 도메인) 입력 후 로그인 테스트
- [ ] 재고 조정 후 FCM 푸시 알림 수신 확인
