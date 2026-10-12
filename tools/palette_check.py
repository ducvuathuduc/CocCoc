#!/usr/bin/env python3
"""Fail if apps/mobile/lib uses a Color(0xFF......) not sampled from Gummble refs (tolerance 6/channel)."""
import json,re,glob,sys
ref=json.load(open('docs/design/qa/palette_from_refs.json'))
pal={h for v in ref['per_screen'].values() for h in v}
rgb=lambda h:tuple(int(h[i:i+2],16) for i in (1,3,5))
P=[rgb(h) for h in pal]
bad={}
for f in glob.glob('apps/mobile/lib/**/*.dart',recursive=True):
    for m in re.finditer(r'Color\(0x[Ff]{2}([0-9A-Fa-f]{6})\)',open(f).read()):
        c=rgb('#'+m.group(1).upper())
        if min(max(abs(a-b) for a,b in zip(c,p)) for p in P)>6: bad.setdefault('#'+m.group(1).upper(),set()).add(f)
for k,v in sorted(bad.items()): print(k, ', '.join(sorted(v))[:200])
print(f"{len(bad)} colors not found in Gummble refs"); sys.exit(1 if bad else 0)
