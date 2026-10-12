#!/usr/bin/env python3
"""Fail if apps/mobile/lib uses a Color(0xFF......) not sampled from Gummble refs (tolerance 6/channel).

Also checks the lesson word illustrations (content/*/media/images/src/*.svg, the vector sources of
the imageChoice art): every fill/stroke colour must be a sampled reference colour (same tolerance).
`--lesson-art` runs only that check.
"""
import json,re,glob,sys
ref=json.load(open('docs/design/qa/palette_from_refs.json'))
pal={h for v in ref['per_screen'].values() for h in v}
rgb=lambda h:tuple(int(h[i:i+2],16) for i in (1,3,5))
P=[rgb(h) for h in pal]
far=lambda c:min(max(abs(a-b) for a,b in zip(c,p)) for p in P)>6
bad={}
lib=[] if '--lesson-art' in sys.argv else glob.glob('apps/mobile/lib/**/*.dart',recursive=True)
for f in lib:
    for m in re.finditer(r'Color\(0x[Ff]{2}([0-9A-Fa-f]{6})\)',open(f).read()):
        c=rgb('#'+m.group(1).upper())
        if far(c): bad.setdefault('#'+m.group(1).upper(),set()).add(f)
for k,v in sorted(bad.items()): print(k, ', '.join(sorted(v))[:200])
if lib: print(f"{len(bad)} colors not found in Gummble refs")
art=sorted(glob.glob('content/*/media/images/src/*.svg'))
art_bad={}; art_colors=set()
for f in art:
    for m in re.finditer(r'(?:fill|stroke)="#([0-9A-Fa-f]{6})"',open(f).read()):
        h='#'+m.group(1).upper(); art_colors.add(h)
        if far(rgb(h)): art_bad.setdefault(h,set()).add(f)
for k,v in sorted(art_bad.items()): print('lesson art', k, ', '.join(sorted(v))[:200])
print(f"lesson art: {len(art)} svg, {len(art_colors)} colors, {len(art_bad)} not found in Gummble refs")
sys.exit(1 if bad or art_bad else 0)
