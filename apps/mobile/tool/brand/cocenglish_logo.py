"""CocEnglish original vector construction and PNG exports (Python + Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, math, re

app = Path(__file__).resolve().parents[2]
assets = app / 'assets/brand'
assets.mkdir(parents=True, exist_ok=True)
orange, cream = '#F47721', '#FFF7EF'
shape = 'M144 64 H368 Q448 64 448 144 V324 Q448 404 368 404 H224 L112 460 L136 404 Q64 404 64 324 V144 Q64 64 144 64 Z'
c = 'M326.71 159.29 A100 100 0 1 0 326.71 300.71'
svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><title>CocEnglish</title><path fill="{orange}" d="{shape}"/><path fill="none" stroke="white" stroke-width="44" stroke-linecap="round" d="{c}"/></svg>\n'
(assets / 'cocenglish-mark.svg').write_text(svg, encoding='utf-8')

def icon(size, background=True):
    im = Image.new('RGBA', (2048,2048), cream if background else (0,0,0,0))
    d = ImageDraw.Draw(im)
    def rect(coords): return tuple(int(x*4) for x in coords)
    d.rounded_rectangle(rect((64,64,448,404)), radius=320, fill=orange)
    d.polygon([tuple(int(v*4) for v in p) for p in [(136,380),(112,460),(240,396)]], fill=orange)
    d.arc(rect((134,108,378,352)), 45,315, fill='white', width=176)
    for angle in [45,315]:
        x=256+100*math.cos(math.radians(angle)); y=230+100*math.sin(math.radians(angle))
        d.ellipse(rect((x-22,y-22,x+22,y+22)), fill='white')
    return im.resize((size,size), Image.Resampling.LANCZOS)

icon(1024,False).save(assets / 'cocenglish-mark.png')
web = app / 'web'
icon(64).save(web / 'favicon.png')
for n in [192,512]:
    for name in [f'Icon-{n}.png', f'Icon-maskable-{n}.png']:
        if 'maskable' in name:
            masked=Image.new('RGBA',(n,n),cream); inner=icon(round(n*.75))
            masked.paste(inner,((n-inner.width)//2,(n-inner.height)//2),inner)
            masked.convert('RGB').save(web / 'icons' / name)
        else:
            icon(n).convert('RGB').save(web / 'icons' / name)
res = app / 'android/app/src/main/res'
for density,n in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    for name in ['ic_launcher.png','ic_launcher_round.png']:
        icon(n).save(res / f'mipmap-{density}' / name)
vector = f'''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
<group android:scaleX="0.14" android:scaleY="0.14" android:translateX="18" android:translateY="18">
<path android:fillColor="{orange}" android:pathData="{shape}"/>
<path android:fillColor="#00000000" android:strokeColor="#FFFFFF" android:strokeWidth="44" android:strokeLineCap="round" android:pathData="{c}"/>
</group></vector>'''
(res / 'drawable/ic_launcher_foreground.xml').write_text(vector, encoding='utf-8')
mono = vector.replace(f'android:fillColor="{orange}"', 'android:fillColor="#00000000" android:strokeColor="#FFFFFF" android:strokeWidth="20"')
(res / 'drawable/ic_launcher_monochrome.xml').write_text(mono, encoding='utf-8')
colors = res / 'values/colors.xml'
text = colors.read_text(encoding='utf-8')
for key in ['launch_background','ic_launcher_background']:
    text = re.sub(r'(<color name="'+key+r'">).*?(</color>)', r'\g<1>'+cream+r'\2', text)
colors.write_text(text, encoding='utf-8')
ios = app / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((ios / 'Contents.json').read_text())['images']:
    if 'filename' in entry:
        n = round(float(entry['size'].split('x')[0])*float(entry['scale'].rstrip('x')))
        icon(n).convert('RGB').save(ios / entry['filename'])
launch = app / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for f in launch.glob('*.png'):
    with Image.open(f) as old: dims = old.size
    mark=icon(min(dims),False); img=Image.new('RGBA',dims,(0,0,0,0))
    img.paste(mark,((dims[0]-mark.width)//2,(dims[1]-mark.height)//2)); img.save(f)
manifest = web / 'manifest.json'
m = json.loads(manifest.read_text())
m.update(name='CocEnglish',short_name='CocEnglish',background_color=cream,theme_color=orange,description='CocEnglish — English learning and practice.')
manifest.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
preview=Image.new('RGB',(1400,760),cream); mark=icon(440); preview.paste(mark,(80,130),mark)
d=ImageDraw.Draw(preview)
d.text((560,275),'CocEnglish',fill=orange,font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',94))
d.text((565,395),'Learn. Speak. Connect.',fill='#794524',font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',34))
preview.save(assets / 'brand-preview.png')
print('Created SVG/PNG and Android/iOS/Web icon exports.')
