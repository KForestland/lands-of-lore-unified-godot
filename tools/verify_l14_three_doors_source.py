#!/usr/bin/env python3
"""Verify original Temple spiral, three-door controls and Jkar idol records."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l14-three-doors-source.json').read_text());b=(a.game/'DAT/L14_HT.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
for key in ['tilt_region_records','fire_region_records']:
 for r in s.get(key,[]):check(r)
print('PASS original',len(s['objects']),'object placements/events,',len(s['groups']),'groups and trial descriptor records; native modes and book joins remain separate')
