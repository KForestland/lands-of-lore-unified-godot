#!/usr/bin/env python3
"""Bind magic shop grants to original item definitions and inventory icons."""
import json,struct
from PIL import Image
from pathlib import Path

def main():
 definitions=entry('GLOBAL.MIX',3984507021);graphics=entry('LOCAL.MIX',4018716831)
 assert digest(definitions)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
 assert digest(graphics)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
 base,n=u32(definitions,4),u32(definitions,0x34);so=base+n*91+4;fo=so+u32(definitions,so-4)*16+4;names=fo+u32(definitions,fo-4)*12
 mapping={'124-War cluster':'War_cluster','131-Mana foil':'Mana_foil','138-SS5':'SS5','57a-Fire crstl':'Fire_crystals','28-Dag Light':'Dag_Light','21-Tho fixed':'Tho_fixed'}
 out=ROOT/'assets/lol2/generated/magic_shop_items';out.mkdir(parents=True,exist_ok=True);sec=sections(graphics);palette=rgb_palette(graphics[u32(graphics,4):][:768],6);items={}
 for i in range(n):
  name=definitions[names+i*30:names+i*30+24].split(b'\0')[0].decode()
  if name not in mapping:continue
  d=definitions[base+i*91:][:91];assert d[46]+d[47]==1
  resource=struct.unpack_from('<h',definitions,fo+i*12)[0];desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
  w,h,pixels,_=decode_rows(graphics[sec[3]+desc[7]:][:desc[12]],allow_special=True);assert(w,h)==desc[1:3]
  rgba=bytes(c for p in pixels for c in (*palette[p*3:p*3+3],0 if p in (0,1) else 255))
  path=out/(mapping[name]+'.png');Image.frombytes('RGBA',(w,h),rgba).save(path)
  items['jungle:magic_shop:'+mapping[name]]=dict(name=name,label=mapping[name].replace('_',' '),definition=i,resource=resource,icon='res://'+str(path.relative_to(ROOT)),definition_hex=d.hex(),pixels_sha256=digest(pixels))
 assert len(items)==6
 (out/'items.json').write_text(json.dumps(items,indent=2)+'\n')
 print('PASS6 original item definitions/icons',[(v['name'],v['definition'],v['resource']) for v in items.values()])
def explicit_main():
 import argparse,hashlib
 global ROOT,entry,sections,rgb_palette,decode_rows,digest,u32
 from lol2_source_format import parse_mix,u32
 from lol2_material_format import sections,rgb_palette
 from lol2_creature_sprite_format import decode_rows
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--game',type=Path,required=True)
 p.add_argument('--output-root',type=Path,required=True)
 a=p.parse_args();game=a.game.resolve();ROOT=a.output_root.resolve()
 if ROOT.exists():p.error('Output must be a fresh directory')
 if ROOT==game or ROOT in game.parents or game in ROOT.parents:p.error('Output overlaps original game')
 digest=lambda raw:hashlib.sha256(raw).hexdigest()
 archives={}
 try:
  for name,wanted in [('GLOBAL.MIX','1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
                      ('LOCAL.MIX','d0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
   archives[name]=(game/name).read_bytes()
   if digest(archives[name])!=wanted:raise ValueError('Unsupported original '+name)
  def entry(filename,key):
   raw=archives[filename];matches=[e for e in parse_mix(raw) if e['key']==key]
   if len(matches)!=1:raise ValueError('Expected one source entry')
   e=matches[0];return raw[e['offset']:e['offset']+e['size']]
  main()
 except (OSError,ValueError,AssertionError) as error:p.error(str(error) or type(error).__name__)

if __name__=='__main__':
 import sys
 if len(sys.argv)>1:explicit_main()
 else:
  from prepare_hive_wax import entry,sections,rgb_palette,decode_rows,ROOT,digest,u32
  main()
