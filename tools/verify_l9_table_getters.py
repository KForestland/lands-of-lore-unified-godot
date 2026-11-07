#!/usr/bin/env python3
"""Replay assembly height/coefficient getters, including original flood-table template19."""
import argparse,hashlib,json,struct
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay
from verify_special_pixel_table_binding import fixups
from verify_actor_item_grants import parse_mix
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
b=(a.game/'LOLG.DAT').read_bytes();assert hashlib.sha256(b).hexdigest()=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
archive=(a.game/'DAT/L9_DR.MIX').read_bytes();assert hashlib.sha256(archive).hexdigest()=='700300d0cdf7df0af9471f3476c4e6ba473a603fa89e3a6e1855037d70be09c7';entry=parse_mix(archive)[0];meta=archive[entry['offset']:entry['offset']+entry['size']];offset=struct.unpack_from('<I',meta,12)[0]+19*60;t=meta[offset:offset+60];assert (t[49],t[46])==(59,200)
u32=lambda o:struct.unpack_from('<I',b,o)[0];le=0x39024+u32(0x39060);objects=le+u32(le+0x40);first=u32(objects+108)
assert b[0x5b64d+0x37000:0x5b654+0x37000].hex()=='c7402884540000'
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True;bindings=[];proof=[];cases=0
for slot,start,end,field in [(8,0x5cf44,0x5cf54,49),(12,0x5cf54,0x5cf64,46)]:
 address=0x5484+slot;f=fixups(b,le,first-1+address//4096)[address%4096];assert f['target_object']==2 and f['target_offset']+0x59024==start;bindings.append(dict(slot=slot,**f))
 code=b[start+0x37000:end+0x37000];ins={i.address:i for i in md.disasm(code,start)};proof.append(dict(start=hex(start),sha256=hashlib.sha256(code).hexdigest()))
 for value in range(256):
  m=CreatureReplay(ins,b'');m.regs['esp']=0x700000;m.writemem(0x700004,4,0x300000);m.writemem(0x30002c,4,0x400000);m.writemem(0x400000+field,1,value);m.execute(start,end-1);assert m.regs['eax']==value;cases+=1
 m.mem[0x400000:0x400000+60]=t;m.execute(start,end-1);assert m.regs['eax']==t[field]
a.out.write_text(json.dumps(dict(executable_sha256=hashlib.sha256(b).hexdigest(),archive_sha256=hashlib.sha256(archive).hexdigest(),bindings=bindings,code=proof,cases=cases,template=dict(index=19,file_offset=entry['offset']+offset,raw_hex=t.hex(),height=59,coefficient=200),scope='512 isolated native getter replays plus original template19. Constructor literal/vtable relocations pinned. B2E6D..B2E89 multiplies this coefficient by its retained height then divides by256 in fluid handling; full fluid caller, bobbing, motion and placement remain untraced, so no exact floating-depth or earned ride claim.'),indent=1)+'\n')
print('PASS512 assembly getter cases; original table19 height59/coefficient200; full buoyancy not replayed')
