"""خط إيموجي «فارغ» للاختبار: يغطي رموز الإيموجي التي لا تملكها خطوط التطبيق، بحروف بلا رسم.

اختبار Flutter لا يملك خط إيموجي ملوّناً (Segoe UI Emoji ملوّن من نوع COLRv1 لا يرسمه المحرك)، فيرسم الرمز مربعاً.
هذا الخط يترك مكانه فارغاً بالعرض نفسه، ثم يرسم الفيديو الإيموجي الملوّن الحقيقي فوقه في الموضع الذي تسجّله اللقطة.
"""
import json
import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

out_dir = Path(sys.argv[1])
fonts = [Path(p) for p in sys.argv[2:]]

candidates = set()
for a, b in [
    (0x203C, 0x203C), (0x2049, 0x2049), (0x2122, 0x2122), (0x2139, 0x2139), (0x2194, 0x2199),
    (0x21A9, 0x21AA), (0x231A, 0x231B), (0x2328, 0x2328), (0x23CF, 0x23CF), (0x23E9, 0x23F3),
    (0x23F8, 0x23FA), (0x24C2, 0x24C2), (0x25AA, 0x25AB), (0x25B6, 0x25B6), (0x25C0, 0x25C0),
    (0x25FB, 0x25FE), (0x2600, 0x27BF), (0x2934, 0x2935), (0x2B05, 0x2B07), (0x2B1B, 0x2B1C),
    (0x2B50, 0x2B50), (0x2B55, 0x2B55), (0x3030, 0x3030), (0x303D, 0x303D), (0x3297, 0x3297),
    (0x3299, 0x3299), (0x1F000, 0x1FAFF),
]:
    candidates.update(range(a, b + 1))
# ما رسمته خطوط التطبيق نفسها يبقى نصاً كما في الهاتف
for f in fonts:
    cmap = TTFont(str(f)).getBestCmap()
    candidates -= set(cmap)
# المعدِّلات: لون البشرة، رابط الدمج، محدد العرض: بلا عرض
modifiers = set(range(0x1F3FB, 0x1F400)) | {0x200D, 0xFE0F, 0x20E3}
candidates -= modifiers

order = ['.notdef', 'blank', 'zero']
fb = FontBuilder(1000, isTTF=True)
fb.setupGlyphOrder(order)
cmap = {cp: 'blank' for cp in sorted(candidates)}
cmap.update({cp: 'zero' for cp in sorted(modifiers)})
fb.setupCharacterMap(cmap)
empty = TTGlyphPen(None).glyph()
fb.setupGlyf({n: empty for n in order})
fb.setupHorizontalMetrics({'.notdef': (500, 0), 'blank': (1170, 0), 'zero': (0, 0)})
fb.setupHorizontalHeader(ascent=900, descent=-200)
fb.setupNameTable({'familyName': 'BlankEmoji', 'styleName': 'Regular'})
fb.setupOS2(sTypoAscender=900, sTypoDescender=-200, usWinAscent=900, usWinDescent=200)
fb.setupPost()
out_dir.mkdir(parents=True, exist_ok=True)
fb.save(str(out_dir / 'blank_emoji.ttf'))
(out_dir / 'emoji_cps.json').write_text(
    json.dumps({'emoji': sorted(candidates), 'modifiers': sorted(modifiers)}), encoding='utf-8')
print('blank emoji font:', len(candidates), 'codepoints')
