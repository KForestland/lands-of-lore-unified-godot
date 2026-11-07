#!/usr/bin/env python3
"""Pin Kenneth grant, mountain Baccata placements, and the original citadel entrance."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l12-citadel-source.json').read_text());b=(a.game/'DAT/L12_CM.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
for group,expected in {140:['0301000081cb928c01000000'],2808:['150378000d00','020100001c2d']}.items():
 g=next(g for g in s['groups'] if g['stream']==1 and g['group']==group);assert all(raw in [c['raw_hex'] for c in g['commands']] for raw in expected)
print('PASS original Kenneth prop4/group140 Picture81 and control74/group2808 CITADEL13 -> L13/1; picture-impact/Baccata speech joins remain unproven')
