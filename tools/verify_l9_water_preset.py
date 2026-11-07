#!/usr/bin/env python3
import hashlib,json,sys,struct
from pathlib import Path
sys.path.insert(0,'tools');import re_helper_root;re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay
from verify_actor_item_grants import parse_mix
import argparse
p=argparse.ArgumentParser(description='Replay the original floor-preset setter up to its collision callback.');p.add_argument('--game',type=Path,required=True);p.add_argument('--out',type=Path,required=True);args=p.parse_args()
root=args.game;exe=(root/'LOLG.DAT').read_bytes();assert hashlib.sha256(exe).hexdigest()=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
a=(root/'DAT/L9_DR.MIX').read_bytes();assert hashlib.sha256(a).hexdigest()=='700300d0cdf7df0af9471f3476c4e6ba473a603fa89e3a6e1855037d70be09c7';e=parse_mix(a)[0];m=a[e['offset']:e['offset']+e['size']];start=struct.unpack_from('<I',m,4)[0];count=struct.unpack_from('<I',m,0x3c)[0];names=start+count*24
code=exe[0xf44cc+0x37000:0xf44f7+0x37000];md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True;ins={i.address:i for i in md.disasm(code,0xf44cc)}
for k in range(count):
 u=CreatureReplay(ins,b'');u.regs['esp']=0x700000
 for addr,size,value in [(0x700004,4,0x300000),(0x700008,4,k),(0x22d44,4,0x400000),(0x400000+k*24+21,1,m[start+k*24+21])]:u.writemem(addr,size,value)
 u.execute(0xf44cc,0xf44f7)
 assert u.readmem(0x300020,1)==k and u.readmem(0x300027,1)==m[start+k*24+21]
 assert [u.readmem(u.regs['esp']+i*4,4) for i in range(3)]==[0x300000,0,1]
k=59;row=m[start+k*24:start+(k+1)*24];name=m[names+k*22:names+(k+1)*22].split(b'\0')[0].decode();assert name=='Shallow North'
args.out.write_text(json.dumps(dict(archive_sha256=hashlib.sha256(a).hexdigest(),executable_sha256=hashlib.sha256(exe).hexdigest(),code_sha256=hashlib.sha256(code).hexdigest(),span=['0xf44cc','0xf44f7'],cases=count,preset=dict(index=k,name=name,raw_hex=row.hex(),source_offset=e['offset']+start+k*24),scope='Native prefix writes region+0x20 selector and region+0x27 preset byte21; stops before B861C call. Later collision callbacks, damage and motion not replayed.'),indent=1)+'\n')
print('PASS64 native preset-prefix replays; actual59 Shallow North; B861C not replayed')
