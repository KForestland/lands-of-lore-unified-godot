#!/usr/bin/env python3
"""Verify original prison entry owners, ground-globe bytes and room consumer."""
import argparse,hashlib,json,struct
from pathlib import Path
from monastery_media import extract
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l13-prison-source.json').read_text());blob=(a.game/'DAT/L13_RC.MIX').read_bytes();assert hashlib.sha256(blob).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 b=bytes.fromhex(r[key]);assert blob[r['file_offset']:r['file_offset']+len(b)]==b
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:
  check(e)
  if e.get('predicate'):
   pred=e['predicate'];b=bytes.fromhex(pred['entry_hex']);assert blob[pred['entry_file_offset']:pred['entry_file_offset']+len(b)]==b
for g in s['groups']:check(g)
for local in s['locals']:
 assert blob[local['name_file_offset']:local['name_file_offset']+41].split(b'\0')[0].decode()==local['name']
assert sorted(s['ruloi_death_weights'].values())==list(range(1,20)) and sum(s['ruloi_death_weights'].values())==190
for r in s['rooms']:
 room=r['room'];dll,_=extract((a.game/('DAT/'+room+'.MIX')).read_bytes(),'WOMS\\'+room+'_.WOM');assert hashlib.sha256(dll).hexdigest()==r['dll_sha256']
 m=dll[48:48+struct.unpack_from('<I',dll,36)[0]]
 for t in r['strings']:assert m[t['module_offset']:].split(b'\0')[0].decode()==t['text']
 if 'release_branch'in r:
  branch=r['release_branch'];b=bytes.fromhex(branch['raw_hex']);assert m[branch['module_offset']:branch['module_offset']+len(b)]==b
print('PASS original control51/52 room28/29, ground-globe and Ruloi event bytes, local18 dead/local19 cell/local20 corpse counter,19 weights summing190 and SLAVES release consumer; opcode207 runtime/globe joins unproven')
