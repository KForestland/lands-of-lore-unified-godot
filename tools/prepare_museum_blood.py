#!/usr/bin/env python3
"""Pin Museum skeleton20's two Dragon Blood grants and three placed vials; extract original icon."""
import hashlib,json,struct
from pathlib import Path
from verify_actor_item_grants import source_area,u32
from prepare_museum_key_locks import definitions,icon
ROOT=Path(__file__).resolve().parents[1]
def main(game=None, root=ROOT):
 area,archive,entry,raw,owners,streams=source_area('L3_DH', game=game)
 grants=[c for c in streams[1][12578] if bytes.fromhex(c['raw_hex'])[:2]==b'\x03\x02']
 assert len(grants)==2 and all(c['raw_hex']=='03021400bfb15e7c04000000' for c in grants)
 for c in grants:
  b=bytes.fromhex(c['raw_hex']);assert archive[c['archive_offset']:c['archive_offset']+len(b)]==b
 matches=[o for o in owners if o['stream']==1 and o['group']==12578];assert len(matches)==1 and matches[0]['owner_kind']=='actor' and matches[0]['owner']==20 and matches[0]['event']==6 and matches[0]['value']==9
 blob,base,count,names=definitions(game=game);assert names[166]=='Drag Blood' and u32(blob,base+166*91+24)==0x7c5eb1bf
 placed=[]
 for i in range(u32(raw,0x6c)):
  row=raw[u32(raw,0x20)+37*i:][:37]
  if u32(row,32)!=0x7c5eb1bf:continue
  x,y,_,z,flags,region=struct.unpack_from('<hhHhHH',row);assert flags==2
  placed.append({'row':i,'position':[x,z,-y],'region':region,'flags':flags,'raw':row.hex(),'id':f'museum:item{i}:Dragon_Blood'})
 assert [r['row'] for r in placed]==[1,2,3]
 out=root/'assets/lol2/generated/museum_blood_loot';icon(166,out/'icon.png',game=game)
 report={'passed':True,'source':area['source'],'actor':20,'group':12578,'owners':matches,'grants':grants,'definition':166,'identity':0x7c5eb1bf,'definition_hex':blob[base+166*91:base+167*91].hex(),'placed':placed,'icon_sha256':hashlib.sha256((out/'icon.png').read_bytes()).hexdigest(),'scope':'Two explicit actor-owned grants plus three active placed vials. Modern corpse retirement, six-second fuse, blast range/damage and placement are adapters; native behavior parity is not claimed.'}
 (root/'scripts/lol2/museum_blood_source.json').write_text(json.dumps(report,indent=2)+'\n')
 (root/'docs/museum-blood-source-checks.json').write_text(json.dumps(report,indent=2)+'\n')
 print('PASS 2 corpse grants + 3 placed Dragon Blood vials and original icon')
def explicit_main():
 import argparse
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--game',type=Path,required=True)
 parser.add_argument('--output-root',type=Path,required=True)
 a=parser.parse_args();game=a.game.resolve();out=a.output_root.resolve()
 if out.exists():parser.error('Output must be a fresh directory')
 if out==game or out in game.parents or game in out.parents:parser.error('Output overlaps original game')
 try:
  for name,wanted in [('DAT/L3_DH.MIX','bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'),
                      ('GLOBAL.MIX','1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
                      ('LOCAL.MIX','d0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
   if hashlib.sha256((game/name).read_bytes()).hexdigest()!=wanted:raise ValueError('Unsupported original '+name)
  (out/'docs').mkdir(parents=True);(out/'scripts/lol2').mkdir(parents=True)
  main(game=game,root=out)
 except (OSError,ValueError,AssertionError) as error:parser.error(str(error) or type(error).__name__)

if __name__=='__main__':
 import sys
 if len(sys.argv)>1:explicit_main()
 else:main()
