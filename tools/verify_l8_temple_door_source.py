#!/usr/bin/env python3
"""Pin original Temple approach prop1198 and exit group11612 bytes."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l8-temple-door-source.json').read_text());b=(a.game/'DAT/L8_SJ.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
print('PASS original prop1198/predicate136/group11612 exit; earned Dreamstone producer is modern')
s=json.loads((root/'docs/l14-temple-entry-source.json').read_text());b=(a.game/'DAT/L14_HT.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
print('PASS original L14 main doors92/93, distinct slot72 and corpse placements187/274')
