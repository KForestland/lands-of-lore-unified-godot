#!/usr/bin/env python3
"""Stage every present Act2/3 item placement, retaining dormant/other rows as census evidence.
Low flag bit1 denotes item-class placement (LIKELY), 0x1000 absence as existing producers.
Native pickup flag restrictions untraced: E pickup is an adapter; no handlers enabled.
"""
import argparse,hashlib,json,struct
from pathlib import Path
from build_game_atlas import parse_mix,section
ROOT=Path(__file__).resolve().parents[1]
AREAS=['L8_SJ','L9_DR','L10_DC','L12_CM','L13_RC','L14_HT','L16_CA','L17_HC','L19_BC','L20_BB']
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--actors',type=Path,default=Path('~/lol2_github_source_20260911/docs/game-actors.json'));a=p.parse_args()
 definitions=json.loads((ROOT/'assets/lol2/generated/items/definitions.json').read_text());by_identity={r['identity']:r for r in definitions['definitions']};result={}
 for area in json.loads(a.actors.read_text())['areas']:
  if area['id'] not in AREAS:continue
  blob=(a.game/area['source']['file']).read_bytes();assert hashlib.sha256(blob).hexdigest()==area['source']['sha256']
  e=next(e for e in parse_mix(blob) if e['key']==area['source']['geometry_key']);g=blob[e['offset']:e['offset']+e['size']];assert hashlib.sha256(g).hexdigest()==area['source']['geometry_sha256']
  offset,count,rows=section(g,0x20,0x6c,37);items=[];excluded=[]
  for i in range(count):
   r=rows[i*37:(i+1)*37];x,z,h,y=struct.unpack_from('<hhHh',r);flags,region=struct.unpack_from('<HH',r,8);identity=struct.unpack_from('<I',r,32)[0]
   common=dict(row=i,flags=flags,region=region,identity=identity,position=[x,y,-z],heading=h,placement_hex=r.hex(),file_offset=e['offset']+offset+i*37)
   if not flags&2 or flags&0x1000:
    excluded.append(dict(**common,reason='dormant placement' if flags&0x1000 else 'not item-class flag2'));continue
   assert identity in by_identity,(area['id'],i,identity)
   d=by_identity[identity];assert not d['ghost'] and d['icon'],(area['id'],i,d['name'])
   icon=d['icon']['path'];assert (ROOT/icon.removeprefix('res://')).is_file(),icon
   items.append(dict(**common,id=f"act2:{area['id']}:item{i}",definition=d['index'],name=d['name'],label=d['label'],icon=icon,handler=d['handler'],grade='LIKELY'))
  result[area['id']]=dict(source=area['source'],source_count=count,items=items,excluded=excluded)
  print(area['id'],count,len(items),len(excluded))
 out=ROOT/'scripts/lol2/act2_items_source.json';out.write_text(json.dumps(dict(version=1,definitions_sources=definitions['sources'],areas=result),indent=1)+'\n')
if __name__=='__main__':main()
