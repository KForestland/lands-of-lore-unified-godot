#!/usr/bin/env python3
"""Prepare Cave surface indices against explicitly paired fresh floor and prop packs."""
import argparse,hashlib,json,struct
from pathlib import Path
from PIL import Image
from lol2_creature_sprite_format import decode_rows,require
from lol2_material_format import sections,column_major_to_rows,rgb_palette
HASH='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
def sha(data):return hashlib.sha256(data).hexdigest()
def prepare(texture,floor_root,prop_root,output):
 require(not output.exists(),'Output must be fresh')
 for source in (texture,floor_root,prop_root):require(output!=source and output not in source.parents and source not in output.parents,'Output overlaps input')
 blob=texture.read_bytes();require(sha(blob)==HASH,'Unsupported Cave texture');s=sections(blob);po=struct.unpack_from('<I',blob,4)[0];pal=rgb_palette(blob[po:po+768],6)
 out=output/'assets/lol2/generated/surface_indices';rows=[]
 floors=json.loads((floor_root/'floors.json').read_text());props=json.loads((prop_root/'props.json').read_text())
 require(sorted(map(int,floors['materials']))==[1,16,84,134,156,161,285,303,305,310,603,614,962],'Floor material selection differs')
 require(sorted({p['descriptor'] for p in props['props']})==[192,195,273,274,275,276,278,295,296,297,298,299,300,301,302,306,417,469,473],'Prop material selection differs')
 for row in floors['materials'].values():
  path=(floor_root/row['path']).resolve();require(floor_root in path.parents,'Floor image escapes input root')
 out.mkdir(parents=True)
 for kind,ids in [('floor',sorted(map(int,floors['materials']))),('prop',sorted({p['descriptor'] for p in props['props']}))]:
  for k in ids:
   v=struct.unpack_from('<6H11I',blob,s[2]+k*56);start=s[3]+v[7];payload=blob[start:start+v[12]];w,h=v[1:3]
   if kind=='prop':
    require(v[3]==0x28e and v[4]==1,'Unsupported sprite');dw,dh,indices,_=decode_rows(payload);require((dw,dh)==(w,h),'Sprite dimensions');require(1 not in indices,'Special pixel needs separate compositor')
    rgba=bytes(c for i in indices for c in [*pal[i*3:i*3+3],255 if i else 0]);reference=Image.open(prop_root/f'prop_{k}.png').convert('RGBA');expected=rgba;layout='verified row spans'
   else:
    require(len(payload)==8+w*h and struct.unpack_from('<4H',payload)==(v[3],w,h,w*h&65535),'Unsupported floor payload')
    raw=payload[8:];reference=Image.open(floor_root/floors['materials'][str(k)]['path']).convert('RGB')
    candidates=[('raw source bytes',raw),('column-to-row source bytes',column_major_to_rows(raw,w,h))]
    matches=[(name,buf) for name,buf in candidates if bytes(c for i in buf for c in pal[i*3:i*3+3])==reference.tobytes()]
    require(bool(matches),f'No source layout matches floor{k}');layout,indices=matches[0];w,h=reference.size
    expected=bytes(c for i in indices for c in pal[i*3:i*3+3]);layout+='; preserves existing floor import, not new native orientation proof'
   require(reference.size==(w,h) and reference.tobytes()==expected,f'Preview parity failed: {kind}{k}')
   Image.frombytes('L',(w,h),indices).save(out/f'{kind}_{k}.png');rows.append(dict(kind=kind,descriptor=k,width=w,height=h,indices_sha256=sha(indices),layout=layout,preview_parity=True))
 (out/'manifest.json').write_text(json.dumps(dict(cache_sha256=HASH,materials=rows,scope='Original first mip and variant, exact preview RGB/RGBA parity; no invented index values or new layout claims.'),indent=2)+'\n');print('Exported',len(floors['materials']),'floor and',len({p['descriptor'] for p in props['props']}),'prop index textures; parity exact')

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('texture','floors','props','output-root'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 try:prepare(a.texture.resolve(),a.floors.resolve(),a.props.resolve(),a.output_root.resolve())
 except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
if __name__=='__main__':main()
