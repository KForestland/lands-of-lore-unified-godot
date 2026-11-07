#!/usr/bin/env python3
"""Pin actor slot80 and replay yellow packets up to the calculation boundary, not HP damage."""
import argparse,hashlib,json,struct
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay
from verify_special_pixel_table_binding import fixups
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
b=(a.game/'LOLG.DAT').read_bytes();digest=hashlib.sha256(b).hexdigest();assert digest=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
u=lambda at:struct.unpack_from('<I',b,at)[0];le=0x39024+u(0x39060);objects=le+u(le+0x40);first=u(objects+108)
slot=0x58d0+0x80;binding=fixups(b,le,first-1+slot//4096)[slot%4096]
assert binding['target_object']==2 and binding['target_offset']+0x59024==0xa6ae0
code_offset=0xa22e1-0x59024;ctor=fixups(b,le,1+code_offset//4096)[code_offset%4096]
assert ctor['target_object']==5 and ctor['target_offset']==0x58d0
assert b[0xa22de+0x37000:0xa22e5+0x37000].hex()=='c74628d0580000'
start,end=0xa6ae0,0xa6cc3;raw=b[start+0x37000:end+0x37000];md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True;ins={i.address:i for i in md.disasm(raw,start)}
assert ins[0xa6cbe].mnemonic=='call' and ins[0xa6cbe].operands[0].imm==0x62728
checks=0;examples=[]
for mask,signature,amount in [(1,1,80),(256,4,20),(1,1,15)]:
 for hp in [0,1,100,1400,65535]:
  for factor in [0,1,10,255]:
   for scalar in [0,64,255]:
    m=CreatureReplay(ins,b'');stack,obj,packet,template=0x700000,0x300000,0x310000,0x320000;m.regs['esp']=stack
    for addr,size,value in [(stack+4,4,obj),(stack+8,4,packet),(obj+0xa8,1,0),(obj+0xb5,1,0),(obj+0x91,1,0),(obj+0xb6,1,0),(obj+0xb7,1,0),(obj+0xb4,1,0),(obj+0x70,4,0),(obj+0x88,2,hp),(obj+0x2c,4,template),(obj+0xa7,1,scalar),(template+0x83,1,factor),(packet,2,mask),(packet+2,2,signature),(packet+4,4,obj),(packet+8,4,0x22574),(packet+0x14,1,1),(packet+0x15,1,80),(packet+0x16,4,amount)]:m.writemem(addr,size,value)
    assert m.execute(start,0xa6cbe)==0xa6cbe
    args=[m.readmem(m.regs['esp']+4*i,4) for i in range(3)]
    assert args[:2]==[packet,scalar]
    assert [m.readmem(args[2]+i*4,4) for i in range(2)]==[template,0]
    assert [m.readmem(packet+o,4) for o in [0x16,0x1a,0x22,0x26]]==[amount,max(1,factor),hp,hp]
    assert m.readmem(obj+0x88,2)==hp
    checks+=1
    if hp==100 and factor==10 and scalar==64:examples.append(dict(mask=mask,signature=signature,amount=amount,hp=hp,factor=factor,scalar=scalar))
a.out.write_text(json.dumps(dict(executable_sha256=digest,slot_binding=binding,constructor_installation=ctor,code_sha256=hashlib.sha256(raw).hexdigest(),cases=checks,examples=examples,scope='Static constructor installation A22DE -> table58D0, slot80 -> A6AE0 verified by original LE relocations. Ordinary active actor prefix replayed with explicit A8/B5/91/B6/B7/B4/70 inputs; selected live target class not witnessed. Original62728 call receives packet, actor scalar and [template,NULL]. CurrentHP is copied into packet22/26; template83 factor (minimum1) into1A, request16 unchanged. Calculation, receiver completion/HP write, special-state branches, flight/effect lifecycle and status128 semantics remain unentered. No gameplay handler/earned route claim.'),indent=1)+'\n')
print('PASS',checks,'original actor receiver-prefix cases; calculation/health completion remains boundary')
