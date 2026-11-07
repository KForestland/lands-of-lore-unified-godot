#!/usr/bin/env python3
"""Pin original control104 exit-lock placement/event/group bytes."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l12-gulch-exit-source.json').read_text());b=(a.game/'DAT/L12_CM.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 if 'placement_hex' in o:check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
print('PASS original L12 region734 stream0/group0 exit020100001c88; existing host maps level8 selector4')
