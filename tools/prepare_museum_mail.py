#!/usr/bin/env python3
"""Stage source museum item10 Mail Shirt; omit destination-remap marker pixels."""
import sys,json,struct,hashlib
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections,rgb_palette
from lol2_creature_sprite_format import decode_rows
root=Path('~/lol2_out/museum_capture_20260913/game')
out=Path(__file__).resolve().parents[1]/'assets/lol2/generated/museum_mail'
if len(sys.argv) > 1:
 import argparse
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--game',type=Path,required=True)
 parser.add_argument('--output-root',type=Path,required=True)
 args=parser.parse_args();root=args.game.resolve();destination=args.output_root.resolve()
 if destination.exists():parser.error('Output must be a fresh directory')
 if destination==root or destination in root.parents or root in destination.parents:parser.error('Output overlaps original game')
 try:
  for name,wanted in [('DAT/L3_DH.MIX','bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'),
                      ('GLOBAL.MIX','1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
                      ('LOCAL.MIX','d0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
   if hashlib.sha256((root/name).read_bytes()).hexdigest()!=wanted:raise ValueError('Unsupported original '+name)
 except (OSError,ValueError) as error:parser.error(str(error))
 out=destination/'assets/lol2/generated/museum_mail'
out.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
def entry(archive,key):
 a=(root/archive).read_bytes();e=next(e for e in parse_mix(a) if e['key']==key)
 return a[e['offset']:e['offset']+e['size']]
level=entry('DAT/L3_DH.MIX',3106551060)
record=level[u32(level,0x20)+10*37:][:37]
assert u32(record,32)==0xcfee0081
x,y,z=[struct.unpack_from('<h',record,o)[0] for o in [0,2,6]]
assert (x,y,z)==(-4213,1164,50) and struct.unpack_from('<H',record,8)[0]==0x2002
g=entry('GLOBAL.MIX',3984507021)
assert sha(g)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
o,n=u32(g,4),u32(g,0x34);so=o+n*91+4;ns=u32(g,so-4);vo=so+ns*16+4
si=vi=0;resource=None
for i in range(n):
 d=g[o+i*91:][:91]
 for selector in range(d[46]+d[47]):
  count=struct.unpack_from('<b',g,so+si*16+13)[0];count=1 if count<0 else count
  if i==40:
   assert u32(d,24)==0xcfee0081 and d[50]==4 and count==1
   resource=struct.unpack_from('<h',g,vo+vi*12)[0]
  si+=1;vi+=count
assert (si,vi)==(170,170) and resource==298
b=entry('LOCAL.MIX',4018716831)
assert sha(b)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
s=sections(b);v=struct.unpack_from('<6H11I',b,s[2]+resource*56)
payload=b[s[3]+v[7]:s[3]+v[7]+v[12]]
w,h,p,marked=decode_rows(payload,allow_special=True)
assert (w,h)==v[1:3]
pal=rgb_palette(b[u32(b,4):u32(b,4)+768],6)
rgba=bytes(c for i in p for c in (*pal[i*3:i*3+3],0 if i in (0,1) else 255))
Image.frombytes('RGBA',(w,h),rgba).save(out/'mail.png')
assert Image.open(out/'mail.png').tobytes()==rgba
(out/'item.json').write_text(json.dumps(dict(id='museum:item10:Mail_Shirt',name='Mail Shirt',position=[x,z,-y],resource=resource,definition=40,placement_hex=record.hex(),level_sha256=sha(level),definitions_sha256=sha(g),graphics_sha256=sha(b),pixels_sha256=sha(p),omitted_remap_pixels=p.count(1),scope='Source placement/definition/view join and row sprite decode. Label from prior verified item/audio identity audit. RGBA omits index0 and destination-remap index1. World pivot/table/pickup behavior authored; armor effects not implemented.'),indent=2)+'\n')
print('Verified museum item10 Mail Shirt: resource298, position', [x,z,-y], 'image',w,h)
