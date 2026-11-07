#!/usr/bin/env python3
"""Check original Larkhon offer, sleep callbacks and native mountain exit bytes."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l8-larkhon-source.json').read_text());b=(a.game/'DAT/L8_SJ.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 if 'placement_hex'in o:check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
o=next(o for o in s['objects'] if o['ref']=='actor:115');e=next(e for e in o['events'] if e['kind']==4);raw=bytes.fromhex(e['raw_hex']);assert raw[4]==3 and int.from_bytes(raw[6:10],'little')==0x58c85701
for group,commands in {21504:['0d02730004090000','c590cd0c0500','c590ce0c0500','c590810d0500'],21588:['0d02730004080000'],1908:['020100001c2c']}.items():
 g=next(g for g in s['groups'] if g['group']==group);assert all(c in [x['raw_hex'] for x in g['commands']] for c in commands)
facade=next(o for o in s['objects'] if o['ref']=='control:111');assert int.from_bytes(bytes.fromhex(facade['placement_hex'])[8:10],'little')&0x80==0
assert '111' not in json.loads((root/'scripts/lol2/static_collision_L8_SJ.json').read_text())['boxes']
print('PASS original115/128 offer, opcode13 arguments9/8, passage regions3277/3278/3457 and native L12/1 exit; recipe/activation/clock adapters remain explicit')
