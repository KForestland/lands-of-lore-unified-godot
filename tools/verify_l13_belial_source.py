#!/usr/bin/env python3
"""Pin original Citadel bridge, encounter and altar placement/event/group bytes without claiming the book gate join."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l13-belial-source.json').read_text());b=(a.game/'DAT/L13_RC.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
print('PASS original control75/90/100/103, actor40, eye193/bridge306 and altar173/174/175/326 bytes; effects and joins separate')
