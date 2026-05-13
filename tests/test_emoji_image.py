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
