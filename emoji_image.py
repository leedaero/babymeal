import logging
import urllib.request

logger = logging.getLogger('emoji_image')

TWEMOJI_BASE = 'https://cdnjs.cloudflare.com/ajax/libs/twemoji/14.0.2/72x72'


def emoji_to_codepoint(emoji: str) -> str:
    """이모지 문자 → Twemoji 파일명. VS16(U+FE0F) 제거."""
    return '-'.join(f'{ord(c):x}' for c in emoji if ord(c) != 0xFE0F)
