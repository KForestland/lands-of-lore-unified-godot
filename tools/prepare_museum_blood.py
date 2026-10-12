#!/usr/bin/env python3
"""Pin Museum skeleton20's two Dragon Blood grants and three placed vials; extract original icon."""
import hashlib,json,struct
from pathlib import Path
from verify_actor_item_grants import source_area,u32
from prepare_museum_key_locks import definitions,icon
ROOT=Path(__file__).resolve().parents[1]
def main():
 area,archive,entry,raw,owners,streams=source_area('L3_DH')
 grants=[c for c in streams[1][12578] if bytes.fromhex(c['raw_hex'])[:2]==b'\x03\x02']
 assert len(grants)==2 and all(c['raw_hex']=='03021400bfb15e7c04000000' for c in grants)
 for c in grants:
  b=bytes.fromhex(c['raw_hex']);assert archive[c['archive_offset']:c['archive_offset']+len(b)]==b
 matches=[o for o in owners if o['stream']==1 and o['group']==12578];assert len(matches)==1 and matches[0]['owner_kind']=='actor' and matches[0]['owner']==20 and matches[0]['event']==6 and matches[0]['value']==9
 blob,base,count,names=definitions();assert names[166]=='Drag Blood' and u32(blob,base+166*91+24)==0x7c5eb1bf
 placed=[]
 for i in range(u32(raw,0x6c)):
  row=raw[u32(raw,0x20)+37*i:][:37]
  if u32(row,32)!=0x7c5eb1bf:continue
  x,y,_,z,flags,region=struct.unpack_from('<hhHhHH',row);assert flags==2
  placed.append({'row':i,'position':[x,z,-y],'region':region,'flags':flags,'raw':row.hex(),'id':f'museum:item{i}:Dragon_Blood'})
 assert [r['row'] for r in placed]==[1,2,3]
 out=ROOT/'assets/lol2/generated/museum_blood_loot';icon(166,out/'icon.png')
 report={'passed':True,'source':area['source'],'actor':20,'group':12578,'owners':matches,'grants':grants,'definition':166,'identity':0x7c5eb1bf,'definition_hex':blob[base+166*91:base+167*91].hex(),'placed':placed,'icon_sha256':hashlib.sha256((out/'icon.png').read_bytes()).hexdigest(),'scope':'Two explicit actor-owned grants plus three active placed vials. Modern corpse retirement, six-second fuse, blast range/damage and placement are adapters; native behavior parity is not claimed.'}
 (ROOT/'scripts/lol2/museum_blood_source.json').write_text(json.dumps(report,indent=2)+'\n')
 (ROOT/'docs/museum-blood-source-checks.json').write_text(json.dumps(report,indent=2)+'\n')
 print('PASS 2 corpse grants + 3 placed Dragon Blood vials and original icon')
if __name__=='__main__':main()
