#!/usr/bin/env python3
"""Bind weapon shop grants to original item definitions and inventory icons.

stage_items() takes the decoded GLOBAL/LOCAL entries, the output directory, the res:// root and the row/palette/section
decoders, so prepare_weapon_shop.py --game ... can stage the icons with published decoders. Run without arguments, main()
uses the historical prepare_hive_wax helpers as before.
"""
import json,struct
from PIL import Image

def stage_items(definitions,graphics,out,root,sections,rgb_palette,decode_rows,digest,u32):
 assert digest(definitions)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
 assert digest(graphics)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
 base,n=u32(definitions,4),u32(definitions,0x34);so=base+n*91+4;fo=so+u32(definitions,so-4)*16+4;names=fo+u32(definitions,fo-4)*12
 mapping={'5-Short swd':'Short_Sword','7-Long arm':'Long_Arm','42-Gargoyle br':'Gargoyle_Bracers','9-Firestorm':'Firestorm'}
 sec=sections(graphics);palette=rgb_palette(graphics[u32(graphics,4):][:768],6);items={}
 for i in range(n):
  name=definitions[names+i*30:names+i*30+24].split(b'\0')[0].decode()
  if name not in mapping:continue
  d=definitions[base+i*91:][:91];assert d[46]+d[47]==1
  resource=struct.unpack_from('<h',definitions,fo+i*12)[0];desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
  w,h,pixels,_=decode_rows(graphics[sec[3]+desc[7]:][:desc[12]],allow_special=True);assert(w,h)==desc[1:3]
  rgba=bytes(c for p in pixels for c in (*palette[p*3:p*3+3],0 if p in (0,1) else 255))
  path=out/(mapping[name]+'.png');Image.frombytes('RGBA',(w,h),rgba).save(path)
  items['jungle:weapon_shop:'+mapping[name]]=dict(name=name,label=mapping[name].replace('_',' '),definition=i,resource=resource,icon='res://'+str(path.relative_to(root)),definition_hex=d.hex(),pixels_sha256=digest(pixels))
 assert len(items)==4
 (out/'items.json').write_text(json.dumps(items,indent=2)+'\n')
 print('PASS4 original item definitions/icons',[(v['name'],v['definition'],v['resource']) for v in items.values()])

def main():
 from prepare_hive_wax import entry,sections,rgb_palette,decode_rows,ROOT,digest,u32
 definitions=entry('GLOBAL.MIX',3984507021);graphics=entry('LOCAL.MIX',4018716831)
 stage_items(definitions,graphics,ROOT/'assets/lol2/generated/weapon_shop',ROOT,sections,rgb_palette,decode_rows,digest,u32)
if __name__=='__main__':main()
