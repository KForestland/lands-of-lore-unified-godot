#!/usr/bin/env python3
"""Pin original Temple priest, ritual bowls and pew supply bytes."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l14-priest-ritual-source.json').read_text());b=(a.game/'DAT/L14_HT.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
for item in s['items']:check(item,'placement_hex')
print('PASS original Temple corpses274/187, ritual bowls369/370 identity offers/floor groups, pew items68 Aloe109 and72 Poison125')
