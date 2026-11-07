#!/usr/bin/env python3
"""Pin original clubhouse candidate guard, paired doors and three placed stones."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l8-clubhouse-source.json').read_text());b=(a.game/'DAT/L8_SJ.MIX').read_bytes();assert hashlib.sha256(b).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 raw=bytes.fromhex(r[key]);assert b[r['file_offset']:r['file_offset']+len(raw)]==raw
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
g=next(g for g in s['groups'] if g['group']==15106);assert [c['raw_hex'] for c in g['commands'][:2]]==['012033006400','012034006400']
rows=json.loads((root/'scripts/lol2/act2_items_source.json').read_text())['areas']['L8_SJ']['items']
for i in [32,33,34]:
 r=next(r for r in rows if r['id']==f'act2:L8_SJ:item{i}');assert r['definition']==68 and r['identity']==0xe0649cba;check(r,'placement_hex')
print('PASS byte-pinned guard21 -> doors51/52 and placed Ancients Stones32/33/34; membership predicate and motion pivot remain adapters')
