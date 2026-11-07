#!/usr/bin/env python3
"""Pin original Claw glacier command bytes, without inferring its event clock."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l12-glacier-source.json').read_text());b=(a.game/'DAT/L12_CM.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
check(s['group'])
floors=[c for c in s['group']['commands'] if c['opcode']==196]
assert sorted(c['target'] for c in floors)==list(range(919,931))
for c in floors:
 r=bytes.fromhex(c['raw_hex']);assert int.from_bytes(r[4:6],'little',signed=True)==-1090 and r[6]==0 and r[7]==50
assert [c['target'] for c in s['group']['commands'] if c['opcode']==9 and c['kind']==16]==[52,53,55,54,56,57]
print('PASS original prop335/group1068:12 floor targets -1090 speed50 and controls52..57; native trigger timing remains unjoined')
