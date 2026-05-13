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
