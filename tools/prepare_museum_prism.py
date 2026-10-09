#!/usr/bin/env python3
"""Pin Museum prop280's one Prism grant and stage its original display/icon."""
from pathlib import Path
import hashlib,json,shutil
from verify_actor_item_grants import source_area
from prepare_museum_key_locks import MAP,definitions,icon
ROOT=Path(__file__).resolve().parents[1]
def main():
 area,arc,entry,raw,owners,streams=source_area('L3_DH')
 selected=[o for o in owners if o['owner_kind']=='prop' and o['owner']==280]
 assert len(selected)==1 and selected[0]['event']==4 and selected[0]['value']==0 and selected[0]['predicate'] is None and selected[0]['group']==6590
 commands=streams[1][6590];assert [c['raw_hex'] for c in commands]==['090318011000','03010000d9cd0de501000000','060318010200','cc90e101cf066703','cc90e201d0066703','cc90e301eb066703','cc90bf01d1066703','cc90e401ec066703','cc90e501d2066703','cc90e601d3066703','090318010200']
 for c in commands:
  b=bytes.fromhex(c['raw_hex']);assert arc[c['archive_offset']:c['archive_offset']+len(b)]==b
 props=json.loads((MAP/'props/props.json').read_text())['props'];prop=next(x for x in props if x['record']==280)
 assert prop['template']==21 and prop['region']==454 and prop['position']==[2324,-30,-3413]
 blob,base,n,names=definitions();assert names[7]=='8-Prism';definition=blob[base+7*91:base+8*91];assert definition[24:28].hex()=='d9cd0de5'
 out=ROOT/'assets/lol2/generated/museum_prism';out.mkdir(parents=True,exist_ok=True);icon(7,out/'icon.png')
 frame=MAP/'props/sprites'/f"{prop['material']}_frame_0.png";shutil.copy2(frame,out/'display.png')
 result={'version':1,'source':area['source'],'owner':selected[0],'commands':commands,'prop':prop,'definition':7,'definition_hex':definition.hex(),'item':'museum:prop280:Prism','images':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in out.glob('*.png')},'scope':'One empty-hand grant and prop removal. First original display frame; shared modern melee weapon behavior. Native animation transition, seven material changes and blinding special effect remain unhosted.'}
 for name in ['scripts/lol2/museum_prism_source.json','docs/museum-prism-source-checks.json']:(ROOT/name).write_text(json.dumps(result,indent=2)+'\n')
 print('PASS prop280/group6590 one Prism, definition7 and source display/icon')
if __name__=='__main__':main()
