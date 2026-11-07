#!/usr/bin/env python3
"""Replay handler93 request routing with explicit external-call boundaries."""
import argparse,hashlib,json,struct
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
b=(a.game/'LOLG.DAT').read_bytes();assert hashlib.sha256(b).hexdigest()=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
code=b[0x9af08+0x37000:0x9afb6+0x37000];md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True;ins={i.address:i for i in md.disasm(code,0x9af08)};stops={i.address for i in ins.values() if i.mnemonic in ['call','ret']}
def run(mode,target_kind,allocated,status):
 m=CreatureReplay(ins,b'');m.regs['esp']=0x700000
 for addr,size,value in [(0x700008,4,0x300000),(0x300000,1,mode),(0x96904,4,0x310000),(0x310000,4,0x320000),(0x32012c,4,98),(0x22cf4,4,0x400000),(0x400000+98*91+24,4,0xf38dcc87),(0x23c57,4,0x500000),(0x500000,4,0x1234),(0x610052,1,target_kind),(0x610046,4,0x620000),(0xdf660,4,0x640000),(0x22712,1,status)]:m.writemem(addr,size,value)
 pc=0x9af08;calls=[]
 while True:
  pc=m.execute(pc,stops);i=ins[pc]
  if i.mnemonic=='ret':break
  callee=m.get(i,i.operands[0]);argc={0x9eb5c:2,0x77acc:2,0xe11c8:2,0xa1864:2,0x10bb28:4}[callee];args=[m.readmem(m.regs['esp']+4*k,4) for k in range(argc)];calls.append(dict(callee=hex(callee),args=args))
  expected={0x9eb5c:[0x22cd8,0xf38dcc87],0x77acc:[0x23348,0x500000],0xe11c8:[0x227a4,0x3000000],0xa1864:[0x640000,106],0x10bb28:[0x630000,0x22574,0 if target_kind in [0,3] else 0x620000,0]}[callee];assert args==expected
  m.regs['eax']={0x9eb5c:0x600000,0x77acc:0,0xe11c8:0 if target_kind==0 else 0x610000,0xa1864:0x630000 if allocated else 0,0x10bb28:0}[callee]
  pc+=i.size
 assert m.regs['eax']==(1 if mode==1 else 0)
 assert m.readmem(0x22712,1)==(status|128 if mode==1 else status)
 assert m.readmem(0x500000,4)==(0x600000 if mode==1 else 0x1234)
 assert len(calls)==(5 if allocated else 4) if mode==1 else not calls
 return calls
for mode in range(256):
 if mode!=1:run(mode,0,False,42)
examples=[]
for kind in [0,3,4]:
 for allocated in [False,True]:
  for status in range(256):
   calls=run(1,kind,allocated,status)
   if status==0:examples.append(dict(target_kind=kind,allocated=allocated,calls=calls))
# Isolate the effect's packet producer; target callback is deliberately a boundary.
packet_code=b[0x10bf40+0x37000:0x10bfe0+0x37000]
packet_ins={i.address:i for i in md.disasm(packet_code,0x10bf40)}
packet_cases=[]
for variant in [0,1,0xffffffff]:
 m=CreatureReplay(packet_ins,b'');m.regs['esp']=0x700000;m.regs['ebx']=0x300000
 for addr,value in [(0x30003e,0x310000),(0x300042,0x320000),(0x300066,variant),(0x320028,0x330000),(0x330080,0x340000)]:m.writemem(addr,4,value)
 pc=0x10bf40;packets=[]
 while True:
  pc=m.execute(pc,{0x10bf8f,0x10bfd7,0x10bfe0})
  if pc==0x10bfe0:break
  i=packet_ins[pc];assert m.get(i,i.operands[0])==0x340000
  assert m.readmem(m.regs['esp'],4)==0x320000
  ptr=m.readmem(m.regs['esp']+4,4)
  packet=dict(kind=m.readmem(ptr,2),selector=m.readmem(ptr+2,2),value=m.readmem(ptr+22,4))
  assert m.readmem(ptr+4,4)==0x320000 and m.readmem(ptr+8,4)==0x310000
  assert m.readmem(ptr+16,4)==0x300000 and m.readmem(ptr+20,1)==1 and m.readmem(ptr+21,1)==80
  packets.append(packet);m.regs['eax']=0;pc+=i.size
 assert packets==([dict(kind=1,selector=1,value=80),dict(kind=256,selector=4,value=20)] if variant==0 else [dict(kind=1,selector=1,value=15)])
 packet_cases.append(dict(constructor_variant=variant,packets=packets))
a.out.write_text(json.dumps(dict(executable_sha256=hashlib.sha256(b).hexdigest(),handler=93,span=['0x9af08','0x9afb6'],code_sha256=hashlib.sha256(code).hexdigest(),refused_requests=255,use_cases=1536,examples=examples,packet_cases=packet_cases,packet_code_sha256=hashlib.sha256(packet_code).hexdigest(),scope='Native handler instructions replayed; 9EB5C/77ACC/E11C8/A1864/10BB28 results supplied at explicit boundaries. Proves request1 routing, slot write, target selection, allocator argument106, status bit0x80 and return1 even allocation failure. Separate10BF40..10BFDD packet producer replay proves requests80/20 for constructor variant0, not HP damage; target callback remains a boundary. Replacement fixture uses original empty98 mapping from verify_globe_replacement.py. Does not prove effect motion or damage; not campaign seeding or a hosted item implementation.'),indent=1)+'\n')
print('PASS255 refused request bytes +1536 handler93 boundary cases +3 effect-packet cases; damage callback remains unverified')
