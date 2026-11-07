#!/usr/bin/env python3
"""Pin original Amaranth gift identity and settlement world-exit placement."""
import argparse,hashlib,struct
from pathlib import Path
from audit_monastery_rooms import extract
from verify_chut_room_sources import slots,calls
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);a=p.parse_args()
def module(stem,expected):
 dll,_=extract((a.game/'DAT'/(stem+'.MIX')).read_bytes(),f'WOMS\\{stem}_.WOM')
 assert hashlib.sha256(dll).hexdigest()==expected
 return dll[48:48+struct.unpack_from('<I',dll,36)[0]]
im=module('SHAMAN','f655c92f96aa2ca8ecb59a50d84d7cfed38e5a3736c8dc2b942efc4ead7eaab5');table=slots(im)
assert im[0x1d7f:].split(b'\0')[0]==b'117-Amaranth sr'
assert table[0x1df8]==0x40 and im[0x1111:0x111d].hex()=='53687f1d0000ff15f81d0000'
# Check exact original placement call recorded in the source receipt.
import json
proof=json.loads((Path(__file__).resolve().parents[1]/'docs/l8-arena-exit-source.json').read_text())
im=module('SETTLE1',proof['settlement_exit']['dll_sha256']);table=slots(im)
cs=calls(im,table,0x520,0x580)
assert any(c['host']=='place' and c['args']==[531,4414] for c in cs)
assert any(c['host']=='host_f0' and c['args']==[180] for c in cs)
print('PASS original SHAMAN Amaranth gift call and SETTLE1 place531/4414; intervening views/outcome remain adapters')
