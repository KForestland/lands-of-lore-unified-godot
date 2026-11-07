#!/usr/bin/env python3
"""Pin citadel switch/vent/brain event bytes without claiming their world callbacks."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l13-eggs-source.json').read_text());b=(a.game/'DAT/L13_RC.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
for r in s.get('basin_items',[]):check(r,'placement_hex')
g=next(g for g in s['groups'] if g['stream']==1 and g['group']==7888);assert 'c590ca040500' in [c['raw_hex'] for c in g['commands']]
print('PASS source switch420/group7888 region1226; vent265 and brain362 bytes pinned, world joins remain scoped separately')
