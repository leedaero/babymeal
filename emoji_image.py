from __future__ import annotations

import logging
import urllib.request

from minio_storage import upload_bytes

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
