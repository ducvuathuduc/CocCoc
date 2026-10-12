"""People, animals, food, school things, times of day."""
from kit import (C, rect, circle, ellipse, path, poly, line, stroke, slab, disc, shine, shadow,
                 group, person, face)

ART = {}


def art(name):
    def deco(fn):
        ART[name] = fn
        return fn
    return deco


# ---------------------------------------------------------------- people

@art('friend')
def _():
    a, _ = person(176, 440, 0.95, style='short', hair='brownDark', top='green', topd='greenDark', arms='up')
    b, _ = person(336, 440, 0.95, skin='skin2', style='pigtails', hair='black', top='orange', topd='orangeDark')
    heart = path('M256,118 C256,92 222,88 222,116 C222,138 256,154 256,162 C256,154 290,138 290,116 C290,88 256,92 256,118 Z', 'red')
    return shadow(256, 448, 190) + a + b + heart


@art('student')
def _():
    bag = slab(176, 236, 160, 150, 40, 'red', 'redDark')
    p, (cx, hy, hr, ty, bw, bh) = person(256, 446, 1.0, style='short', hair='black', top='blue', topd='blueDark', child=True)
    book = slab(300, 300, 74, 92, 10, 'yellow', 'yellowDark', 8) + rect(312, 314, 50, 8, 4, 'white')
    straps = line(214, ty + 6, 214, ty + bh - 6, 'redDark', 14) + line(298, ty + 6, 298, ty + bh - 6, 'redDark', 14)
    return shadow() + bag + p + straps + book


@art('teacher')
def _():
    board = slab(40, 60, 270, 190, 22, 'greenDark', 'navy') + rect(56, 76, 238, 158, 14, 'tealDark')
    board += stroke('M84,120 L150,120 M84,160 L210,160 M84,198 L180,198', 'white', 12)
    p, (cx, hy, hr, ty, bw, bh) = person(360, 448, 1.0, style='bun', hair='brown', top='purple', topd='purpleDark', glasses=True, arms='up')
    return shadow(250, 450, 200) + board + p


@art('mother')
def _():
    p, _ = person(256, 448, 1.08, style='long', hair='brownDark', top='pink', topd='purpleDark')
    return shadow() + p


@art('father')
def _():
    tie = path('M256,248 L270,262 L262,320 L256,330 L250,320 L242,262 Z', 'red')
    p, (cx, hy, hr, ty, bw, bh) = person(256, 448, 1.08, style='short', hair='black', top='blue', topd='blueDark', beard='mustache')
    collar = poly([(232, ty + 4), (256, ty + 26), (280, ty + 4)], 'white')
    return shadow() + p + collar + tie.replace('248', str(int(ty + 18)))


@art('family')
def _():
    dad, _ = person(150, 444, 0.82, style='short', hair='black', top='blue', topd='blueDark', beard='mustache')
    mom, _ = person(362, 444, 0.82, style='long', hair='brownDark', top='pink', topd='purpleDark')
    kid1, _ = person(232, 452, 0.62, style='short', hair='brown', top='green', topd='greenDark', child=True)
    kid2, _ = person(288, 452, 0.62, style='pigtails', hair='brownDark', top='orange', topd='orangeDark', child=True)
    return shadow(256, 456, 230) + group(dad + mom + kid1 + kid2, 'translate(256,452) scale(1.18) translate(-256,-452)')


@art('brother')
def _():
    stripe = rect(196, 300, 120, 18, 0, 'white')
    p, (cx, hy, hr, ty, bw, bh) = person(256, 446, 1.05, style='short', hair='brown', top='green', topd='greenDark', child=True, arms='up')
    return shadow() + p + rect(cx - bw / 2 + 6, ty + 40, bw - 12, 16, 8, 'greenLight')


@art('sister')
def _():
    p, (cx, hy, hr, ty, bw, bh) = person(256, 446, 1.05, style='pigtails', hair='brownDark', top='red', topd='redDark', child=True)
    skirt = path(f'M{cx - bw / 2 - 6:g},{ty + bh - 30:g} L{cx + bw / 2 + 6:g},{ty + bh - 30:g} L{cx + bw / 2 + 26:g},{ty + bh + 22:g} '
                 f'L{cx - bw / 2 - 26:g},{ty + bh + 22:g} Z', 'redDark')
    bows = circle(cx - hr * 1.05, hy - hr * 0.35, 16, 'yellow') + circle(cx + hr * 1.05, hy - hr * 0.35, 16, 'yellow')
    return shadow() + p + skirt + bows


@art('grandmother')
def _():
    p, (cx, hy, hr, ty, bw, bh) = person(256, 448, 1.05, style='bun', hair='grayLight', top='purple', topd='purpleDark', glasses=True)
    shawl = path(f'M{cx - bw / 2:g},{ty + 20:g} Q{cx:g},{ty + 90:g} {cx + bw / 2:g},{ty + 20:g} L{cx + bw / 2:g},{ty + 4:g} L{cx - bw / 2:g},{ty + 4:g} Z', 'pink')
    return shadow() + p + shawl


@art('grandfather')
def _():
    cane = stroke('M372,446 L372,300 Q372,270 346,272', 'brown', 16)
    p, (cx, hy, hr, ty, bw, bh) = person(250, 448, 1.05, style='bald', hair='grayLight', top='brownLight', topd='brown', glasses=True, beard='mustache', legs='grayDark')
    return shadow() + p + cane


@art('baby')
def _():
    blanket = path('M120,300 Q120,190 256,190 Q392,190 392,300 Q392,420 256,430 Q120,420 120,300 Z', 'blueSky')
    blanket += path('M150,330 Q256,300 362,330 Q362,420 256,428 Q150,420 150,330 Z', 'blue')
    head = circle(256, 236, 92, 'skin') + face(256, 248, 92)
    curl = stroke('M248,146 Q262,128 276,146', 'brownDark', 12)
    pacifier = circle(256, 296, 22, 'yellow') + circle(256, 296, 10, 'pink')
    return shadow(256, 448, 150) + blanket + head + curl + pacifier


def worker(top, topd, hat='', props='', **kw):
    p, geo = person(256, 448, 1.05, top=top, topd=topd, **kw)
    return shadow() + p + hat.format(*geo[:3]) + props


@art('doctor')
def _():
    p, (cx, hy, hr, ty, bw, bh) = person(256, 448, 1.05, style='short', hair='black', top='white', topd='grayLight', legs='blueDark')
    lapels = poly([(cx - 20, ty + 4), (cx, ty + 60), (cx + 20, ty + 4)], 'blue')
    steth = stroke(f'M{cx - 34:g},{ty + 10:g} Q{cx - 40:g},{ty + 80:g} {cx:g},{ty + 84:g} Q{cx + 40:g},{ty + 80:g} {cx + 34:g},{ty + 10:g}', 'grayDark', 9)
    steth += circle(cx, ty + 90, 13, 'grayDark') + circle(cx, ty + 90, 6, 'gray')
    pocket = rect(cx + 24, ty + 56, 30, 28, 6, 'bluePale') + rect(cx + 34, ty + 44, 6, 22, 3, 'red')
    return shadow() + p + lapels + steth + pocket


@art('nurse')
def _():
    p, (cx, hy, hr, ty, bw, bh) = person(256, 448, 1.05, style='bun', hair='brownDark', top='teal', topd='tealDark', legs='tealDark')
    cap = slab(cx - 52, hy - hr * 1.02 - 6, 104, 46, 14, 'white', 'grayLight', 6)
    cross = rect(cx - 6, hy - hr - 2, 12, 34, 3, 'red') + rect(cx - 17, hy - hr + 9, 34, 12, 3, 'red')
    badge = rect(cx - 50, ty + 34, 30, 22, 6, 'white')
    return shadow() + p + cap + cross + badge


@art('engineer')
def _():
    p, (cx, hy, hr, ty, bw, bh) = person(256, 448, 1.05, style='short', hair='brownDark', top='orange', topd='orangeDark', legs='blueDark')
    vest = rect(cx - bw / 2 + 10, ty + 54, bw - 20, 14, 7, 'yellowPale')
    hat = path(f'M{cx - hr * 1.15:g},{hy - hr * 0.22:g} Q{cx - hr:g},{hy - hr * 1.25:g} {cx:g},{hy - hr * 1.2:g} '
               f'Q{cx + hr:g},{hy - hr * 1.25:g} {cx + hr * 1.15:g},{hy - hr * 0.22:g} Z', 'yellow')
    hat += rect(cx - hr * 1.3, hy - hr * 0.32, hr * 2.6, 22, 11, 'yellowDark') + rect(cx - 8, hy - hr * 1.18, 16, hr * 0.9, 8, 'yellowDark')
    wrench = stroke('M352,330 L392,276', 'grayDark', 16) + circle(396, 270, 18, 'grayDark') + circle(402, 262, 9, 'white')
    return shadow() + p + vest + hat + wrench


@art('driver')
def _():
    p, (cx, hy, hr, ty, bw, bh) = person(256, 420, 1.0, style='short', hair='black', top='blue', topd='blueDark', legs='navy')
    cap = path(f'M{cx - hr * 1.02:g},{hy - hr * 0.2:g} Q{cx:g},{hy - hr * 1.5:g} {cx + hr * 1.02:g},{hy - hr * 0.2:g} Z', 'navy')
    cap += rect(cx - hr * 1.0, hy - hr * 0.34, hr * 2.25, 20, 10, 'ink') + circle(cx, hy - hr * 0.72, 11, 'yellow')
    wheel = (f'<circle cx="256" cy="380" r="86" fill="none" stroke="{C["ink"]}" stroke-width="26"/>'
             + rect(176, 368, 160, 24, 12, 'ink') + circle(256, 380, 26, 'grayDark'))
    return shadow(256, 470, 170, 18) + p + wheel


@art('dentist')
def _():
    p, (cx, hy, hr, ty, bw, bh) = person(210, 448, 1.0, style='long', hair='black', top='white', topd='grayLight', legs='blue')
    mask = rect(cx - hr * 0.6, hy + hr * 0.3, hr * 1.2, hr * 0.55, 14, 'bluePale')
    tooth = path('M330,170 Q330,120 372,124 Q392,128 402,140 Q412,128 432,124 Q474,120 474,170 Q474,220 456,262 '
                 'Q448,300 434,300 Q422,300 418,262 Q412,236 402,236 Q392,236 386,262 Q382,300 370,300 Q356,300 348,262 Q330,220 330,170 Z', 'white')
    tooth_shadow = group(path('M330,170 Q330,120 372,124 Q392,128 402,140 Q412,128 432,124 Q474,120 474,170 Q474,220 456,262 '
                              'Q448,300 434,300 Q422,300 418,262 Q412,236 402,236 Q392,236 386,262 Q382,300 370,300 Q356,300 348,262 Q330,220 330,170 Z', 'grayLight'),
                         'translate(0,10)')
    sparkle = path('M462,96 L470,116 L490,124 L470,132 L462,152 L454,132 L434,124 L454,116 Z', 'yellow')
    mirror = stroke('M300,360 L344,310', 'grayDark', 12) + circle(352, 300, 18, 'blueSky')
    badge = disc(402, 206, 104, 'blueSky', 'blue', 10)
    return shadow(256, 450, 200) + p + mask + badge + tooth_shadow + tooth + shine(352, 146, 30, 12) + sparkle + mirror


# ---------------------------------------------------------------- animals

@art('cat')
def _():
    tail = stroke('M352,392 Q440,380 420,300 Q410,262 380,270', 'orangeDark', 34)
    body = ellipse(256, 360, 120, 86, 'orange') + ellipse(256, 380, 70, 56, 'cream')
    ears = poly([(166, 190), (178, 108), (232, 152)], 'orange') + poly([(346, 190), (334, 108), (280, 152)], 'orange')
    ears += poly([(180, 166), (186, 130), (212, 152)], 'pink') + poly([(332, 166), (326, 130), (300, 152)], 'pink')
    head = circle(256, 214, 96, 'orange') + face(256, 220, 96, cheeks=True)
    nose = path('M246,244 L266,244 L256,256 Z', 'pink')
    whisk = stroke('M150,238 L204,246 M150,266 L204,258 M362,238 L308,246 M362,266 L308,258', 'orangeDark', 7)
    stripes = stroke('M236,132 L240,154 M256,126 L256,152 M276,132 L272,154', 'orangeDark', 9)
    paws = ellipse(206, 438, 36, 20, 'orange') + ellipse(306, 438, 36, 20, 'orange')
    return shadow() + tail + body + paws + ears + head + nose + whisk + stripes


@art('dog')
def _():
    tail = stroke('M354,360 Q420,330 410,280', 'brown', 30)
    body = ellipse(256, 364, 118, 84, 'brownLight') + ellipse(256, 384, 66, 52, 'cream')
    head = circle(256, 214, 98, 'brownLight')
    ears = ellipse(158, 214, 34, 70, 'brownDark', ' transform="rotate(14 158 214)"') + ellipse(354, 214, 34, 70, 'brownDark', ' transform="rotate(-14 354 214)"')
    patch = circle(300, 190, 34, 'brown')
    muzzle = ellipse(256, 262, 54, 38, 'cream') + ellipse(256, 246, 22, 15, 'ink')
    eyes = face(256, 212, 90, mood='none', cheeks=False)
    tongue = path('M244,280 Q256,316 268,280 Z', 'red')
    paws = ellipse(206, 440, 36, 20, 'brownLight') + ellipse(306, 440, 36, 20, 'brownLight')
    collar = rect(196, 296, 120, 20, 10, 'red') + circle(256, 322, 13, 'yellow')
    return shadow() + tail + body + paws + head + patch + ears + eyes + muzzle + tongue + collar


# ---------------------------------------------------------------- food & drink

@art('water')
def _():
    glass = path('M150,96 L362,96 L334,432 Q332,446 318,446 L194,446 Q180,446 178,432 Z', 'bluePale')
    water = path('M162,200 Q210,184 256,200 Q302,216 350,200 L334,432 Q332,446 318,446 L194,446 Q180,446 178,432 Z', 'blueSky')
    water += path('M174,330 L340,330 L334,432 Q332,446 318,446 L194,446 Q180,446 178,432 Z', 'blue')
    drop = path('M400,110 Q430,160 430,180 Q430,210 400,210 Q370,210 370,180 Q370,160 400,110 Z', 'blue')
    return shadow(256, 452, 130) + glass + water + rect(196, 230, 22, 120, 11, 'white') + drop + shine(384, 168, 12, 22)


@art('rice')
def _():
    rice = path('M118,256 Q118,150 256,140 Q394,150 394,256 Z', 'tan')
    rice += path('M128,256 Q128,160 256,150 Q384,160 384,256 Z', 'cream')
    for i, (x, y) in enumerate([(176, 236), (216, 200), (256, 186), (296, 200), (336, 236), (236, 226), (280, 228), (196, 250), (316, 250), (256, 238)]):
        rice += ellipse(x, y - 4, 16, 9, 'white')
    bowl = path('M100,250 L412,250 Q408,380 300,410 L212,410 Q104,380 100,250 Z', 'blue')
    bowl_lip = rect(96, 236, 320, 34, 17, 'blueDark')
    rim = path('M120,300 Q256,330 392,300', 'none', f' stroke="{C["bluePale"]}" stroke-width="12" stroke-linecap="round"')
    base = rect(200, 404, 112, 30, 12, 'blueDark')
    sticks = line(300, 70, 420, 190, 'brown', 16) + line(340, 60, 440, 160, 'brownLight', 16)
    return shadow(256, 444, 170) + sticks + rice + bowl_lip + bowl + base + rim


@art('bread')
def _():
    loaf = group(ellipse(256, 0, 200, 70, 'brown') + ellipse(256, -14, 196, 64, 'brownLight')
                 + stroke('M150,-40 Q170,-10 160,24 M220,-56 Q240,-20 230,20 M290,-56 Q310,-20 300,20 M360,-40 Q380,-10 370,24', 'tan', 14)
                 + shine(170, -64, 60, 14), 'translate(0,280) rotate(-14 256 0)')
    return shadow(256, 420, 190) + loaf


@art('apple')
def _():
    body = path('M256,170 C200,120 92,140 100,270 C108,380 190,446 256,420 C322,446 404,380 412,270 C420,140 312,120 256,170 Z', 'redDark')
    body2 = path('M256,160 C200,110 92,130 100,258 C108,368 190,430 256,404 C322,430 404,368 412,258 C420,130 312,110 256,160 Z', 'red')
    stem = stroke('M256,166 Q252,120 270,92', 'brownDark', 18)
    leaf = path('M276,120 Q320,66 380,92 Q340,148 276,120 Z', 'green')
    return shadow(256, 444, 150) + body + body2 + stem + leaf + shine(150, 214, 22, 56)


@art('tea')
def _():
    saucer = ellipse(256, 410, 190, 36, 'greenDark') + ellipse(256, 400, 190, 34, 'green')
    cup = path('M120,230 L392,230 Q392,400 256,406 Q120,400 120,230 Z', 'greenDark') + path('M120,220 L392,220 Q392,390 256,396 Q120,390 120,220 Z', 'greenPale')
    tea = ellipse(256, 222, 136, 26, 'greenLight')
    handle = f'<path d="M386,250 Q456,250 446,306 Q436,350 378,340" fill="none" stroke="{C["greenDark"]}" stroke-width="22"/>'
    band = path('M128,270 L384,270 Q380,300 372,316 L140,316 Q132,300 128,270 Z', 'white')
    steam = stroke('M206,180 Q186,150 206,120 Q226,90 206,60 M266,180 Q246,150 266,120 Q286,90 266,60', 'grayLight', 14)
    leaf = path('M236,282 Q256,262 284,282 Q256,304 236,282 Z', 'green')
    return shadow(256, 444, 190) + saucer + handle + cup + band + leaf + tea + steam


@art('coffee')
def _():
    handle = f'<path d="M370,220 Q450,220 440,290 Q430,350 364,340" fill="none" stroke="{C["redDark"]}" stroke-width="26"/>'
    mug = slab(130, 170, 250, 260, 50, 'red', 'redDark')
    coffee = ellipse(255, 184, 110, 22, 'brownDark')
    bean = ellipse(256, 312, 34, 48, 'brownDark', ' transform="rotate(20 256 312)"') + stroke('M246,276 Q272,312 262,350', 'brown', 7)
    steam = stroke('M216,140 Q196,110 216,80 Q236,50 216,24 M292,140 Q272,110 292,80 Q312,50 292,24', 'grayLight', 14)
    return shadow(256, 452, 170) + handle + mug + coffee + bean + steam + shine(156, 214, 16, 50)


@art('milk')
def _():
    side = path('M326,170 L392,140 L392,400 L326,440 Z', 'grayLight')
    front = rect(150, 180, 176, 270, 18, 'grayLight') + rect(150, 170, 176, 266, 18, 'white')
    roof = poly([(150, 170), (204, 92), (380, 76), (326, 170)], 'blueSky')
    roof += poly([(204, 92), (220, 60), (390, 46), (380, 76)], 'blue')
    label = rect(170, 260, 136, 120, 16, 'blue') + path('M200,330 Q238,290 276,330 Q238,366 200,330 Z', 'white')
    drop = path('M238,280 Q252,300 252,310 Q252,322 238,322 Q224,322 224,310 Q224,300 238,280 Z', 'bluePale')
    return shadow(256, 450, 150) + side + front + roof + label + drop


@art('juice')
def _():
    straw = line(300, 60, 270, 210, 'red', 18)
    glass = path('M150,150 L362,150 L334,432 Q332,446 318,446 L194,446 Q180,446 178,432 Z', 'yellowPale')
    juice = path('M160,210 L352,210 L334,432 Q332,446 318,446 L194,446 Q180,446 178,432 Z', 'orange')
    slice_ = circle(356, 168, 56, 'orangeDark') + circle(356, 168, 46, 'yellow')
    slice_ += stroke('M356,126 L356,210 M314,168 L398,168 M326,138 L386,198 M386,138 L326,198', 'orange', 6)
    return shadow(256, 452, 130) + straw + glass + juice + rect(196, 240, 20, 120, 10, 'yellowPale') + slice_


@art('chicken')
def _():
    plate = ellipse(256, 400, 200, 46, 'grayLight') + ellipse(256, 392, 170, 36, 'white')
    bone = circle(392, 168, 26, 'cream') + circle(412, 196, 26, 'cream') + line(330, 240, 392, 186, 'cream', 30)
    meat = path('M140,330 C120,240 200,170 300,190 C360,204 370,260 340,300 C300,360 170,380 140,330 Z', 'orangeDark')
    meat2 = path('M150,320 C134,244 204,182 296,198 C350,210 356,258 330,292 C296,346 176,362 150,320 Z', 'orange')
    return shadow(256, 440, 200) + plate + bone + meat + meat2 + shine(188, 240, 44, 16)


@art('fish')
def _():
    tail = poly([(352, 256), (440, 186), (430, 256), (440, 326)], 'blueDark')
    body = path('M80,256 Q160,140 300,160 Q370,176 380,256 Q370,336 300,352 Q160,372 80,256 Z', 'blue')
    belly = path('M110,280 Q200,340 300,330 Q350,320 370,280 Q240,300 110,280 Z', 'blueSky')
    fin = path('M210,166 Q250,100 300,162 Z', 'blueDark') + path('M220,330 Q250,380 280,340 Z', 'blueDark')
    eye = circle(150, 236, 20, 'white') + circle(146, 238, 11, 'ink')
    gill = stroke('M200,210 Q216,256 200,300', 'blueDark', 10)
    return shadow(256, 430, 170) + tail + fin + body + belly + eye + gill + shine(236, 196, 50, 14)


@art('egg')
def _():
    whole = group(ellipse(0, 10, 82, 108, 'tan') + ellipse(0, 0, 82, 108, 'cream') + shine(-46, -60, 18, 40), 'translate(150,300) rotate(-10)')
    fried = path('M250,300 Q240,220 320,220 Q360,180 410,230 Q470,250 452,320 Q470,390 390,400 Q330,430 290,390 Q230,380 250,300 Z', 'white')
    yolk = circle(360, 310, 52, 'orange') + circle(360, 304, 52, 'yellow') + shine(334, 282, 22, 10)
    return shadow(290, 440, 210) + group(fried, 'translate(0,10)').replace(C['white'], C['grayLight']) + fried + yolk + whole


# ---------------------------------------------------------------- school things

@art('phone')
def _():
    body = slab(156, 56, 200, 384, 44, 'ink', 'black')
    screen = rect(174, 96, 164, 290, 22, 'blue')
    apps = ''
    cols = ['yellow', 'green', 'red', 'purple', 'orange', 'white']
    for i in range(6):
        apps += rect(194 + (i % 3) * 46, 126 + (i // 3) * 50, 34, 34, 10, cols[i])
    btn = circle(256, 410, 14, 'grayDark')
    return shadow(256, 464, 130) + body + screen + apps + rect(194, 250, 124, 18, 9, 'blueSky') + rect(194, 282, 86, 18, 9, 'blueSky') + btn


@art('book')
def _():
    pages = path('M96,140 L256,170 L416,140 L416,400 L256,430 L96,400 Z', 'grayLight')
    left = path('M110,120 Q190,110 256,150 L256,404 Q190,370 110,382 Z', 'white')
    right = path('M402,120 Q322,110 256,150 L256,404 Q322,370 402,382 Z', 'cream')
    cover = path('M80,150 L80,408 L256,440 L432,408 L432,150 L416,150 L416,400 L256,430 L96,400 L96,150 Z', 'green')
    lines = stroke('M140,170 L224,184 M140,214 L224,228 M140,258 L224,272 M288,184 L372,170 M288,228 L372,214 M288,272 L346,262', 'gray', 10)
    mark = path('M330,120 L366,120 L366,200 L348,184 L330,200 Z', 'red')
    return shadow(256, 458, 190) + cover + pages + left + right + lines + mark


@art('pen')
def _():
    pen = group(slab(-170, -34, 300, 68, 34, 'blue', 'blueDark', 10)
                + poly([(130, -30), (196, 0), (130, 30)], 'tan') + poly([(176, -9), (198, 0), (176, 9)], 'ink')
                + rect(-196, -34, 60, 68, 30, 'navy') + rect(-150, -50, 100, 20, 10, 'grayDark')
                + shine(-110, -20, 140, 10), 'translate(256,256) rotate(-38)')
    scribble = stroke('M84,420 Q130,380 170,420 T260,420', 'blue', 12)
    return shadow(256, 452, 150) + pen + scribble


@art('bag')
def _():
    strap = f'<path d="M176,180 Q176,90 256,90 Q336,90 336,180" fill="none" stroke="{C["redDark"]}" stroke-width="26"/>'
    body = slab(120, 150, 272, 290, 64, 'red', 'redDark', 16)
    flap = path('M120,214 Q120,150 184,150 L328,150 Q392,150 392,214 L392,250 Q256,290 120,250 Z', 'redDark')
    pocket = slab(180, 300, 152, 104, 30, 'orange', 'orangeDark', 10)
    buckle = rect(236, 248, 40, 40, 10, 'yellow')
    return shadow(256, 464, 170) + strap + body + flap + pocket + buckle + shine(150, 300, 14, 60)


@art('school')
def _():
    main = slab(110, 200, 292, 230, 16, 'yellow', 'yellowDark')
    roof = poly([(96, 210), (256, 100), (416, 210)], 'red')
    pole = line(256, 106, 256, 30, 'grayDark', 8) + path('M260,32 L320,48 L260,66 Z', 'red')
    bell = circle(256, 176, 28, 'white') + circle(256, 176, 16, 'yellowDark')
    door = path('M220,430 L220,350 Q256,316 292,350 L292,430 Z', 'brown')
    wins = ''.join(rect(x, y, 56, 50, 10, 'blueSky') for x in (136, 320) for y in (240, 330))
    return shadow(256, 448, 210) + main + roof + pole + bell + wins + door


@art('morning')
def _():
    sky = path('M40,320 Q40,120 256,120 Q472,120 472,320 Z', 'bluePale')
    rays = ''.join(line(256 + 150 * __import__('math').cos(a), 320 - 150 * __import__('math').sin(a),
                        256 + 196 * __import__('math').cos(a), 320 - 196 * __import__('math').sin(a), 'yellow', 18)
                   for a in [0.35, 0.85, 1.35, 1.8, 2.3, 2.8])
    sun = circle(256, 320, 112, 'orange') + circle(256, 320, 96, 'yellow')
    hills = path('M30,330 Q140,260 256,320 Q372,260 482,330 L482,420 Q482,440 462,440 L50,440 Q30,440 30,420 Z', 'green')
    hills += path('M30,380 Q160,330 300,380 Q400,350 482,380 L482,420 Q482,440 462,440 L50,440 Q30,440 30,420 Z', 'greenDark')
    bird = stroke('M120,170 Q136,154 152,170 Q168,154 184,170', 'ink', 8)
    return sky + rays + sun + hills + bird


@art('evening')
def _():
    sky = rect(40, 80, 432, 360, 60, 'orange') + rect(40, 80, 432, 140, 60, 'purple') + rect(40, 160, 432, 80, 0, 'pink')
    sun = path('M156,330 A100,100 0 0 1 356,330 Z', 'yellow')
    sea = rect(40, 330, 432, 110, 0, 'purpleDark') + path('M40,330 L472,330 L472,380 Q472,440 412,440 L100,440 Q40,440 40,380 Z', 'purpleDark')
    glints = stroke('M190,366 L322,366 M220,398 L292,398', 'yellow', 12)
    cloud = rect(300, 120, 120, 34, 17, 'pink') + rect(330, 104, 70, 34, 17, 'pink')
    return sky + cloud + sun + sea + glints


@art('night')
def _():
    sky = rect(40, 56, 432, 400, 70, 'navy')
    moon = circle(230, 230, 110, 'yellow') + circle(282, 196, 96, 'navy')
    stars = ''
    for x, y, r in [(370, 120, 16), (400, 260, 12), (120, 380, 14), (330, 380, 18), (140, 120, 10)]:
        stars += path(f'M{x},{y - r * 1.6} L{x + r * 0.45},{y - r * 0.45} L{x + r * 1.6},{y} L{x + r * 0.45},{y + r * 0.45} '
                      f'L{x},{y + r * 1.6} L{x - r * 0.45},{y + r * 0.45} L{x - r * 1.6},{y} L{x - r * 0.45},{y - r * 0.45} Z', 'yellowPale')
    return sky + moon + stars
