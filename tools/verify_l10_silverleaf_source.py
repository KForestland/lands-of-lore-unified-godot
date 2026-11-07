#!/usr/bin/env python3
"""Verify the Silverleaf tree grant/activation receipt against original L10 archive bytes."""
import argparse,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args()
s=json.loads((Path(__file__).resolve().parents[1]/'docs/l10-silverleaf-source.json').read_text())
b=(a.game/s['source']['file']).read_bytes();assert hashlib.sha256(b).hexdigest()==s['source']['sha256']
def pin(r,raw='raw_hex',offset='file_offset'):
 data=bytes.fromhex(r[raw]);at=r[offset];assert b[at:at+len(data)]==data
for o in s['objects']:
 if 'placement_hex' in o:pin(o,'placement_hex')
 for e in o['events']:
  pin(e);pred=e.get('predicate')
  if pred:pin(pred,'entry_hex','entry_file_offset');pin(pred,'trailer_hex','trailer_file_offset')
for g in s['groups']:pin(g)
assert len(s['objects'])==15 and len(s['groups'])==31
print('PASS15 objects/31 groups: original Silverleaf grants and prop254 activation; no native conversation claim')
