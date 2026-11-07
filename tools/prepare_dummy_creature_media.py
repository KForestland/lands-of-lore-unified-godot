#!/usr/bin/env python3
"""Prepare the established Cave dummy poses from a freshly decoded texture."""
import argparse,json,struct,hashlib
from pathlib import Path
from PIL import Image
from lol2_creature_sprite_format import lcw,decode_blocks,require
from lol2_material_format import sections
HASH='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
def sha(data):return hashlib.sha256(data).hexdigest()
def prepare(texture,output):
 require(not output.exists(),'Output must be fresh')
 require(output!=texture and output not in texture.parents and texture not in output.parents,'Output overlaps input')
 b=texture.read_bytes();require(sha(b)==HASH,'Unsupported Cave texture');s=sections(b);out=output/'assets/lol2/generated/dummy_creatures';out.mkdir(parents=True);rows=[]
 for k,label,height in [(408,'Normal guard stand-in',56),(733,'Roach-like stand-in',12)]:
  v=struct.unpack_from('<6H11I',b,s[2]+k*56);require(v[3]==0x1246,'Unexpected frame type');payload=b[s[3]+v[7]:s[3]+v[7]+v[12]];ci=struct.unpack_from('<I',payload,8)[0];require(ci<17,'Unsupported codebook');off,allocation,packed=struct.unpack_from('<3I',b,s[9]+ci*12);require(s[8]<=off and off+allocation<=s[9] and packed<=allocation,'Codebook extent')
  w,h,pixels,_,tail=decode_blocks(payload,lcw(b[off:off+packed]));require((w,h)==v[1:3] and 1 not in pixels,'Special pixel needs separate semantics')
  im=Image.frombytes('L',(w,h),pixels);bbox=im.getbbox();require(bbox is not None,'Empty frame');crop=im.crop(bbox);crop.save(out/f'creature_{k}.png');rows.append(dict(descriptor=k,label=label,original_size=[w,h],crop_box=bbox,texture_size=crop.size,indices_sha256=sha(crop.tobytes()),unread_tail=tail,preview_height=height,preview_width=height*crop.width/crop.height,identity_scope='Visual identification, not original filename/state binding'))
 placements=[dict(id='guard_a',descriptor=408,region=353),dict(id='roach_a',descriptor=733,region=354),dict(id='guard_b',descriptor=408,region=1813),dict(id='roach_b',descriptor=733,region=1813,vertex=2,fraction=0.4)]
 (out/'creatures.json').write_text(json.dumps(dict(cache_sha256=HASH,frames=rows,placements=placements,scope='Static dummy poses. Original decoded pixels, cropped transparent bounds. Provisional display heights and floor-region centroid placements; not original spawns, direction/timing, AI, collision or gameplay. Kevin314-407 excluded.'),indent=2)+'\n');print(rows)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--texture',type=Path,required=True);p.add_argument('--output-root',type=Path,required=True);a=p.parse_args()
 try:prepare(a.texture.resolve(),a.output_root.resolve())
 except (ValueError,OSError,IndexError,struct.error) as error:p.error(str(error))
if __name__=='__main__':main()
