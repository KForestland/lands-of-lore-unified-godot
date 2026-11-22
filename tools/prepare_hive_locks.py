#!/usr/bin/env python3
"""Pin decoded L1,L1,L3,L2 lock groups; no inferred initial local8 or rewards."""
import argparse,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def build():
 p=ROOT/'scripts/lol2/native_scripts/L5_HC.json';n=json.loads(p.read_text())
 ids=[114,115,116];groups=[6408,6436,6470,6498,6532,6560,6604,6632,6676,6698,6726,6760,6782,6810]
 data={k:n[k] for k in ['format','area','source','predicate_table']}
 data['objects']=[o for o in n['objects'] if o['ref'] in ['control:'+str(i) for i in ids]]
 data['groups']=[g for g in n['groups'] if g['stream']==1 and g['group'] in groups]
 assert len(data['objects'])==3 and len(data['groups'])==14
 for g in data['groups']:
  assert all(c['opcode'] in [16,20,196,198] for c in g['commands'])
 assert [c['opcode'] for c in next(g for g in data['groups'] if g['group']==6560)['commands']]==[20,198,196,20]
 geometry=ROOT/'assets/lol2/generated/hive_review/hive.json';geo=json.loads(geometry.read_text())
 faces=[f for f in geo['faces'] if f['kind']=='floor' and f['region']==760];assert len(faces)==1
 assert all(p[1]==-1011 for p in faces[0]['points'])
 placements=json.loads((ROOT/'assets/lol2/generated/static_assemblies/L5_HC/assemblies.json').read_text())
 return {'version':1,'native_export_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'geometry_sha256':hashlib.sha256(geometry.read_bytes()).hexdigest(),'native':data,'floor':faces[0],'controls':{str(i):placements['placements'][str(i)] for i in ids},'admission':'Lead06:54: exact116,116,114,115 admits existing6560/6632 only; initiallocal8 remains unproved. No rewards added.'}
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
 output=ROOT/'scripts/lol2/hive_locks_source.json';text=json.dumps(build(),indent=2,sort_keys=True)+'\n'
 if args.check:
  if output.read_text()!=text:parser.exit(1,'Hive lock native/geometry/floor pins changed\n')
 else:output.write_text(text)
 print('PASS three decoded Hive locks, fourteen original groups, one original floor')
