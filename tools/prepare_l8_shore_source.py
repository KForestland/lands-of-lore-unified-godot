#!/usr/bin/env python3
"""Pin L8 arrival5 and its original shore-Dawn activation callbacks."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('tmp/l8_shore_source.json'));a=p.parse_args()
root=Path(__file__).resolve().parents[1];blob=(a.game/'DAT/L8_SJ.MIX').read_bytes()
assert hashlib.sha256(blob).hexdigest()=='3eff07430a453d2c6f09133f869874e0530af1b6a3bfff7f4297761b96a28bc2'
s=json.loads((root/'scripts/lol2/native_scripts/L8_SJ.json').read_text());refs={'actor:20','prop:630','prop:437','prop:1121','prop:117','prop:102'}
objects=[o for o in s['objects'] if o['ref'] in refs];keys={(e['stream'],e['group']) for o in objects for e in o['events'] if 'group' in e};groups=[g for g in s['groups'] if (g['stream'],g['group']) in keys]
def check(row,field='raw_hex',offset='file_offset'):
 raw=bytes.fromhex(row[field]);assert blob[row[offset]:row[offset]+len(raw)]==raw
for o in objects:
 check(o,'placement_hex')
 for e in o['events']:
  check(e)
  pred=e.get('predicate')
  if pred:check(pred,'entry_hex','entry_file_offset');check(pred,'trailer_hex','trailer_file_offset')
for g in groups:check(g)
pop=json.loads((root/'scripts/lol2/act2_populations/L8_SJ.json').read_text());actor=next(x for x in pop['actors'] if x['actor']==20)
assert actor['definition']==13 and actor['position']==[-4252,0,-1515]
# Pin the already exported source arrival record independently of a preview start.
arrival=dict(selector=5,x=-4292,y=1623,region=66,heading_units=30037,file_offset=13550213,raw_hex='3cef57065575420005000000');check(arrival)
entry=next(g for g in groups if (g['stream'],g['group'])==(1,7888));assert any(c['raw_hex']=='090214000300' for c in entry['commands'])
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(dict(version=1,source_sha256=hashlib.sha256(blob).hexdigest(),arrival=arrival,actor=actor,objects=objects,groups=groups,scope='Byte-checked arrival and callback evidence only. Prop630 kind6/value20/extra05 group7888 links actor20. Dialogue condition meanings, cinematic presentation, global ruin closure and earned escape/arrival are not implemented or qualified by this extract.'),indent=1)+'\n')
print(f'PASS original L8 arrival5, Dawn20/definition13, {len(objects)} objects/{len(groups)} groups; no gameplay completion claim')
