"""Renders the original CocEnglish mascot into launcher/notification/iOS PNGs.

Usage (from apps/mobile): python3 tool/brand/render.py
"""
import io, os, cairosvg
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
GREEN = (0x5B, 0xCD, 0x05, 255)
svg = open(os.path.join(HERE, 'mascot.svg')).read()

def frog(px):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=px, output_height=px))).convert('RGBA')

def on_green(px, round_mask=False, zoom=1.0):
    bg = Image.new('RGBA', (px, px), GREEN)
    f = frog(int(px * zoom))
    off = (px - f.width) // 2
    bg.alpha_composite(f, (off, off)) if off >= 0 else bg.alpha_composite(f.crop((-off, -off, -off + px, -off + px)))
    if round_mask:
        from PIL import ImageDraw
        m = Image.new('L', (px, px), 0); ImageDraw.Draw(m).ellipse((0, 0, px - 1, px - 1), fill=255)
        bg.putalpha(m)
    return bg

res = os.path.join(ROOT, 'android/app/src/main/res')
for d, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
    on_green(px, zoom=1.45).save(os.path.join(res, f'mipmap-{d}/ic_launcher.png'))
    on_green(px, round_mask=True, zoom=1.45).save(os.path.join(res, f'mipmap-{d}/ic_launcher_round.png'))
os.makedirs(os.path.join(res, 'drawable-nodpi'), exist_ok=True)
on_green(256, round_mask=True, zoom=1.45).save(os.path.join(res, 'drawable-nodpi/ic_notification_mascot.png'))

ios = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
for name in os.listdir(ios):
    if name.endswith('.png'):
        w = Image.open(os.path.join(ios, name)).width
        on_green(w, zoom=1.45).convert('RGB').save(os.path.join(ios, name))
print('ok')
