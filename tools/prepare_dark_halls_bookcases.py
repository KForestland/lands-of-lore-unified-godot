#!/usr/bin/env python3
"""Stage native bookcase use records and exported mesh bounds; slide axis is a presentation adapter."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 n=json.loads((ROOT/'scripts/lol2/native_scripts/L7_DH.json').read_text());a=json.loads((ROOT/'assets/lol2/generated/dark_halls/area.json').read_text());rows=[]
 for id in [51,58,59]:
  o=next(o for o in n['objects'] if o['ref']==f'movable:{id}');b=bytes.fromhex(o['placement_hex']);heading=int.from_bytes(b[4:6],'little')
  faces=[f for f in a['faces'] if f.get('placement_kind')=='movable' and f.get('source_index')==id]
  assert faces and all(f['template']==0 for f in faces)
  lo=[min(v[i] for f in faces for v in f['points']) for i in range(3)];hi=[max(v[i] for f in faces for v in f['points']) for i in range(3)]
  events=[e for e in o['events'] if e['kind']==4];assert len(events)==(2 if id==58 else 1)
  assert b[34] in [2,4]
  rows.append(dict(control=id,center=[(x+y)/2 for x,y in zip(lo,hi)],size=[y-x for x,y in zip(lo,hi)],travel=b[36],direction=[math.cos(heading/65536*math.tau),0,math.sin(heading/65536*math.tau)],groups=[e['group'] for e in events]))
 (ROOT/'scripts/lol2/dark_halls_bookcases_source.json').write_text(json.dumps(dict(controls=rows),indent=1)+'\n');print('PASS bookcase source: native movables51/58/59 and mesh bounds')
if __name__=='__main__':main()
