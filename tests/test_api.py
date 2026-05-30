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
        sess['user_id'] = 1
        sess['view_as_user_id'] = 1
        sess['is_admin'] = True
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
    call_args = cur.execute.call_args_list[0]
    assert '1' in str(call_args) or 1 in str(call_args)


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


def test_jwt_helper_make_and_decode(app):
    with app.app_context():
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
