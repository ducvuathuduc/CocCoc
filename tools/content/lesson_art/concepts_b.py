"""Home, school, weather, shopping, city, travel, work, hobbies, health, celebrations."""
import math

from kit import (C, rect, circle, ellipse, path, poly, line, stroke, slab, disc, shine, shadow,
                 group, person, face)

ART = {}


def art(name):
    def deco(fn):
        ART[name] = fn
        return fn
    return deco


# ---------------------------------------------------------------- helpers

def windows(x, y, cols, rows, w, h, gx, gy, c='blueSky'):
    return ''.join(rect(x + i * (w + gx), y + j * (h + gy), w, h, min(w, h) * 0.22, c)
                   for i in range(cols) for j in range(rows))


def cloud(x, y, s=1.0, c='white', cd='grayLight'):
    def blob(dy, col):
        return (rect(x - 70 * s, y - 20 * s + dy, 140 * s, 44 * s, 22 * s, col)
                + circle(x - 22 * s, y - 24 * s + dy, 34 * s, col) + circle(x + 26 * s, y - 14 * s + dy, 26 * s, col))
    return blob(8 * s, cd) + blob(0, c)


def tree(x, by, s=1.0, c='green', cd='greenDark'):
    return (rect(x - 14 * s, by - 90 * s, 28 * s, 90 * s, 12 * s, 'brown')
            + circle(x, by - 130 * s + 8 * s, 70 * s, cd) + circle(x, by - 130 * s, 70 * s, c)
            + shine(x - 40 * s, by - 170 * s, 24 * s, 12 * s))


def star(x, y, r, c='yellow'):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.48
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
    return poly(pts, c)


def sparkle(x, y, r, c='yellow'):
    return path(f'M{x},{y - r} L{x + r * 0.3},{y - r * 0.3} L{x + r},{y} L{x + r * 0.3},{y + r * 0.3} '
                f'L{x},{y + r} L{x - r * 0.3},{y + r * 0.3} L{x - r},{y} L{x - r * 0.3},{y - r * 0.3} Z', c)


def wheel(x, y, r=34):
    return circle(x, y, r, 'ink') + circle(x, y, r * 0.45, 'gray')


def interior(wall='yellowPale', floor='brownLight', floord='brown'):
    """Cut-away room: back wall + floor inside a rounded tile."""
    return (rect(40, 60, 432, 380, 48, wall)
            + path('M40,330 L472,330 L472,392 Q472,440 424,440 L88,440 Q40,440 40,392 Z', floor)
            + rect(40, 330, 432, 14, 0, floord))


def wall_window(x, y, w=110, h=100):
    return (slab(x, y, w, h, 14, 'white', 'grayLight', 8) + rect(x + 12, y + 12, w - 24, h - 24, 8, 'blueSky')
            + rect(x + w / 2 - 5, y + 12, 10, h - 24, 0, 'white') + rect(x + 12, y + h / 2 - 5, w - 24, 10, 0, 'white'))


def bed_shape(x, y, s=1.0):
    return group(slab(0, 60, 300, 70, 18, 'blue', 'blueDark') + rect(0, 0, 40, 160, 16, 'brown')
                 + rect(260, 40, 40, 120, 16, 'brown') + slab(46, 34, 84, 40, 18, 'white', 'grayLight', 6)
                 + rect(130, 46, 136, 38, 16, 'blueSky') + rect(10, 150, 24, 20, 6, 'brownDark') + rect(266, 150, 24, 20, 6, 'brownDark'),
                 f'translate({x},{y}) scale({s})')


def sofa_shape(x, y, s=1.0, c='purple', cd='purpleDark'):
    return group(slab(20, 0, 300, 120, 40, c, cd) + slab(0, 70, 340, 90, 30, c, cd)
                 + slab(50, 70, 116, 56, 20, 'pink', cd, 6) + slab(174, 70, 116, 56, 20, 'pink', cd, 6)
                 + slab(-10, 50, 60, 120, 28, cd, cd, 0) + slab(290, 50, 60, 120, 28, cd, cd, 0)
                 + rect(20, 168, 24, 26, 8, 'brownDark') + rect(296, 168, 24, 26, 8, 'brownDark'),
                 f'translate({x},{y}) scale({s})')


def table_shape(x, y, s=1.0):
    return group(slab(0, 0, 300, 40, 16, 'brownLight', 'brown', 12) + rect(24, 50, 30, 150, 12, 'brown')
                 + rect(246, 50, 30, 150, 12, 'brown'), f'translate({x},{y}) scale({s})')


def chair_shape(x, y, s=1.0, c='orange', cd='orangeDark'):
    return group(slab(10, 0, 150, 150, 30, c, cd, 10) + slab(0, 150, 170, 44, 18, c, cd, 12)
                 + rect(14, 200, 26, 110, 12, cd) + rect(130, 200, 26, 110, 12, cd),
                 f'translate({x},{y}) scale({s})')


def facade(x, y, w, h, c, cd, r=16):
    return slab(x, y, w, h, r, c, cd)


def colour_swatch(c, cd, light):
    blob = ('M256,92 C330,80 352,140 400,150 C460,162 452,240 420,280 C392,316 430,370 376,404 '
            'C330,432 300,392 256,410 C200,432 150,420 128,380 C104,336 70,320 84,262 C96,210 70,170 120,130 '
            'C160,98 210,100 256,92 Z')
    drops = circle(436, 380, 22, c) + circle(92, 140, 16, c) + circle(410, 96, 12, c)
    return (shadow(256, 452, 150) + group(path(blob, cd), 'translate(0,14)') + path(blob, c) + drops
            + ellipse(196, 176, 46, 22, light, ' transform="rotate(-24 196 176)"') + circle(250, 150, 10, light))


# ---------------------------------------------------------------- home

@art('house')
def _():
    body = facade(120, 210, 272, 220, 'cream', 'tan')
    roof = poly([(96, 226), (256, 92), (416, 226)], 'red') + rect(316, 110, 40, 80, 8, 'redDark')
    door = rect(220, 330, 72, 100, 14, 'brown') + circle(276, 384, 7, 'yellow')
    return shadow(256, 448, 200) + body + roof + door + wall_window(140, 270, 64, 60) + wall_window(308, 270, 64, 60)


@art('room')
def _():
    frame = slab(196, 110, 120, 90, 10, 'yellow', 'yellowDark', 8) + rect(208, 122, 96, 66, 6, 'blueSky') + poly([(214, 182), (250, 140), (290, 182)], 'green') + circle(280, 142, 10, 'yellow')
    rug = ellipse(256, 392, 150, 30, 'red') + ellipse(256, 392, 110, 20, 'redPale')
    plant = rect(380, 270, 50, 64, 12, 'orange') + ellipse(405, 248, 30, 44, 'green') + ellipse(380, 240, 18, 34, 'greenDark', ' transform="rotate(-30 380 240)"')
    lamp = rect(96, 220, 12, 112, 6, 'grayDark') + path('M70,224 L134,224 L118,170 L86,170 Z', 'yellow') + ellipse(102, 334, 30, 8, 'grayDark')
    return interior('bluePale') + wall_window(60, 110, 100, 90) + frame + rug + plant + lamp


@art('kitchen')
def _():
    tiles = ''.join(rect(56 + i * 50, 76, 40, 40, 8, 'white') for i in range(8))
    counter = slab(56, 250, 400, 170, 20, 'white', 'grayLight') + rect(56, 238, 400, 26, 10, 'grayDark')
    oven = rect(176, 300, 160, 100, 16, 'ink') + rect(196, 318, 120, 64, 10, 'grayDark') + rect(196, 284, 120, 8, 4, 'gray')
    pot = slab(190, 160, 132, 74, 22, 'red', 'redDark', 8) + rect(176, 168, 160, 16, 8, 'redDark') + rect(240, 146, 32, 16, 8, 'redDark')
    steam = stroke('M222,136 Q210,116 222,96 M290,136 Q278,116 290,96', 'gray', 10)
    handles = rect(80, 290, 60, 10, 5, 'gray') + rect(372, 290, 60, 10, 5, 'gray')
    return rect(40, 60, 432, 380, 48, 'greenPale') + tiles + counter + oven + handles + pot + steam


@art('bedroom')
def _():
    night = slab(370, 262, 80, 80, 12, 'brownLight', 'brown', 8) + rect(394, 220, 32, 42, 6, 'yellow') + rect(404, 210, 12, 12, 4, 'grayDark')
    return interior('purple', 'brownLight', 'brown') + wall_window(196, 96, 120, 100) + star(110, 130, 22, 'yellowPale') + bed_shape(72, 214, 0.98) + night


@art('table')
def _():
    vase = rect(226, 120, 60, 80, 20, 'blue') + circle(240, 104, 22, 'red') + circle(274, 98, 22, 'yellow') + circle(258, 82, 20, 'pink')
    return shadow(256, 444, 190) + table_shape(106, 210, 1.0) + vase


@art('chair')
def _():
    return shadow(256, 450, 130) + chair_shape(170, 100, 1.04)


@art('bed')
def _():
    return shadow(256, 432, 200) + bed_shape(84, 200, 1.15)


@art('door')
def _():
    frame = slab(136, 50, 240, 400, 24, 'brownDark', 'navy', 0)
    door = rect(156, 70, 200, 380, 18, 'brownLight')
    panels = rect(186, 104, 140, 120, 14, 'brown') + rect(186, 260, 140, 150, 14, 'brown')
    knob = circle(320, 250, 18, 'yellow') + circle(316, 246, 6, 'white')
    return shadow(256, 456, 170) + frame + door + panels + knob


@art('window')
def _():
    frame = slab(96, 70, 320, 330, 26, 'white', 'grayLight')
    glass = rect(120, 94, 272, 282, 16, 'blueSky') + cloud(200, 180, 0.6) + circle(330, 150, 30, 'yellow')
    bars = rect(248, 94, 16, 282, 0, 'white') + rect(120, 228, 272, 16, 0, 'white')
    sill = slab(76, 396, 360, 30, 14, 'brownLight', 'brown', 8)
    curtains = path('M86,60 Q150,60 140,230 Q128,330 86,400 Z', 'red') + path('M426,60 Q362,60 372,230 Q384,330 426,400 Z', 'red')
    return shadow(256, 456, 190) + frame + glass + bars + curtains + sill


@art('lamp')
def _():
    base = slab(186, 400, 140, 30, 15, 'grayDark', 'ink', 8)
    pole = rect(248, 230, 16, 176, 8, 'grayDark')
    shade = path('M176,240 L336,240 L300,90 L212,90 Z', 'orangeDark') + path('M176,226 L336,226 L300,80 L212,80 Z', 'yellow')
    glow = path('M200,250 L312,250 L360,330 L152,330 Z', 'yellowPale')
    return shadow(256, 452, 130) + glow + base + pole + shade + shine(226, 110, 18, 60)


@art('sofa')
def _():
    return shadow(256, 444, 200) + sofa_shape(86, 200, 1.0)


@art('bathroom')
def _():
    shower = stroke('M380,320 L380,110 Q380,80 350,80 L320,80', 'grayDark', 14) + path('M290,80 L350,80 L340,110 L300,110 Z', 'gray')
    drops = ''.join(rect(304 + i * 14, 124 + (i % 2) * 18, 8, 24, 4, 'blue') for i in range(3))
    tub = path('M70,280 L442,280 L430,370 Q420,410 380,410 L132,410 Q92,410 82,370 Z', 'white')
    tub = path('M70,290 L442,290 L430,380 Q420,420 380,420 L132,420 Q92,420 82,380 Z', 'grayLight') + tub + rect(60, 268, 392, 28, 14, 'blueSky')
    bubbles = circle(150, 262, 30, 'white') + circle(196, 248, 36, 'white') + circle(246, 262, 26, 'white') + circle(200, 262, 30, 'bluePale')
    duck = circle(330, 246, 22, 'yellow') + ellipse(312, 270, 34, 18, 'yellow') + poly([(348, 246), (362, 250), (348, 254)], 'orange')
    feet = rect(110, 412, 30, 24, 8, 'grayDark') + rect(372, 412, 30, 24, 8, 'grayDark')
    tiles = ''.join(rect(56 + i * 52, 76, 42, 42, 8, 'white') for i in range(4))
    return rect(40, 60, 432, 380, 48, 'bluePale') + tiles + shower + drops + feet + tub + bubbles + duck


@art('apartment')
def _():
    body = facade(130, 70, 252, 370, 'orange', 'orangeDark')
    balconies = ''
    for row in range(4):
        y = 104 + row * 82
        balconies += windows(156, y, 3, 1, 52, 48, 26, 0, 'blueSky')
        balconies += rect(146, y + 46, 220, 12, 6, 'white')
    door = rect(226, 396, 60, 44, 8, 'brown')
    return shadow(256, 452, 170) + body + rect(118, 60, 276, 26, 13, 'orangeDark') + balconies + door


@art('garden')
def _():
    fence = ''.join(path(f'M{x},440 L{x},270 L{x + 18},248 L{x + 36},270 L{x + 36},440 Z', 'white') for x in range(56, 460, 56))
    fence += rect(48, 300, 416, 18, 6, 'grayLight') + rect(48, 380, 416, 18, 6, 'grayLight')
    grass = path('M40,400 Q256,370 472,400 L472,440 Q472,452 460,452 L52,452 Q40,452 40,440 Z', 'green')
    flowers = ''
    for x, c in [(100, 'red'), (180, 'yellow'), (256, 'pink'), (330, 'purple'), (410, 'orange')]:
        flowers += line(x, 410, x, 300, 'greenDark', 10) + ellipse(x + 18, 360, 18, 9, 'green')
        flowers += ''.join(circle(x + 22 * math.cos(a), 290 + 22 * math.sin(a), 16, c) for a in [i * math.pi * 2 / 5 for i in range(5)])
        flowers += circle(x, 290, 12, 'yellowPale' if c != 'yellow' else 'orange')
    sun = circle(400, 130, 46, 'yellow')
    return sun + tree(130, 300, 0.8) + fence + grass + flowers


# ---------------------------------------------------------------- school

def board(x, y, w, h):
    return (slab(x, y, w, h, 16, 'brown', 'brownDark', 10) + rect(x + 14, y + 14, w - 28, h - 28, 10, 'tealDark')
            + stroke(f'M{x + 40},{y + 50} L{x + 120},{y + 50} M{x + 40},{y + 84} L{x + 170},{y + 84}', 'white', 10))


def desk(x, y):
    return slab(x, y, 120, 26, 10, 'brownLight', 'brown', 8) + rect(x + 12, y + 30, 16, 60, 6, 'brown') + rect(x + 92, y + 30, 16, 60, 6, 'brown')


@art('classroom')
def _():
    clock = circle(400, 120, 34, 'white') + stroke('M400,120 L400,98 M400,120 L416,128', 'ink', 6)
    return (interior('yellowPale', 'brownLight', 'brown') + board(80, 90, 260, 150) + clock
            + desk(70, 300) + desk(196, 300) + desk(322, 300) + desk(130, 360) + desk(262, 360))


@art('class')
def _():
    kids = ''
    for cx, sk, hair, style, top, topd in [(130, 'skin', 'brownDark', 'short', 'blue', 'blueDark'),
                                           (256, 'skin2', 'black', 'pigtails', 'red', 'redDark'),
                                           (382, 'skin', 'brown', 'short', 'green', 'greenDark')]:
        p, _ = person(cx, 420, 0.72, skin=sk, hair=hair, style=style, top=top, topd=topd, child=True, arms='up')
        kids += p
    desks = slab(56, 344, 400, 40, 14, 'brownLight', 'brown', 10) + rect(80, 394, 22, 50, 8, 'brown') + rect(410, 394, 22, 50, 8, 'brown')
    books = rect(100, 326, 50, 18, 4, 'yellow') + rect(230, 326, 50, 18, 4, 'purple') + rect(356, 326, 50, 18, 4, 'orange')
    return shadow(256, 452, 210) + kids + desks + books


# ---------------------------------------------------------------- weather & seasons

@art('summer')
def _():
    rays = ''.join(line(256 + 150 * math.cos(a), 236 + 150 * math.sin(a), 256 + 200 * math.cos(a), 236 + 200 * math.sin(a), 'orange', 22)
                   for a in [i * math.pi / 4 for i in range(8)])
    sun = disc(256, 236, 124, 'yellow', 'orange', 10)
    glasses = rect(176, 200, 70, 52, 22, 'ink') + rect(266, 200, 70, 52, 22, 'ink') + rect(240, 210, 32, 12, 6, 'ink') + shine(188, 210, 22, 9) + shine(278, 210, 22, 9)
    smile = stroke('M210,296 Q256,330 302,296', 'orangeDark', 12)
    return rays + sun + glasses + smile


@art('winter')
def _():
    body = disc(256, 360, 96, 'white', 'grayLight', 10) + disc(256, 210, 70, 'white', 'grayLight', 8)
    hat = rect(206, 112, 100, 50, 14, 'blueDark') + rect(186, 150, 140, 18, 9, 'blue')
    scarf = rect(196, 262, 120, 30, 15, 'red') + rect(280, 270, 30, 70, 12, 'redDark')
    eyes = circle(232, 200, 9, 'ink') + circle(280, 200, 9, 'ink')
    nose = poly([(256, 216), (300, 226), (256, 236)], 'orange')
    buttons = circle(256, 330, 10, 'ink') + circle(256, 370, 10, 'ink')
    flakes = sparkle(96, 120, 22, 'blueSky') + sparkle(420, 90, 18, 'blueSky') + sparkle(430, 260, 14, 'blueSky') + sparkle(80, 300, 14, 'blueSky')
    arms = stroke('M170,330 L100,280 M342,330 L412,280', 'brown', 12)
    return shadow(256, 466, 160, 18) + flakes + arms + body + hat + scarf + eyes + nose + buttons


@art('spring')
def _():
    petals = ''
    for cx, cy, r, c in [(176, 190, 70, 'pink'), (346, 160, 52, 'redPale'), (340, 330, 44, 'pink')]:
        for i in range(5):
            a = -math.pi / 2 + i * 2 * math.pi / 5
            petals += circle(cx + r * 0.62 * math.cos(a), cy + r * 0.62 * math.sin(a), r * 0.5, c)
        petals += circle(cx, cy, r * 0.32, 'yellow')
    sprout = stroke('M150,440 L150,330', 'greenDark', 14) + path('M150,360 Q90,330 96,290 Q150,300 150,360 Z', 'green') + path('M150,340 Q210,300 216,262 Q160,276 150,340 Z', 'greenLight')
    ground = ellipse(170, 444, 120, 22, 'brownLight')
    butterfly = ellipse(428, 236, 22, 30, 'purple', ' transform="rotate(-20 428 236)"') + ellipse(458, 236, 22, 30, 'purple', ' transform="rotate(20 458 236)"') + rect(438, 214, 10, 46, 5, 'ink')
    return ground + sprout + petals + butterfly


@art('autumn')
def _():
    def leaf(x, y, s, rot, c, cd):
        d = ('M0,-110 L22,-60 L66,-80 L52,-30 L100,-20 L60,14 L76,50 L26,40 L10,90 L0,100 L-10,90 L-26,40 L-76,50 '
             'L-60,14 L-100,-20 L-52,-30 L-66,-80 L-22,-60 Z')
        return group(path(d, c) + stroke('M0,100 L0,-70 M0,10 L46,-30 M0,10 L-46,-30 M0,50 L36,30 M0,50 L-36,30', cd, 8)
                     + line(0, 100, 0, 140, cd, 10), f'translate({x},{y}) rotate({rot}) scale({s})')
    return (shadow(256, 450, 170) + leaf(190, 220, 1.3, -18, 'orange', 'orangeDark') + leaf(350, 290, 0.95, 24, 'red', 'redDark')
            + leaf(130, 380, 0.55, 40, 'yellow', 'yellowDark') + leaf(400, 120, 0.45, -40, 'brownLight', 'brown'))


@art('sky')
def _():
    sky = rect(40, 56, 432, 400, 70, 'blueSky')
    sun = circle(360, 150, 56, 'yellow')
    return sky + sun + cloud(190, 170, 1.1) + cloud(320, 330, 1.25) + stroke('M110,300 Q124,286 138,300 Q152,286 166,300', 'navy', 8)


@art('umbrella')
def _():
    canopy = path('M70,260 Q80,90 256,84 Q432,90 442,260 Q412,236 382,260 Q352,236 320,260 Q288,236 256,260 Q224,236 192,260 Q160,236 130,260 Q100,236 70,260 Z', 'blue')
    panels = path('M256,84 Q200,150 192,260 Q224,236 256,260 Q288,236 320,260 Q312,150 256,84 Z', 'blueSky')
    handle = stroke('M256,258 L256,400 Q256,440 294,440 Q330,440 330,404', 'brownDark', 18)
    top = rect(248, 62, 16, 30, 8, 'brownDark')
    drops = ''.join(path(f'M{x},{y} Q{x + 14},{y + 22} {x + 14},{y + 30} Q{x + 14},{y + 44} {x},{y + 44} Q{x - 14},{y + 44} {x - 14},{y + 30} Q{x - 14},{y + 22} {x},{y} Z', 'blue')
                    for x, y in [(80, 330), (430, 320), (120, 410), (400, 410)])
    return shadow(290, 456, 110, 16) + drops + top + canopy + panels + handle


@art('coat')
def _():
    body = path('M150,110 L210,90 Q256,140 302,90 L362,110 L430,230 L392,262 L362,214 L362,430 Q362,446 346,446 L166,446 Q150,446 150,430 L150,214 L120,262 L82,230 Z', 'brown')
    shade = path('M150,400 L362,400 L362,430 Q362,446 346,446 L166,446 Q150,446 150,430 Z', 'brownDark')
    lapels = poly([(210, 90), (256, 200), (226, 210), (190, 120)], 'brownDark') + poly([(302, 90), (256, 200), (286, 210), (322, 120)], 'brownDark')
    buttons = ''.join(circle(272, y, 10, 'yellow') for y in (250, 300, 350))
    pockets = rect(170, 330, 60, 14, 7, 'brownDark') + rect(300, 330, 46, 14, 7, 'brownDark')
    scarf = rect(210, 86, 92, 24, 12, 'red')
    return shadow(256, 456, 150) + body + shade + lapels + scarf + buttons + pockets


# ---------------------------------------------------------------- shopping

def awning(x, y, w, n, c1, c2, depth=56):
    out = ''
    sw = w / n
    for i in range(n):
        out += rect(x + i * sw, y, sw, depth, 0, c1 if i % 2 == 0 else c2)
        out += circle(x + i * sw + sw / 2, y + depth, sw / 2, c1 if i % 2 == 0 else c2)
    return rect(x - 6, y - 12, w + 12, 20, 10, 'redDark' if c1 == 'red' else 'greenDark') + out


@art('shop')
def _():
    body = facade(96, 130, 320, 300, 'cream', 'tan')
    sign = slab(150, 76, 212, 60, 16, 'blue', 'blueDark', 8) + rect(178, 98, 156, 14, 7, 'white')
    win = rect(120, 250, 150, 150, 14, 'blueSky') + rect(140, 330, 40, 50, 6, 'yellow') + rect(196, 310, 50, 70, 6, 'pink')
    door = rect(296, 250, 96, 180, 12, 'brown') + rect(310, 270, 68, 70, 8, 'blueSky') + circle(374, 360, 7, 'yellow')
    return shadow(256, 448, 200) + body + win + door + awning(96, 168, 320, 6, 'red', 'white') + sign


@art('market')
def _():
    stalls = ''
    for x, c1 in [(60, 'green'), (270, 'red')]:
        stalls += rect(x + 10, 200, 14, 220, 6, 'brown') + rect(x + 158, 200, 14, 220, 6, 'brown')
        stalls += awning(x, 130, 182, 4, c1, 'white', 46)
        stalls += slab(x, 320, 182, 60, 12, 'brownLight', 'brown', 10)
    produce = ''.join(circle(x, 304, 22, c) for x, c in [(96, 'red'), (140, 'red'), (184, 'orange'), (306, 'yellow'), (350, 'green'), (394, 'greenLight')])
    produce += ''.join(circle(x, 280, 22, c) for x, c in [(118, 'red'), (162, 'orange'), (328, 'yellow'), (372, 'green')])
    basket = slab(210, 380, 92, 56, 18, 'yellowDark', 'brown', 8) + circle(236, 372, 18, 'purple') + circle(272, 372, 18, 'red')
    return shadow(256, 452, 220) + stalls + produce + basket


@art('shirt')
def _():
    body = path('M150,110 L210,86 Q256,120 302,86 L362,110 L440,200 L392,250 L362,214 L362,430 Q362,446 346,446 L166,446 Q150,446 150,430 L150,214 L120,250 L72,200 Z', 'blue')
    shade = path('M150,404 L362,404 L362,430 Q362,446 346,446 L166,446 Q150,446 150,430 Z', 'blueDark')
    collar = poly([(210, 86), (256, 126), (230, 150)], 'white') + poly([(302, 86), (256, 126), (282, 150)], 'white')
    placket = rect(250, 130, 12, 274, 6, 'blueDark') + ''.join(circle(256, y, 8, 'white') for y in (180, 240, 300, 360))
    pocket = rect(286, 190, 50, 50, 10, 'blueSky')
    return shadow(256, 456, 150) + body + shade + collar + placket + pocket


@art('shoes')
def _():
    def shoe(x, y, c, cd):
        return group(path('M0,60 Q0,0 50,0 L90,0 Q110,40 160,50 Q220,60 220,100 L220,120 L0,120 Z', c)
                     + rect(-6, 106, 232, 26, 13, cd) + stroke('M60,30 L100,22 M66,54 L110,46', 'white', 9)
                     + shine(16, 20, 14, 30), f'translate({x},{y})')
    return shadow(256, 440, 200) + shoe(50, 230, 'red', 'redDark') + shoe(236, 280, 'red', 'redDark')


@art('dress')
def _():
    straps = line(214, 70, 222, 140, 'purpleDark', 14) + line(298, 70, 290, 140, 'purpleDark', 14)
    bodice = path('M206,140 L306,140 L300,230 L212,230 Z', 'purple')
    skirt = path('M212,226 L300,226 Q380,330 410,420 Q256,456 102,420 Q132,330 212,226 Z', 'purple')
    hem = path('M102,420 Q256,456 410,420 L414,436 Q256,474 98,436 Z', 'purpleDark')
    belt = rect(204, 220, 104, 22, 11, 'pink') + circle(256, 231, 14, 'yellow')
    dots = ''.join(circle(x, y, 9, 'pink') for x, y in [(190, 320), (256, 300), (322, 320), (160, 390), (256, 380), (352, 390)])
    return shadow(256, 460, 160) + straps + bodice + skirt + hem + dots + belt


@art('red')
def _():
    return colour_swatch('red', 'redDark', 'redPale')


@art('blue')
def _():
    return colour_swatch('blue', 'blueDark', 'blueSky')


@art('black')
def _():
    return colour_swatch('black', 'ink', 'grayDark')


@art('gift')
def _():
    box = slab(116, 210, 280, 220, 22, 'red', 'redDark')
    lid = slab(100, 170, 312, 70, 20, 'redDark', 'redDark', 0) + rect(100, 160, 312, 66, 20, 'red')
    ribbon = rect(236, 160, 40, 270, 6, 'yellow') + rect(100, 182, 312, 24, 0, 'yellow')
    bow = ellipse(206, 132, 56, 34, 'yellow', ' transform="rotate(-20 206 132)"') + ellipse(306, 132, 56, 34, 'yellow', ' transform="rotate(20 306 132)"') + circle(256, 150, 22, 'yellowDark')
    return shadow(256, 452, 170) + box + lid + ribbon + bow + shine(130, 260, 14, 50)


@art('wallet')
def _():
    cards = rect(150, 120, 200, 120, 16, 'blue', ' transform="rotate(-8 250 180)"') + rect(170, 110, 200, 120, 16, 'yellow', ' transform="rotate(6 270 170)"')
    body = slab(96, 170, 320, 230, 36, 'brown', 'brownDark')
    flap = path('M260,240 L416,240 L416,350 L260,350 Q232,350 232,322 L232,268 Q232,240 260,240 Z', 'brownDark')
    clasp = circle(290, 295, 18, 'yellow')
    stitch = stroke('M120,196 L392,196', 'brownLight', 6)
    money = rect(118, 150, 120, 70, 10, 'green')
    return shadow(256, 450, 180) + cards + money + body + stitch + flap + clasp


# ---------------------------------------------------------------- city

@art('street')
def _():
    road = path('M200,80 L312,80 L470,440 L42,440 Z', 'grayDark')
    side = path('M190,80 L200,80 L42,440 L20,440 Z', 'gray') + path('M322,80 L312,80 L470,440 L492,440 Z', 'gray')
    dashes = ''.join(path(f'M{256 - w / 2},{y} L{256 + w / 2},{y} L{256 + w / 2 + 2},{y + h} L{256 - w / 2 - 2},{y + h} Z', 'white')
                     for y, w, h in [(100, 8, 30), (160, 12, 44), (240, 18, 60), (340, 26, 80)])
    lamp = stroke('M430,330 L430,120 Q430,96 400,96', 'grayDark', 12) + ellipse(392, 104, 26, 14, 'yellow')
    sky = rect(40, 40, 432, 80, 40, 'bluePale')
    return sky + side + road + dashes + lamp + tree(80, 220, 0.6)


@art('bank')
def _():
    base = slab(90, 380, 332, 50, 12, 'grayLight', 'gray', 10)
    roof = poly([(90, 170), (256, 80), (422, 170)], 'blue') + rect(84, 170, 344, 34, 10, 'blueDark')
    cols = ''.join(rect(x, 210, 38, 170, 10, 'white') for x in (120, 196, 278, 354))
    coin = disc(256, 130, 34, 'yellow', 'yellowDark', 6) + rect(250, 106, 12, 48, 6, 'yellowDark')
    return shadow(256, 450, 200) + rect(100, 200, 312, 190, 0, 'bluePale') + cols + base + roof + coin


@art('hospital')
def _():
    body = facade(100, 120, 312, 310, 'bluePale', 'blueSky')
    sign = disc(256, 120, 58, 'red', 'redDark', 8) + rect(244, 84, 24, 72, 6, 'white') + rect(220, 108, 72, 24, 6, 'white')
    wins = windows(126, 200, 4, 2, 50, 46, 22, 24)
    door = rect(206, 340, 100, 90, 10, 'blueSky') + rect(252, 340, 8, 90, 0, 'white')
    return shadow(256, 448, 200) + body + rect(100, 300, 312, 14, 0, 'red') + wins + door + sign


@art('park')
def _():
    grass = ellipse(256, 410, 220, 50, 'green')
    bench = slab(150, 330, 220, 22, 8, 'brownLight', 'brown', 6) + slab(150, 290, 220, 20, 8, 'brownLight', 'brown', 6)
    bench += rect(166, 356, 14, 50, 6, 'grayDark') + rect(340, 356, 14, 50, 6, 'grayDark')
    flowers = circle(90, 400, 12, 'red') + circle(430, 404, 12, 'yellow') + circle(406, 420, 10, 'pink')
    return tree(120, 380, 1.15) + tree(392, 370, 0.9, 'greenLight', 'green') + grass + bench + flowers


@art('city')
def _():
    sky = rect(40, 60, 432, 380, 60, 'bluePale')
    blds = ''
    for x, w, h, c, cd in [(60, 90, 220, 'purple', 'purpleDark'), (150, 80, 300, 'blue', 'blueDark'), (230, 100, 190, 'orange', 'orangeDark'),
                           (330, 70, 260, 'teal', 'tealDark'), (400, 70, 160, 'red', 'redDark')]:
        blds += rect(x, 440 - h, w, h, 10, c) + rect(x, 440 - 20, w, 20, 0, cd)
        blds += windows(x + 14, 440 - h + 20, max(1, int((w - 14) // 30)), int((h - 50) // 40), 18, 22, 12, 18, 'yellowPale')
    return sky + cloud(130, 120, 0.6) + blds + rect(40, 420, 432, 20, 0, 'grayDark')


@art('map')
def _():
    sheet = poly([(60, 140), (180, 100), (330, 140), (452, 100), (452, 380), (330, 420), (180, 380), (60, 420)], 'greenPale')
    folds = poly([(180, 100), (330, 140), (330, 420), (180, 380)], 'greenLight')
    water = path('M60,300 Q120,280 160,320 Q190,350 180,380 L60,420 Z', 'blueSky')
    route = stroke('M110,200 Q200,180 230,260 Q260,330 350,300', 'red', 10).replace('stroke-linecap="round"', 'stroke-linecap="round" stroke-dasharray="4 24"')
    pin = path('M360,150 Q410,150 410,200 Q410,240 360,300 Q310,240 310,200 Q310,150 360,150 Z', 'red') + circle(360, 198, 18, 'white')
    return shadow(256, 450, 200) + sheet + folds + water + route + pin


@art('building')
def _():
    body = facade(150, 50, 212, 384, 'blue', 'blueDark')
    glass = windows(172, 80, 3, 7, 44, 32, 16, 14, 'blueSky')
    door = rect(220, 384, 72, 50, 8, 'navy')
    antenna = line(256, 50, 256, 20, 'grayDark', 8) + circle(256, 18, 8, 'red')
    return shadow(256, 452, 160) + antenna + body + glass + door


@art('bridge')
def _():
    water = path('M40,360 L472,360 L472,400 Q472,440 432,440 L80,440 Q40,440 40,400 Z', 'blue')
    waves = stroke('M90,400 Q110,388 130,400 M220,410 Q240,398 260,410 M350,398 Q370,386 390,398', 'blueSky', 8)
    deck = slab(30, 270, 452, 34, 10, 'red', 'redDark', 10)
    towers = rect(120, 120, 34, 240, 8, 'redDark') + rect(358, 120, 34, 240, 8, 'redDark')
    cable = stroke('M30,160 Q137,300 256,280 Q375,300 482,160', 'red', 10) + stroke('M137,124 Q256,300 375,124', 'red', 10)
    hangers = ''.join(line(x, 270, x, 270 - 60 + abs(x - 256) * 0.4, 'red', 5) for x in range(180, 340, 30))
    return water + waves + towers + cable + hangers + deck


# ---------------------------------------------------------------- travel

@art('plane')
def _():
    body = group(slab(-190, -42, 380, 84, 42, 'white', 'grayLight', 12)
                 + path('M120,-42 Q200,-42 200,0 Q200,4 190,6 L120,6 Z', 'blue')
                 + path('M-60,10 L60,10 L-40,150 L-90,150 Z', 'blue') + path('M-60,-30 L40,-30 L-50,-130 L-90,-130 Z', 'blueDark')
                 + path('M-190,-10 L-150,-10 L-170,-100 L-200,-100 Z', 'blue')
                 + ''.join(circle(x, -6, 12, 'blueSky') for x in range(-110, 110, 40)), 'translate(256,250) rotate(-12)')
    return cloud(110, 380, 0.7, 'bluePale', 'blueSky') + cloud(420, 120, 0.5, 'bluePale', 'blueSky') + body


@art('train')
def _():
    body = slab(100, 100, 312, 290, 50, 'red', 'redDark')
    front = rect(130, 130, 252, 110, 26, 'blueSky') + rect(250, 130, 12, 110, 0, 'red')
    lights = circle(160, 310, 22, 'yellow') + circle(352, 310, 22, 'yellow')
    grill = rect(206, 290, 100, 40, 12, 'redDark')
    stripe = rect(100, 260, 312, 14, 0, 'white')
    rails = line(120, 446, 392, 446, 'grayDark', 12) + line(150, 410, 120, 446, 'grayDark', 12) + line(362, 410, 392, 446, 'grayDark', 12)
    return rails + body + front + stripe + lights + grill + rect(186, 380, 30, 40, 8, 'ink') + rect(296, 380, 30, 40, 8, 'ink')


@art('bus')
def _():
    body = slab(56, 130, 400, 230, 40, 'yellow', 'yellowDark')
    wins = windows(80, 160, 4, 1, 70, 76, 16, 0, 'blueSky')
    stripe = rect(56, 270, 400, 18, 0, 'orange')
    door = rect(380, 250, 0, 0, 0, 'white')
    lights = circle(440, 316, 12, 'white') + rect(56, 316, 22, 20, 6, 'red')
    return shadow(256, 420, 200) + body + wins + stripe + lights + wheel(140, 368) + wheel(372, 368) + door


@art('taxi')
def _():
    sign = slab(206, 100, 100, 44, 12, 'yellowDark', 'brown', 6) + ''.join(rect(220 + i * 18, 114, 12, 12, 2, 'ink') for i in range(4))
    cabin = path('M140,250 L180,160 Q188,144 206,144 L306,144 Q324,144 332,160 L372,250 Z', 'yellow')
    glass = path('M172,240 L198,172 L250,172 L250,240 Z', 'blueSky') + path('M262,172 L314,172 L340,240 L262,240 Z', 'blueSky')
    body = slab(70, 236, 372, 110, 36, 'yellow', 'yellowDark')
    checks = ''.join(rect(90 + i * 34, 282, 17, 17, 0, 'ink' if i % 2 == 0 else 'yellow') for i in range(10))
    lights = rect(410, 266, 26, 22, 8, 'white') + rect(76, 266, 26, 22, 8, 'red')
    return shadow(256, 410, 200) + sign + cabin + glass + body + checks + lights + wheel(150, 356, 38) + wheel(362, 356, 38)


@art('ticket')
def _():
    t = ('M80,150 L432,150 L432,210 Q404,210 404,256 Q404,302 432,302 L432,362 L80,362 L80,302 Q108,302 108,256 '
         'Q108,210 80,210 Z')
    body = group(group(path(t, 'orangeDark'), 'translate(0,14)') + path(t, 'orange')
                 + stroke('M330,170 L330,342', 'yellowPale', 8).replace('stroke-linecap="round"', 'stroke-linecap="round" stroke-dasharray="2 22"')
                 + star(380, 256, 30, 'yellowPale') + rect(140, 206, 150, 22, 11, 'white') + rect(140, 246, 110, 18, 9, 'yellowPale')
                 + rect(140, 282, 130, 18, 9, 'yellowPale'), 'rotate(-10 256 256)')
    return shadow(256, 440, 180) + body


@art('airport')
def _():
    tower = rect(116, 170, 50, 260, 10, 'grayLight') + slab(80, 110, 122, 70, 20, 'blue', 'blueDark', 8) + rect(96, 126, 90, 30, 10, 'blueSky')
    terminal = facade(200, 300, 260, 130, 'white', 'grayLight') + rect(200, 300, 260, 30, 10, 'blue') + windows(220, 350, 5, 1, 32, 50, 16, 0)
    plane = group(rect(-110, -18, 220, 36, 18, 'white') + path('M-30,0 L40,0 L-20,70 L-50,70 Z', 'blue') + path('M-30,0 L40,0 L-20,-70 L-50,-70 Z', 'blueDark')
                  + path('M-110,-4 L-86,-4 L-100,-50 L-118,-50 Z', 'blue') + path('M110,-18 Q140,-18 140,0 Q140,18 110,18 Z', 'grayLight'), 'translate(340,150) rotate(-18)')
    return shadow(256, 448, 210) + tower + terminal + plane


@art('hotel')
def _():
    body = facade(120, 100, 272, 330, 'purple', 'purpleDark')
    sign = slab(186, 60, 140, 70, 16, 'red', 'redDark', 8) + rect(226, 76, 14, 40, 4, 'white') + rect(272, 76, 14, 40, 4, 'white') + rect(232, 90, 48, 12, 4, 'white')
    wins = windows(146, 160, 4, 4, 40, 34, 16, 18, 'yellowPale')
    door = rect(216, 360, 80, 70, 10, 'blueSky') + rect(200, 346, 112, 16, 8, 'red')
    return shadow(256, 448, 190) + body + wins + door + sign


@art('passport')
def _():
    book = slab(130, 70, 252, 360, 30, 'navy', 'black', 14)
    globe = circle(256, 220, 70, 'yellow') + circle(256, 220, 56, 'navy') + circle(256, 220, 46, 'yellow')
    lines = stroke('M210,220 L302,220 M256,174 Q226,220 256,266 Q286,220 256,174', 'navy', 7)
    title = rect(186, 320, 140, 18, 9, 'yellow') + rect(206, 356, 100, 14, 7, 'yellowDark')
    return shadow(256, 456, 150) + book + rect(130, 70, 30, 360, 14, 'black') + globe + lines + title


@art('suitcase')
def _():
    handle = f'<path d="M206,150 L206,104 Q206,86 224,86 L288,86 Q306,86 306,104 L306,150" fill="none" stroke="{C["grayDark"]}" stroke-width="22"/>'
    body = slab(116, 140, 280, 270, 40, 'orange', 'orangeDark')
    ribs = rect(186, 150, 18, 250, 9, 'orangeDark') + rect(308, 150, 18, 250, 9, 'orangeDark')
    stickers = circle(256, 230, 30, 'blue') + rect(222, 300, 70, 44, 10, 'green') + star(256, 230, 18, 'white')
    return shadow(256, 450, 160) + handle + body + ribs + stickers + wheel(160, 430, 18) + wheel(352, 430, 18)


@art('beach')
def _():
    sky = rect(40, 60, 432, 380, 60, 'bluePale')
    sea = rect(40, 250, 432, 90, 0, 'blue') + stroke('M70,290 Q90,278 110,290 M300,280 Q320,268 340,280', 'blueSky', 8)
    sand = path('M40,320 Q256,290 472,330 L472,392 Q472,440 424,440 L88,440 Q40,440 40,392 Z', 'tan')
    umb = line(330, 420, 330, 190, 'grayDark', 10) + path('M220,210 Q330,120 440,210 Z', 'red') + path('M300,210 Q330,140 360,210 Z', 'white')
    ball = circle(150, 390, 34, 'white') + path('M116,390 A34,34 0 0 1 150,356 L150,390 Z', 'blue') + path('M184,390 A34,34 0 0 1 150,424 L150,390 Z', 'yellow')
    sun = circle(120, 140, 44, 'yellow')
    return sky + sun + sea + sand + umb + ball


@art('mountain')
def _():
    back = poly([(220, 420), (360, 150), (480, 420)], 'blueDark')
    front = poly([(40, 420), (200, 100), (360, 420)], 'blue')
    snow = path('M200,96 L248,190 L222,176 L200,200 L176,176 L152,190 Z', 'white') + path('M360,146 L392,210 L372,200 L360,216 L346,200 L328,210 Z', 'white')
    ground = rect(40, 410, 432, 30, 15, 'green')
    sun = circle(400, 110, 40, 'yellow')
    return sun + back + front + snow + ground


@art('sea')
def _():
    sky = rect(40, 60, 432, 380, 60, 'bluePale')
    waves = ''
    for i, (c, y) in enumerate([('blueSky', 220), ('blue', 290), ('blueDark', 360)]):
        d = f'M40,{y}' + ''.join(f' Q{40 + 54 * (2 * k + 1)},{y - 36} {40 + 108 * (k + 1)},{y}' for k in range(4))
        d += f' L472,{min(y + 200, 440)} L40,{min(y + 200, 440)} Z'
        waves += path(d, c)
    boat = path('M300,170 L420,170 L400,200 L320,200 Z', 'red') + poly([(360, 166), (360, 100), (406, 160)], 'white')
    gull = stroke('M120,130 Q136,114 152,130 Q168,114 184,130', 'navy', 8)
    tile = f'<clipPath id="c"><rect x="40" y="60" width="432" height="380" rx="60"/></clipPath>'
    return tile + f'<g clip-path="url(#c)">{sky}{boat}{waves}</g>' + gull


@art('island')
def _():
    sea = ellipse(256, 400, 220, 52, 'blue') + stroke('M70,404 Q90,392 110,404 M402,410 Q422,398 442,410', 'blueSky', 8)
    sand = ellipse(256, 380, 150, 46, 'tan')
    trunk = stroke('M250,380 Q240,280 280,190', 'brown', 24)
    leaves = ''.join(path(f'M280,190 Q{280 + 120 * math.cos(a)},{190 + 60 * math.sin(a) - 40} {280 + 150 * math.cos(a)},{190 + 110 * math.sin(a) + 20} Q{280 + 70 * math.cos(a)},{190 + 20} 280,190 Z', 'green')
                     for a in [math.pi * 1.05, math.pi * 1.35, math.pi * 1.65, math.pi * 1.95])
    nuts = circle(268, 204, 14, 'brownDark') + circle(292, 208, 14, 'brownDark')
    sun = circle(110, 120, 40, 'yellow')
    return sun + sea + sand + trunk + leaves + nuts


# ---------------------------------------------------------------- work

def monitor(x, y, s=1.0):
    return group(slab(0, 0, 240, 160, 18, 'ink', 'black', 10) + rect(14, 14, 212, 124, 10, 'blue')
                 + rect(34, 36, 110, 14, 7, 'white') + rect(34, 64, 160, 12, 6, 'blueSky') + rect(34, 88, 130, 12, 6, 'blueSky')
                 + rect(104, 170, 32, 40, 6, 'grayDark') + rect(70, 206, 100, 18, 9, 'grayDark'), f'translate({x},{y}) scale({s})')


@art('computer')
def _():
    keyboard = slab(130, 380, 252, 40, 12, 'grayLight', 'gray', 8) + ''.join(rect(146 + i * 30, 390, 22, 8, 3, 'gray') for i in range(8))
    mouse = ellipse(420, 396, 22, 30, 'grayLight')
    return shadow(256, 444, 200) + monitor(136, 110, 1.0) + keyboard + mouse


@art('office')
def _():
    deskt = slab(60, 300, 392, 34, 12, 'brownLight', 'brown', 10) + rect(80, 340, 26, 100, 8, 'brown') + rect(406, 340, 26, 100, 8, 'brown')
    drawer = rect(300, 340, 120, 80, 10, 'brownLight') + rect(340, 364, 40, 10, 5, 'brown')
    laptop = path('M150,200 L290,200 L280,290 L160,290 Z', 'grayDark') + rect(166, 212, 108, 66, 6, 'blueSky') + rect(130, 288, 180, 14, 7, 'gray')
    mug = rect(330, 246, 40, 50, 10, 'red') + stroke('M370,260 Q388,264 370,284', 'red', 8)
    papers = rect(380, 270, 56, 30, 4, 'white')
    plant = rect(84, 250, 46, 50, 10, 'orange') + ellipse(107, 226, 26, 36, 'green')
    return interior('bluePale', 'gray', 'grayDark') + wall_window(300, 90, 130, 110) + slab(80, 90, 150, 90, 12, 'white', 'grayLight', 6) + rect(100, 110, 60, 10, 5, 'blue') + rect(100, 136, 100, 10, 5, 'gray') + deskt + drawer + laptop + mug + papers + plant


# ---------------------------------------------------------------- hobbies

@art('movie')
def _():
    board = slab(100, 210, 312, 200, 22, 'ink', 'black', 12) + rect(124, 250, 264, 18, 9, 'grayDark') + rect(124, 290, 200, 18, 9, 'grayDark')
    top = group(rect(0, 0, 312, 56, 12, 'white') + ''.join(poly([(20 + i * 70, 0), (54 + i * 70, 0), (34 + i * 70, 56), (0 + i * 70, 56)], 'ink') for i in range(5)),
                'translate(100,150) rotate(-12 0 56)')
    popcorn = path('M370,250 L450,250 L436,400 L384,400 Z', 'red') + rect(396, 250, 12, 150, 0, 'white') + rect(420, 250, 12, 150, 0, 'white')
    popcorn += ''.join(circle(x, 240, 20, 'yellowPale') for x in (380, 410, 440)) + circle(396, 220, 18, 'yellowPale') + circle(426, 222, 18, 'yellowPale')
    return shadow(256, 444, 200) + board + top + popcorn


@art('game')
def _():
    pad = path('M120,190 Q256,170 392,190 Q460,200 470,300 Q476,380 420,390 Q380,396 350,340 L162,340 Q132,396 92,390 Q36,380 42,300 Q52,200 120,190 Z', 'purpleDark')
    pad2 = path('M120,180 Q256,160 392,180 Q460,190 470,290 Q476,370 420,380 Q380,386 350,330 L162,330 Q132,386 92,380 Q36,370 42,290 Q52,190 120,180 Z', 'purple')
    dpad = rect(104, 252, 80, 26, 8, 'ink') + rect(131, 225, 26, 80, 8, 'ink')
    btns = circle(360, 236, 18, 'green') + circle(396, 266, 18, 'red') + circle(324, 266, 18, 'blue') + circle(360, 296, 18, 'yellow')
    mid = rect(226, 230, 26, 12, 6, 'white') + rect(262, 230, 26, 12, 6, 'white')
    return shadow(256, 430, 200) + pad + pad2 + dpad + btns + mid


@art('sport')
def _():
    basket = disc(190, 290, 110, 'orange', 'orangeDark', 10) + stroke('M80,290 L300,290 M190,180 L190,400 M112,212 Q170,290 112,368 M268,212 Q210,290 268,368', 'orangeDark', 9)
    tennis = disc(380, 360, 60, 'greenLight', 'green', 8) + stroke('M330,330 Q380,360 330,400 M430,320 Q380,360 432,392', 'white', 8)
    racket = group(f'<ellipse cx="0" cy="-70" rx="50" ry="64" fill="none" stroke="{C["red"]}" stroke-width="16"/>'
                   + line(0, 0, 0, 90, 'redDark', 22), 'translate(390,180) rotate(30)')
    return shadow(256, 444, 210) + racket + basket + tennis


@art('football')
def _():
    ball = circle(256, 264, 172, 'grayLight') + circle(256, 250, 170, 'white')

    def pent(x, y, r, rot=0.0):
        return poly([(x + r * math.cos(rot - math.pi / 2 + i * 2 * math.pi / 5), y + r * math.sin(rot - math.pi / 2 + i * 2 * math.pi / 5)) for i in range(5)], 'ink')
    patches = pent(256, 250, 50)
    for i in range(5):
        a = -math.pi / 2 + i * 2 * math.pi / 5
        patches += line(256 + 50 * math.cos(a), 250 + 50 * math.sin(a), 256 + 118 * math.cos(a), 250 + 118 * math.sin(a), 'gray', 7)
        patches += pent(256 + 162 * math.cos(a), 250 + 162 * math.sin(a), 44, math.pi)
    clip = '<clipPath id="ball"><circle cx="256" cy="250" r="170"/></clipPath>'
    return shadow(256, 450, 150) + ball + clip + f'<g clip-path="url(#ball)">{patches}</g>' + shine(160, 150, 46, 16)


@art('guitar')
def _():
    g = group(rect(-18, -230, 36, 220, 10, 'brownDark') + rect(-30, -280, 60, 70, 18, 'brownDark')
              + ''.join(circle(k * 40, -270 + j * 26, 9, 'grayLight') for k in (-1, 1) for j in range(2))
              + circle(0, 60, 108, 'orangeDark') + circle(0, -50, 82, 'orangeDark')
              + circle(0, 50, 102, 'orange') + circle(0, -56, 76, 'orange')
              + circle(0, -20, 30, 'brownDark') + rect(-46, 76, 92, 20, 8, 'brownDark')
              + ''.join(line(x, -270, x, 86, 'white', 3) for x in (-12, -4, 4, 12)), 'translate(256,300) rotate(24)')
    return shadow(256, 456, 140) + g


@art('piano')
def _():
    body = slab(70, 110, 372, 250, 30, 'ink', 'black', 12)
    keys = rect(92, 230, 328, 120, 10, 'white')
    keys += ''.join(rect(92 + i * 41, 230, 3, 120, 0, 'grayLight') for i in range(1, 8))
    keys += ''.join(rect(92 + i * 41 - 14, 230, 26, 72, 6, 'ink') for i in (1, 2, 4, 5, 6))
    legs = rect(100, 370, 26, 70, 8, 'black') + rect(386, 370, 26, 70, 8, 'black')
    notes = stroke('M200,140 L200,90 L250,80 L250,130', 'yellow', 10) + circle(190, 142, 14, 'yellow') + circle(240, 132, 14, 'yellow')
    return shadow(256, 450, 200) + legs + body + keys + notes


@art('camera')
def _():
    body = slab(70, 150, 372, 250, 40, 'grayDark', 'ink')
    top = rect(150, 112, 110, 60, 14, 'grayDark') + rect(330, 124, 60, 30, 10, 'red')
    lens = disc(256, 280, 96, 'ink', 'black', 6) + circle(256, 280, 70, 'blueDark') + circle(256, 280, 44, 'blue') + shine(226, 248, 26, 12)
    band = rect(70, 230, 372, 20, 0, 'gray')
    flash = rect(96, 180, 50, 30, 8, 'yellowPale')
    return shadow(256, 450, 200) + top + body + band + lens + flash


@art('photo')
def _():
    back = group(slab(0, 0, 260, 300, 16, 'white', 'grayLight', 10) + rect(20, 20, 220, 200, 8, 'pink'), 'translate(90,90) rotate(-10)')
    front = group(slab(0, 0, 270, 310, 16, 'white', 'grayLight', 10) + rect(20, 20, 230, 210, 8, 'blueSky')
                  + poly([(30, 220), (110, 110), (190, 220)], 'green') + poly([(130, 220), (190, 140), (240, 220)], 'greenDark')
                  + circle(196, 70, 24, 'yellow') + rect(30, 250, 140, 16, 8, 'grayLight'), 'translate(170,110) rotate(8)')
    return shadow(256, 456, 190) + back + front


# ---------------------------------------------------------------- health

@art('pharmacy')
def _():
    body = facade(100, 170, 312, 260, 'cream', 'tan')
    awn = awning(100, 200, 312, 6, 'green', 'white', 44)
    sign = disc(256, 120, 60, 'green', 'greenDark', 8) + rect(242, 80, 28, 80, 6, 'white') + rect(216, 106, 80, 28, 6, 'white')
    win = rect(126, 300, 120, 110, 12, 'blueSky') + slab(150, 340, 30, 50, 8, 'orange', 'orangeDark', 4) + slab(194, 350, 34, 40, 10, 'red', 'redDark', 4)
    door = rect(280, 300, 100, 130, 10, 'greenPale') + circle(364, 370, 7, 'greenDark')
    return shadow(256, 448, 200) + body + win + door + awn + sign


@art('vegetable')
def _():
    carrot = group(path('M-40,0 Q0,-20 40,0 L6,230 Q0,244 -6,230 Z', 'orange')
                   + stroke('M-26,50 L-6,54 M14,100 L-6,104 M-14,150 L4,152', 'orangeDark', 7)
                   + path('M0,0 Q-50,-80 -30,-110 Q0,-60 0,0 Z', 'green') + path('M0,0 Q50,-90 30,-120 Q4,-60 0,0 Z', 'greenDark'),
                   'translate(330,170) rotate(28)')
    broccoli = (rect(150, 270, 40, 150, 16, 'greenLight') + circle(120, 250, 50, 'greenDark') + circle(220, 250, 50, 'greenDark')
                + circle(170, 200, 60, 'green') + circle(120, 240, 44, 'green') + circle(222, 240, 44, 'green'))
    tomato = disc(270, 380, 52, 'red', 'redDark', 8) + path('M250,334 L270,346 L290,334 L282,354 L258,354 Z', 'green')
    return shadow(256, 448, 200) + carrot + broccoli + tomato


@art('fruit')
def _():
    grapes = ''.join(circle(x, y, 26, 'purpleDark') for x, y in [(130, 180), (180, 180), (230, 180), (155, 222), (205, 222), (180, 264)])
    grapes += ''.join(circle(x - 4, y - 4, 22, 'purple') for x, y in [(130, 180), (180, 180), (230, 180), (155, 222), (205, 222), (180, 264)])
    grapes += stroke('M180,154 Q186,120 210,110', 'brown', 10)
    banana = path('M260,140 Q300,150 330,250 Q350,330 440,370 Q430,390 400,390 Q300,380 270,280 Q248,200 260,140 Z', 'yellow')
    banana += path('M262,140 Q258,128 268,126 L276,142 Z', 'brownDark') + stroke('M286,190 Q300,300 380,360', 'yellowDark', 8)
    orange = disc(170, 370, 64, 'orange', 'orangeDark', 8) + path('M170,306 Q196,284 214,300 Q190,314 170,306 Z', 'green') + shine(132, 340, 22, 10)
    return shadow(256, 450, 200) + grapes + banana + orange


# ---------------------------------------------------------------- celebrations & plans

@art('party')
def _():
    popper = poly([(120, 430), (210, 220), (300, 330)], 'purple') + stroke('M150,360 L250,300 M180,300 L240,260', 'yellow', 10)
    confetti = ''.join(rect(x, y, 18, 10, 4, c, f' transform="rotate({r} {x} {y})"') for x, y, c, r in
                       [(260, 180, 'red', 20), (320, 130, 'yellow', -30), (380, 200, 'blue', 40), (300, 240, 'green', 10), (420, 280, 'pink', -20), (240, 110, 'orange', 50)])
    streamer = stroke('M230,220 Q260,150 320,170 Q380,190 400,120', 'teal', 9)
    balloons = (line(380, 330, 400, 440, 'grayDark', 4) + ellipse(380, 290, 46, 56, 'red') + shine(356, 262, 12, 24)
                + line(440, 290, 420, 440, 'grayDark', 4) + ellipse(446, 250, 40, 50, 'blue'))
    return shadow(256, 452, 190) + balloons + streamer + confetti + popper


@art('birthday')
def _():
    plate = ellipse(256, 420, 190, 30, 'grayLight')
    cake = slab(100, 290, 312, 120, 22, 'pink', 'purpleDark') + slab(136, 200, 240, 96, 20, 'cream', 'tan', 10)
    icing = path('M100,300 Q130,330 160,300 Q190,330 220,300 Q250,330 280,300 Q310,330 340,300 Q370,330 412,300 L412,300 L100,300 Z', 'white')
    icing += path('M136,210 Q166,236 196,210 Q226,236 256,210 Q286,236 316,210 Q346,236 376,210 Z', 'pink')
    candles = ''.join(rect(x, 130, 18, 74, 8, c) + path(f'M{x + 9},{92} Q{x + 26},{116} {x + 9},{128} Q{x - 8},{116} {x + 9},{92} Z', 'orange') + circle(x + 9, 116, 6, 'yellow')
                      for x, c in [(186, 'blue'), (247, 'green'), (308, 'purple')])
    sprinkles = ''.join(rect(x, y, 16, 8, 4, c) for x, y, c in [(150, 350, 'yellow'), (220, 370, 'blue'), (300, 350, 'green'), (360, 372, 'yellow')])
    return shadow(256, 444, 200) + plate + cake + icing + candles + sprinkles


@art('concert')
def _():
    stage = rect(40, 60, 432, 380, 60, 'navy')
    beams = path('M110,60 L190,60 L300,360 L120,360 Z', 'purpleDark') + path('M330,60 L410,60 L400,360 L230,360 Z', 'blueDark')
    floor = path('M40,340 L472,340 L472,392 Q472,440 424,440 L88,440 Q40,440 40,392 Z', 'purple')
    mic = rect(250, 210, 12, 140, 6, 'gray') + slab(234, 160, 44, 64, 22, 'grayDark', 'ink', 6) + ellipse(256, 350, 40, 10, 'gray')
    notes = (stroke('M110,170 L110,120 L150,110 L150,160', 'yellow', 9) + circle(100, 172, 13, 'yellow') + circle(140, 162, 13, 'yellow')
             + stroke('M390,220 L390,170', 'pink', 9) + circle(380, 222, 13, 'pink') + path('M390,170 Q410,180 404,200', 'none', f' stroke="{C["pink"]}" stroke-width="9"'))
    crowd = ''.join(circle(x, 420, 26, 'black') for x in (100, 170, 240, 310, 380, 440))
    clip = '<clipPath id="stage"><rect x="40" y="60" width="432" height="380" rx="60"/></clipPath>'
    return clip + f'<g clip-path="url(#stage)">{stage}{beams}{floor}{mic}{notes}{crowd}</g>'


@art('museum')
def _():
    steps = slab(76, 392, 360, 22, 6, 'grayLight', 'gray', 6) + slab(96, 370, 320, 22, 6, 'grayLight', 'gray', 6)
    roof = poly([(84, 170), (256, 76), (428, 170)], 'purple') + rect(80, 168, 352, 30, 8, 'purpleDark')
    cols = ''.join(rect(x, 206, 30, 164, 6, 'cream') + rect(x - 6, 200, 42, 14, 4, 'tan') for x in (114, 180, 302, 368))
    art_ = slab(212, 220, 88, 100, 10, 'yellow', 'yellowDark', 6) + rect(222, 230, 68, 80, 6, 'blueSky') + circle(256, 270, 20, 'pink')
    emblem = circle(256, 138, 22, 'yellowPale')
    return shadow(256, 444, 200) + rect(104, 200, 304, 170, 0, 'purple') + art_ + cols + steps + roof + emblem


@art('festival')
def _():
    sky = rect(40, 60, 432, 380, 60, 'navy')
    rope = stroke('M40,150 Q256,240 472,150', 'yellowDark', 6)

    def lantern(x, y, c, cd):
        return (line(x, y - 40, x, y - 20, 'yellowDark', 5) + rect(x - 22, y - 26, 44, 12, 4, 'yellowDark')
                + ellipse(x, y + 20, 38, 46, c) + stroke(f'M{x},{y - 22} L{x},{y + 62}', cd, 5) + rect(x - 22, y + 58, 44, 12, 4, 'yellowDark')
                + line(x, y + 70, x, y + 96, 'yellow', 6))
    lanterns = lantern(120, 210, 'red', 'redDark') + lantern(256, 240, 'yellow', 'orange') + lantern(392, 210, 'red', 'redDark')
    fw = ''
    for cx, cy, c in [(140, 340, 'pink'), (370, 350, 'blueSky')]:
        fw += ''.join(line(cx + 20 * math.cos(a), cy + 20 * math.sin(a), cx + 56 * math.cos(a), cy + 56 * math.sin(a), c, 8) for a in [i * math.pi / 5 for i in range(10)])
    stars = sparkle(256, 110, 14, 'yellowPale') + sparkle(420, 100, 10, 'yellowPale') + sparkle(90, 100, 10, 'yellowPale')
    return sky + stars + fw + rope + lanterns


@art('picnic')
def _():
    blanket = poly([(70, 330), (442, 330), (480, 440), (32, 440)], 'red')
    checks = ''.join(poly([(70 + i * 62 + (j * 10), 330 + j * 37), (101 + i * 62 + (j * 10), 330 + j * 37), (104 + i * 62 + ((j + 1) * 10), 367 + j * 37), (73 + i * 62 + ((j + 1) * 10), 367 + j * 37)], 'white')
                     for i in range(6) for j in range(3) if (i + j) % 2 == 0)
    basket = slab(180, 230, 152, 110, 22, 'brownLight', 'brown', 10) + stroke('M196,240 Q256,130 316,240', 'brown', 14)
    basket += stroke('M196,270 L316,270 M196,300 L316,300', 'brown', 6)
    apple = circle(370, 330, 26, 'red') + line(370, 304, 374, 290, 'brownDark', 6)
    sandwich = poly([(100, 330), (160, 290), (170, 336)], 'tan') + poly([(104, 322), (160, 286), (166, 320)], 'greenLight')
    return tree(400, 300, 0.9) + shadow(256, 446, 230, 14) + blanket + checks + basket + apple + sandwich
