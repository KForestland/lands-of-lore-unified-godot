#!/usr/bin/env python3
"""Pin prop297's three placed burnt crystals and extract original icons/hit sounds."""
import argparse,json,struct,hashlib
from pathlib import Path
from verify_actor_item_grants import source_area
from prepare_museum_key_locks import definitions,icon
from prepare_creature_audio_clips import stage_clips
from lol2_source_format import u32
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
if a.out.exists():p.error('Output must be fresh')
game=a.game.resolve();out=a.out.resolve()
if game==out or game in out.parents or out in game.parents:p.error('Output overlaps game')
area,arc,entry,geo,owners,streams=source_area('L3_DH',game=game)
blob,base,count,names=definitions(game=game);assert names[58]=='57b-Fire brnt' and u32(blob,base+58*91+24)==0xddc02377
rows=[]
for stage,(item,group,sound,pred) in enumerate([(6,6692,484,206),(5,6720,485,207),(4,6748,487,208)]):
 r=next(r for r in owners if r['owner_kind']=='prop' and r['owner']==297 and r['event']==9 and r['group']==group);off=r['archive_offset'];raw=arc[off:off+arc[off]];assert raw[4:]==bytes.fromhex('060904000181') and r['predicate']==pred
 commands=[c['raw_hex'] for c in streams[1][group]];assert commands==['10032901%02x00'%(stage+1),'14032901%02x0196000a14'%(sound&255),'0904%02x000300'%item]
 io=u32(geo,0x20)+item*37;b=geo[io:io+37];assert u32(b,32)==0xddc02377;x,y,z=struct.unpack_from('<hh2xh',b)
 rows.append(dict(item=item,id='museum:item%d:Fire_Crystal'%item,position=[x,z,-y],placement_hex=b.hex(),archive_offset=entry['offset']+io,hit=dict(record_hex=raw.hex(),archive_offset=off,group=group,predicate=pred,commands=commands),sound=sound))
assets=out/'assets/lol2/generated/museum_crystal';assets.mkdir(parents=True)
icon(58,assets/'burnt.png',game=game);icon(57,assets/'charged.png',game=game);stage_clips(out,'museum_crystal',[484,485,487],game=game)
contract=dict(version=1,source=area['source'],items=rows,hit_condition='mask0&0x906 and mask2&4 and supplied amount>=1; state0/1/2 advances one row; mode0x81 clears after success',files={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in assets.iterdir()},adapters=['World pickup uses original icon at0.5unit/pixel, fixed original itemplacement; native falling physics not hosted','Melee positive damage supplied by port; original hit-filter replay is separate','Same carriedidentity retains charged/burnt form through saved charges, matching existing firecrystal adapter'])
f=out/'scripts/lol2/museum_crystal_source.json';f.parent.mkdir(parents=True);f.write_text(json.dumps(contract,indent=2)+'\n');print('PASS three original placed burntcrystals, two icons, three hit sounds')
