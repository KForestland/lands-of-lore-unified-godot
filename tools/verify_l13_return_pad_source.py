#!/usr/bin/env python3
"""Pin original control54 return-pad placement/event/group bytes."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l13-return-pad-source.json').read_text());b=(a.game/'DAT/L13_RC.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
print('PASS original control54 return placement and group8152; transport semantics remain adapter boundary')
