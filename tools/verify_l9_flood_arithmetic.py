#!/usr/bin/env python3
"""Isolate native opcode208 height arithmetic and opcode9/5 flag mutation."""
import argparse, hashlib, json, struct
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay
from verify_special_pixel_table_binding import fixups
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
b=(a.game/'LOLG.DAT').read_bytes()
assert hashlib.sha256(b).hexdigest()=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True
spans=[(0xb520d,0xb52ee),(0x655c2,0x65810)]
ins={};proof=[]
for start,end in spans:
 code=b[start+0x37000:end+0x37000];ins.update({i.address:i for i in md.disasm(code,start)});proof.append(dict(start=hex(start),end=hex(end),sha256=hashlib.sha256(code).hexdigest()))
le=0x39024+struct.unpack_from('<I',b,0x39060)[0];slot=0x5c010+5*4
binding=fixups(b,le,1+slot//4096)[slot%4096]
assert binding['target_object']==2 and binding['target_offset']+0x59024==0xb520d
for flag in range(256):
 u=CreatureReplay(ins,b'');u.regs['ebx']=0x300000;u.regs['esp']=0x700000
 # Keep native 0x200 spatial relink path off: that callback is outside this witness.
 before=(flag<<16)|0x80;u.writemem(0x300014,4,before)
 u.execute(0xb520d,0xb52e9)
 assert u.readmem(0x300014,4)==before|0x100 and u.regs['eax']==1
cases=[]
for rate,target in [(3,70),(10,400)]:
 for elapsed in [6,20,60]:
  rise=rate*elapsed//60
  if rise==0:continue
  for floor in [0,59,69,70,399,400]:
   u=CreatureReplay(ins,b'');u.regs['esp']=0x700000
   for addr,size,value in [(0x700048,4,0x400000),(0x400002,2,0),(0x400005,1,rate),(0x400006,2,target),(0x22d0c,4,0x300000),(0x22d10,4,0x500000),(0x2b534,4,1),(0xbbb4,4,elapsed),(0x500000,2,0),(0x500017,1,1),(0x300014,2,floor),(0x300016,2,500),(0x300018,2,0),(0x300020,1,59),(0x300027,1,10)]:u.writemem(addr,size,value)
   pc=0x655c2;calls=[];stops={x for x,i in ins.items() if i.mnemonic=='call'}|{0x65810}
   for _ in range(10):
    pc=u.execute(pc,stops)
    if pc==0x65810:break
    i=ins[pc];callee=u.get(i,i.operands[0]);assert callee==0xf3a5c
    calls.append(hex(callee));pc+=i.size # observation-only callback boundary; no callback effects claimed
   else:raise AssertionError('arithmetic failed to finish')
   expected=floor+rise if floor+rise<=target else floor
   assert u.readmem(0x300014,2)==expected,(rate,target,elapsed,floor,expected,u.readmem(0x300014,2))
   assert u.readmem(0x300027,1)==(min(255,10+rise) if expected!=floor else 10)
   cases.append(dict(rate=rate,target=target,elapsed_ticks=elapsed,before=floor,after=expected,callbacks=calls))
a.out.write_text(json.dumps(dict(executable_sha256=hashlib.sha256(b).hexdigest(),spans=proof,arm5_binding=binding,arm5_cases=256,height_cases=cases,scope='Isolated synthetic arithmetic witnesses, not campaign seeds. Arm5 sets object flag0x100; 0x200 relinking branch excluded. Opcode208 starts after timer setup with supplied ticks; same-preset, one-region descriptor, callback F3A5C observed but not executed. Does not prove full water propagation, clock or floating physics.'),indent=1)+'\n')
print(f'PASS256 native arm5 flag cases; {len(cases)} opcode208 height arithmetic cases; callbacks excluded')
