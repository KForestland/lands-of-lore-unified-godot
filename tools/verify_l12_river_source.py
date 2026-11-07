#!/usr/bin/env python3
"""Pin original river raft and niche placement/event/group bytes."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l12-river-source.json').read_text());b=(a.game/'DAT/L12_CM.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
check(s['item'],'placement_hex')
for r in s.get('bank_regions',[]):check(r)
print('PASS original river rafts50/51/55, seven waypoint groups, prop136/group564 and dormant armor5; motion clock and Spark input remain adapter boundaries')
