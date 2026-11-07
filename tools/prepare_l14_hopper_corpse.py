#!/usr/bin/env python3
"""Decode the original L14 LAMPLT corpse frame for the logged carry adapter."""
import hashlib,json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1];src=root/'assets/lol2/generated/act2_creatures/L14_HT'
m=json.loads((src/'sprites.json').read_text());frame=next(f for f in m['frames'] if f['resource']==4)
assert hashlib.sha256((src/frame['file']).read_bytes()).hexdigest()==frame['png_sha256']
assert hashlib.sha256((src/'palette.png').read_bytes()).hexdigest()==m['palette']['png_sha256']
a=Image.open(src/frame['file']);pal=Image.open(src/'palette.png').convert('RGB');assert a.mode=='L'
out=Image.new('RGBA',a.size);out.putdata([(*pal.getpixel((v,0)),255 if v else 0) for v in a.getdata()]);box=out.getbbox();out=out.crop(box)
dest=root/'assets/lol2/generated/l14_hopper_platform';dest.mkdir(parents=True,exist_ok=True);out.save(dest/'corpse.png')
record={'source_frame_sha256':frame['png_sha256'],'source_palette_sha256':m['palette']['png_sha256'],'definition':0,'corpse_selector':16,'resource':4,'crop':box,'icon_sha256':hashlib.sha256((dest/'corpse.png').read_bytes()).hexdigest(),'grade':'original indexed corpse frame/palette; modern carry icon crop'}
(root/'scripts/lol2/l14_hopper_corpse_source.json').write_text(json.dumps(record,indent=1)+'\n');print('PASS original corpse frame/palette decoded',record['icon_sha256'])
