"""Drawing kit for the v2 lesson word illustrations (imageChoice art).

Flat, friendly shapes on a 512x512 canvas: thick rounded forms, a darker
"lip" under each solid shape instead of outlines, a soft ground shadow, and a
transparent background. Every colour comes from PALETTE, whose values are
sampled from the design references (docs/design/qa/palette_from_refs.json,
G-COLOR); `tools/palette_check.py --lesson-art` re-checks the SVG sources.
"""

PALETTE = {
    'green': '#58CC02', 'greenDark': '#58A700', 'greenLight': '#89E219', 'greenPale': '#D7FFB8',
    'blue': '#1CB0F6', 'blueDark': '#1899D6', 'bluePale': '#DDF4FF', 'blueSky': '#84D8FF',
    'red': '#FF4B4B', 'redDark': '#EA2B2B', 'redPale': '#FFDFE0',
    'yellow': '#FFC800', 'yellowDark': '#E6A000', 'yellowPale': '#FEF4B2',
    'orange': '#FF9600', 'orangeDark': '#CD7900',
    'purple': '#CE82FF', 'purpleDark': '#B056F0', 'pink': '#FF86CD',
    'brown': '#A76742', 'brownDark': '#633D29', 'brownLight': '#E59D65', 'tan': '#F7D3AD',
    'skin': '#FFC6BA', 'skinDark': '#F09686', 'skin2': '#E89D67',
    'ink': '#4B4B4B', 'gray': '#AFAFAF', 'grayLight': '#E5E5E5', 'grayDark': '#777777',
    'white': '#FFFFFF', 'black': '#2B2B2B', 'teal': '#02CEA0', 'tealDark': '#02A47F',
    'navy': '#19343B', 'cream': '#FFF9E6',
}
C = PALETTE


def _f(c):
    return C.get(c, c)


def rect(x, y, w, h, r=0, c='white', extra=''):
    return f'<rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}" rx="{r:g}" fill="{_f(c)}"{extra}/>'


def circle(cx, cy, r, c='white'):
    return f'<circle cx="{cx:g}" cy="{cy:g}" r="{r:g}" fill="{_f(c)}"/>'


def ellipse(cx, cy, rx, ry, c='white', extra=''):
    return f'<ellipse cx="{cx:g}" cy="{cy:g}" rx="{rx:g}" ry="{ry:g}" fill="{_f(c)}"{extra}/>'


def path(d, c='white', extra=''):
    return f'<path d="{d}" fill="{_f(c)}"{extra}/>'


def poly(points, c='white'):
    pts = ' '.join(f'{x:g},{y:g}' for x, y in points)
    return f'<polygon points="{pts}" fill="{_f(c)}" stroke="{_f(c)}" stroke-width="10" stroke-linejoin="round"/>'


def line(x1, y1, x2, y2, c='ink', w=14):
    return (f'<line x1="{x1:g}" y1="{y1:g}" x2="{x2:g}" y2="{y2:g}" stroke="{_f(c)}" '
            f'stroke-width="{w:g}" stroke-linecap="round"/>')


def stroke(d, c='ink', w=14):
    return (f'<path d="{d}" fill="none" stroke="{_f(c)}" stroke-width="{w:g}" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')


def slab(x, y, w, h, r, c, cd, d=14):
    """A rounded block with a darker lip underneath (the 3D-button look)."""
    return rect(x, y + d, w, h, r, cd) + rect(x, y, w, h, r, c)


def disc(cx, cy, r, c, cd, d=12):
    return circle(cx, cy + d, r, cd) + circle(cx, cy, r, c)


def shine(x, y, w=26, h=12):
    """Small white highlight pill (top-left of glossy shapes)."""
    return rect(x, y, w, h, h / 2, 'white')


def shadow(cx=256, cy=452, rx=170, ry=22):
    return ellipse(cx, cy, rx, ry, 'grayLight')


def group(body, transform):
    return f'<g transform="{transform}">{body}</g>'


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
            f'viewBox="0 0 512 512">{body}</svg>\n')


# ---------------------------------------------------------------- people

def face(cx, cy, r, mood='smile', glasses=False, cheeks=True):
    s = ''
    ex = r * 0.36
    ey = cy - r * 0.02
    for k in (-1, 1):
        s += ellipse(cx + k * ex, ey, r * 0.1, r * 0.14, 'ink')
        s += circle(cx + k * ex + r * 0.035, ey - r * 0.05, r * 0.035, 'white')
    if cheeks:
        for k in (-1, 1):
            s += ellipse(cx + k * r * 0.58, cy + r * 0.26, r * 0.13, r * 0.08, 'skinDark')
    if mood == 'smile':
        s += stroke(f'M{cx - r * 0.24:g},{cy + r * 0.3:g} Q{cx:g},{cy + r * 0.52:g} {cx + r * 0.24:g},{cy + r * 0.3:g}',
                    'ink', max(4, r * 0.08))
    elif mood == 'open':
        s += path(f'M{cx - r * 0.26:g},{cy + r * 0.26:g} Q{cx:g},{cy + r * 0.72:g} {cx + r * 0.26:g},{cy + r * 0.26:g} Z', 'redDark')
    if glasses:
        for k in (-1, 1):
            s += (f'<circle cx="{cx + k * ex:g}" cy="{ey:g}" r="{r * 0.22:g}" fill="none" '
                  f'stroke="{C["ink"]}" stroke-width="{max(4, r * 0.07):g}"/>')
        s += line(cx - ex + r * 0.22, ey, cx + ex - r * 0.22, ey, 'ink', max(4, r * 0.07))
    return s


def person(cx, by, s=1.0, skin='skin', hair='brownDark', style='short', top='blue', topd='blueDark',
           legs='navy', mood='smile', glasses=False, beard=None, extra_top='', child=False, arms='down'):
    """Standing figure; feet at y=by, roughly 330*s tall (child ~0.8)."""
    k = s * (0.82 if child else 1.0)
    head_r = 62 * s
    body_w, body_h = 132 * k, 120 * k
    leg_h = 70 * k
    top_y = by - leg_h - body_h
    hy = top_y - head_r * 0.82
    out = ''
    # legs + shoes
    for d in (-1, 1):
        out += rect(cx + d * 26 * k - 18 * k, by - leg_h - 10, 36 * k, leg_h + 10, 14 * k, legs)
        out += rect(cx + d * 26 * k - 24 * k, by - 18 * k, 48 * k, 22 * k, 11 * k, 'ink')
    # arms
    for d in (-1, 1):
        ax = cx + d * (body_w / 2 + 4 * k)
        if arms == 'up' and d == 1:
            out += line(ax, top_y + 30 * k, ax + 30 * k, top_y - 50 * k, topd, 30 * k)
            out += circle(ax + 30 * k, top_y - 58 * k, 17 * k, skin)
        else:
            out += line(ax, top_y + 30 * k, ax + d * 10 * k, top_y + body_h - 10 * k, topd, 30 * k)
            out += circle(ax + d * 10 * k, top_y + body_h, 17 * k, skin)
    # torso
    out += rect(cx - body_w / 2, top_y, body_w, body_h, 42 * k, top)
    out += rect(cx - body_w / 2, top_y + body_h - 22 * k, body_w, 22 * k, 11 * k, topd)
    out += extra_top
    # neck + head
    out += rect(cx - 16 * s, top_y - 18 * s, 32 * s, 30 * s, 10 * s, 'skinDark' if skin == 'skin' else skin)
    if style in ('long', 'bun_long'):
        out += rect(cx - head_r * 1.1, hy - head_r * 0.6, head_r * 2.2, head_r * 2.0, head_r * 0.7, hair)
    if style == 'pigtails':
        for d in (-1, 1):
            out += circle(cx + d * head_r * 1.05, hy + head_r * 0.15, head_r * 0.38, hair)
    for d in (-1, 1):
        out += circle(cx + d * head_r * 0.95, hy + head_r * 0.08, head_r * 0.2, skin)
    out += circle(cx, hy, head_r, skin)
    # hair caps
    if style == 'short':
        out += path(f'M{cx - head_r:g},{hy:g} A{head_r:g},{head_r:g} 0 0 1 {cx + head_r:g},{hy:g} '
                    f'Q{cx + head_r * 0.5:g},{hy - head_r * 0.45:g} {cx - head_r * 0.2:g},{hy - head_r * 0.35:g} '
                    f'Q{cx - head_r * 0.7:g},{hy - head_r * 0.3:g} {cx - head_r:g},{hy:g} Z', hair)
    elif style in ('long', 'pigtails', 'ponytail'):
        out += path(f'M{cx - head_r * 1.02:g},{hy + head_r * 0.15:g} A{head_r * 1.02:g},{head_r * 1.02:g} 0 0 1 {cx + head_r * 1.02:g},{hy + head_r * 0.15:g} '
                    f'Q{cx + head_r * 0.2:g},{hy - head_r * 0.5:g} {cx - head_r * 1.02:g},{hy + head_r * 0.15:g} Z', hair)
    elif style == 'bun':
        out += circle(cx, hy - head_r * 1.02, head_r * 0.36, hair)
        out += path(f'M{cx - head_r:g},{hy - head_r * 0.05:g} A{head_r:g},{head_r:g} 0 0 1 {cx + head_r:g},{hy - head_r * 0.05:g} '
                    f'Q{cx:g},{hy - head_r * 0.62:g} {cx - head_r:g},{hy - head_r * 0.05:g} Z', hair)
    elif style == 'bald':
        for d in (-1, 1):
            out += ellipse(cx + d * head_r * 0.86, hy - head_r * 0.15, head_r * 0.2, head_r * 0.34, hair)
        out += shine(cx - head_r * 0.45, hy - head_r * 0.72, head_r * 0.42, head_r * 0.16)
    out += face(cx, hy + head_r * 0.08, head_r, mood, glasses)
    if beard == 'mustache':
        out += path(f'M{cx - head_r * 0.34:g},{hy + head_r * 0.42:g} Q{cx:g},{hy + head_r * 0.2:g} {cx + head_r * 0.34:g},{hy + head_r * 0.42:g} '
                    f'Q{cx:g},{hy + head_r * 0.34:g} {cx - head_r * 0.34:g},{hy + head_r * 0.42:g} Z', 'gray' if hair in ('gray', 'grayLight') else hair)
    return out, (cx, hy, head_r, top_y, body_w, body_h)
