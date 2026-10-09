#!/usr/bin/env python3
"""Original captain player grants: definitions, icons and equipped defense byte."""
import json,struct
from PIL import Image
from prepare_hive_wax import entry,sections,rgb_palette,decode_rows,ROOT,digest,u32

def main():
 definitions=entry('GLOBAL.MIX',3984507021);graphics=entry('LOCAL.MIX',4018716831)
 assert digest(definitions)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
 assert digest(graphics)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
 base,n=u32(definitions,4),u32(definitions,0x34);so=base+n*91+4;fo=so+u32(definitions,so-4)*16+4;names=fo+u32(definitions,fo-4)*12
 mapping={'5-Short swd':('Short_Sword',4,0xe29a1126),'37-Brnt Chain':('Burnt_Chain',36,0x65fe4457)}
 out=ROOT/'assets/lol2/generated/cave_captain_items';out.mkdir(parents=True,exist_ok=True)
 sec=sections(graphics);palette=rgb_palette(graphics[u32(graphics,4):][:768],6);items={}
 for i in range(n):
  name=definitions[names+i*30:names+i*30+24].split(b'\0')[0].decode()
  if name not in mapping:continue
  label,wanted,identity=mapping[name];d=definitions[base+i*91:][:91];assert i==wanted and u32(d,24)==identity and d[46]+d[47]==1
  resource=struct.unpack_from('<h',definitions,fo+i*12)[0];desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
  w,h,pixels,_=decode_rows(graphics[sec[3]+desc[7]:][:desc[12]],allow_special=True);assert(w,h)==desc[1:3]
  rgba=bytes(c for p in pixels for c in (*palette[p*3:p*3+3],0 if p in (0,1) else 255))
  path=out/(label+'.png');Image.frombytes('RGBA',(w,h),rgba).save(path)
  # Cave renderer consumes original palette indices; both native transparency indices become0.
  Image.frombytes('L',(w,h),bytes(0 if p in (0,1) else p for p in pixels)).save(out/(label+'_indices.png'))
  items['cave:captain:'+label]=dict(name=name,label=label.replace('_',' '),definition=i,resource=resource,icon='res://'+str(path.relative_to(ROOT)),defense=d[0x41],definition_hex=d.hex(),pixels_sha256=digest(pixels))
 assert definitions[base+40*91+0x41]==20 and definitions[base+41*91+0x41]==5
 assert len(items)==2 and items['cave:captain:Burnt_Chain']['defense']==8
 (out/'items.json').write_text(json.dumps(items,indent=2)+'\n')
 (ROOT/'docs/captain-items-source-checks.json').write_text(json.dumps(dict(definitions_sha256=digest(definitions),graphics_sha256=digest(graphics),items=items,armor_scalars={'Burnt_Chain':8,'Mail_Shirt':20,'Gargoyle_Bracers':5},scope='Exact source captain kind4 player grants; original icon decode. Equipped armor contribution byte+0x41 shares verified native six-slot defense sum (verify_gargoyle_bracers.py). Weapon uses existing playable melee adapter; not a native sword damage claim.'),indent=2)+'\n')
 print('PASS captain original ShortSword/BurntChain identities/icons; armor defense8')
if __name__=='__main__':main()
