"""MinIO 이미지 저장소 유틸리티

MinIO(S3 호환) 서버에 애니 썸네일을 캐싱하는 유틸리티 모듈.
minio 패키지 미설치 시 모든 함수가 안전하게 None/False를 반환한다.
"""

import io
import ssl
import logging
from urllib.request import urlopen, Request
from urllib.error import URLError

logger = logging.getLogger("minio_storage")

try:
    from minio import Minio
    from minio.error import S3Error
    MINIO_AVAILABLE = True
except ImportError:
    MINIO_AVAILABLE = False

# SSL 인증서 검증 비활성화 (onnada.com 인증서 이슈)
_SSL_CTX = ssl.create_default_context()
_SSL_CTX.check_hostname = False
_SSL_CTX.verify_mode = ssl.CERT_NONE


def get_minio_client(config):
    """config에서 Minio 클라이언트를 생성한다. 실패 시 None 반환."""
    if not MINIO_AVAILABLE:
        return None
    minio_cfg = config.get("minio")
    if not minio_cfg:
        return None
    try:
        return Minio(
            minio_cfg["endpoint"],
            access_key=minio_cfg["access_key"],
            secret_key=minio_cfg["secret_key"],
            secure=minio_cfg.get("secure", False),
        )
    except Exception as e:
        logger.warning(f"MinIO 클라이언트 생성 실패: {e}")
        return None


def ensure_bucket(client, bucket):
    """버킷이 없으면 생성한다."""
    if not client:
        return
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
        logger.info(f"MinIO 버킷 생성: {bucket}")


def _object_key(anime_id):
    """썸네일 오브젝트 키를 반환한다."""
    return f"thumbnails/{anime_id}.jpg"


def image_exists(client, bucket, anime_id):
    """MinIO에 해당 anime_id의 썸네일이 존재하는지 확인한다."""
    if not client:
        return False
    try:
        client.stat_object(bucket, _object_key(anime_id))
        return True
    except Exception:
        return False


def upload_thumbnail(client, bucket, anime_id, thumb_url):
    """onnada에서 이미지를 다운로드하여 MinIO에 업로드한다. 성공 시 True."""
    if not client or not thumb_url:
        return False
    try:
        req = Request(thumb_url, headers={"User-Agent": "Mozilla/5.0"})
        resp = urlopen(req, context=_SSL_CTX, timeout=15)
        data = resp.read()
        content_type = resp.headers.get("Content-Type", "image/jpeg")

        client.put_object(
            bucket,
            _object_key(anime_id),
            io.BytesIO(data),
            length=len(data),
            content_type=content_type,
        )
        return True
    except Exception as e:
        logger.debug(f"썸네일 업로드 실패 [{anime_id}]: {e}")
        return False


def get_image_data(client, bucket, anime_id):
    """MinIO에서 이미지 바이트와 content_type을 반환한다. 실패 시 (None, None)."""
    if not client:
        return None, None
    try:
        response = client.get_object(bucket, _object_key(anime_id))
        data = response.read()
        content_type = response.headers.get("Content-Type", "image/jpeg")
        response.close()
        response.release_conn()
        return data, content_type
    except Exception:
        return None, None


def upload_bytes(client, bucket, key, data, content_type="image/jpeg"):
    """임의 키로 바이트 데이터를 MinIO에 업로드. 성공 시 True."""
    if not client or not data:
        return False
    try:
        client.put_object(bucket, key, io.BytesIO(data), length=len(data),
                          content_type=content_type)
        return True
    except Exception as e:
        logger.debug(f"업로드 실패 [{key}]: {e}")
        return False


def get_bytes(client, bucket, key):
    """임의 키로 MinIO에서 데이터 조회. 실패 시 (None, None)."""
    if not client:
        return None, None
    try:
        response = client.get_object(bucket, key)
        data = response.read()
        content_type = response.headers.get("Content-Type", "image/jpeg")
        response.close()
        response.release_conn()
        return data, content_type
    except Exception:
        return None, None
