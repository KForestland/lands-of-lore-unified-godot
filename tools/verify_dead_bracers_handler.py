#!/usr/bin/env python3
"""Replay all request bytes through the pinned native dead-bracers handler."""
import hashlib,json,struct
from pathlib import Path
import sys
import re_helper_root
re_helper_root.insert('draracle')
import argparse
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
import capstone
from verify_creature_states import CreatureReplay
blob=(a.game/'LOLG.DAT').read_bytes();assert hashlib.sha256(blob).hexdigest()=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
code=blob[0x99b94+0x37000:0x99beb+0x37000];cases=[]
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True
ins={i.address:i for i in md.disasm(code,0x99b94)}
for mode in range(256):
 for bank in [False,True]:
  u=CreatureReplay(ins,b'');u.regs['esp']=0x700000;u.regs['ebx']=0x12345678
  for address,size,value in [(0x26e58,4,0x300000 if bank else 0),(0x2333f,1,7),(0x300007,1,77),(0x400000,1,mode),(0x700008,4,0x400000)]:u.writemem(address,size,value)
  u.execute(0x99b94,0x99bea)
  result=u.regs['eax'];local=u.readmem(0x300007,1)
  assert result==(1 if mode==18 else 2 if mode==16 else 0)
  assert local==(1 if bank and mode==18 else 0 if bank and mode==14 else 77)
  assert u.readmem(0x26e58,4)==(0x300000 if bank else 0)
  assert u.regs['esp']==0x700000 and u.regs['ebx']==0x12345678
  cases.append(dict(mode=mode,bank=bank,before=77,after=local,result=result))
a.out.write_text(json.dumps(dict(executable_sha256=hashlib.sha256(blob).hexdigest(),code_sha256=hashlib.sha256(code).hexdigest(),cases=cases,scope='512 pinned x86 handler replays; synthetic isolated bank/pointer witnesses, not campaign seeding or native caller replay.'),indent=1)+'\n')
print('PASS 512 isolated native handler70 replays, null/live bank, pointer preserved')
