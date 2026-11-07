#!/usr/bin/env python3
"""Pin post-fight L9 callbacks; retain unresolved water/table semantics explicitly."""
import argparse, hashlib, json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game',type=Path,required=True)
p.add_argument('--output',type=Path,default=Path('scripts/lol2/l9_flood_source.json'))
a=p.parse_args();root=Path(__file__).resolve().parents[1]
archive=(a.game/'DAT/L9_DR.MIX').read_bytes()
assert hashlib.sha256(archive).hexdigest()=='700300d0cdf7df0af9471f3476c4e6ba473a603fa89e3a6e1855037d70be09c7'
s=json.loads((root/'scripts/lol2/native_scripts/L9_DR.json').read_text())
refs=['prop:'+str(i) for i in [104,108,113,114,1015,1016,1017,1018,1019,1023,1024,1025,1026,1027,1029,1031]]+['control:'+str(i) for i in [82,99,121,122]]+['movable:56']
objects=[o for o in s['objects'] if o['ref'] in refs]
keys={(e['stream'],e['group']) for o in objects for e in o['events'] if 'group' in e}|{(0,i) for i in [5918,6054,6190,6326]}
region_events=[e for row in s['region_lists'] for e in row['records'] if e.get('kind')==11 and int.from_bytes(bytes.fromhex(e['raw_hex'])[4:6],'little') in [5977,6045]]
assert len(region_events)==3
keys.update((0,int.from_bytes(bytes.fromhex(e['raw_hex'])[2:4],'little')) for e in region_events)
for e in region_events:
 raw=bytes.fromhex(e['raw_hex']);assert archive[e['file_offset']:e['file_offset']+len(raw)]==raw
groups=[g for g in s['groups'] if (g['stream'],g['group']) in keys]
for o in objects:
 raw=bytes.fromhex(o['placement_hex']);assert archive[o['file_offset']:o['file_offset']+len(raw)]==raw
 for e in o['events']:
  raw=bytes.fromhex(e['raw_hex']);assert archive[e['file_offset']:e['file_offset']+len(raw)]==raw
for g in groups:
 raw=bytes.fromhex(g['raw_hex']);assert archive[g['file_offset']:g['file_offset']+len(raw)]==raw
floors=next(g['commands'] for g in groups if (g['stream'],g['group'])==(1,5752))
assert len(floors)==91 and all(c['opcode']==196 for c in floors)
nav=json.loads((root/'assets/lol2/generated/creature_nav/L9_DR.json').read_text())['regions']
regions=[]
for c in floors:
 b=bytes.fromhex(c['raw_hex']);i=c['target'];assert b[6:8]==bytes([16,1])
 regions.append(dict(region=i,polygon=nav[i][0],floor=nav[i][1:3],target=int.from_bytes(b[4:6],'little',signed=True),flags=b[6],speed=b[7]))
assert sum(r['target']==87 for r in regions)==90 and next(r for r in regions if r['target']==1)['region']==5977
out=dict(version=1,source_sha256=hashlib.sha256(archive).hexdigest(),objects=objects,groups=groups,region_events=region_events,floor_commands=regions,exit=dict(control=82,timer_prop=104,destination='L8_SJ',selector=5),scope='Byte-checked source links only. Opcode204 -1 arm, floor flags0x10 water presentation, floating table identity/motion and flood damage are not hosted or claimed by this extract.')
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(out,indent=1)+'\n')
print(f'PASS {len(objects)} placements, {len(groups)} groups,91 floor targets and control82 -> prop104 -> L8selector5; unresolved semantics retained')
