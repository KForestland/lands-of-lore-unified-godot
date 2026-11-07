#!/usr/bin/env python3
"""Verify actor-owned L8 speech commands and stage the three original audible cues."""
import argparse,json,hashlib
from pathlib import Path
from prepare_creature_audio_clips import stage_clips,BANK_HASH
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output-root',type=Path,default=Path('.'));a=p.parse_args();root=Path(__file__).resolve().parents[1]
s=json.loads((root/'docs/l8-huline-speech-source.json').read_text());blob=(a.game/'DAT/L8_SJ.MIX').read_bytes();assert hashlib.sha256(blob).hexdigest()==s['source_sha256']
def check(r,key='raw_hex'):
 b=bytes.fromhex(r[key]);assert blob[r['file_offset']:r['file_offset']+len(b)]==b
for o in s['objects']:
 check(o,'placement_hex')
 for e in o['events']:check(e)
for g in s['groups']:check(g)
expected={18566:(93,237),17970:(92,1012),15636:(23,1016),17284:(82,1016)}
for g in s['groups']:
 actor,cue=expected[g['group']];c=next(c for c in g['commands'] if c['opcode']==20);b=bytes.fromhex(c['raw_hex']);assert b[1]==2 and int.from_bytes(b[2:4],'little')==actor and int.from_bytes(b[4:6],'little')==cue
clips=stage_clips(a.output_root.resolve(),'l8_huline_speech',[237,1012,1016],names={237:'0204224e.aud',1012:'0112208e.aud',1016:'0263011e.aud'},game=a.game)
out=a.output_root/'assets/lol2/generated/l8_huline_speech/audio.json';out.write_text(json.dumps(dict(sound_bank_sha256=BANK_HASH,clips=clips),indent=2)+'\n')
print('PASS original L8 actor bindings and three lossless speech cues; near-actor trigger remains modern')
