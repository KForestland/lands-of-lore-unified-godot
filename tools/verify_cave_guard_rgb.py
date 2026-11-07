#!/usr/bin/env python3
"""Verify the RGB compositor sentinel is absent from every original decoded frame."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/'scripts/lol2/cave_guard_sequence_source.json').read_text())
count=0
for clip in source['clips']:
 for row in clip['frames']:
  path=ROOT/row['file'].removeprefix('res://')
  assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']
  image=Image.open(path).convert('RGB')
  colours=image.getcolors(image.width*image.height)
  assert colours is not None and all(colour!=(64,64,0) for _,colour in colours),str(path)
  count+=1
assert count==430
print(json.dumps(dict(passed=True,frames=count,sentinel=[64,64,0],collisions=0,source=source['source'])))
