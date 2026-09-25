#!/usr/bin/env python3
"""Check the exact opcode9/subcommand10 bit update used by Rashar's entrance."""
import json,struct
from audit_hive_rune_rooms import ROOT,GAME,digest,fixups,u32,capstone
from verify_creature_states import CreatureReplay

def main():
 exe=(GAME/'LOLG.DAT').read_bytes();assert digest(exe)=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
 le=0x39024+u32(exe,0x39060);bindings=[]
 for address,target in [(0x5c878+8*4,0xb59b3),(0x5c010+10*4,0xb5393)]:
  r=fixups(exe,le,1+address//4096)[address%4096];assert r['target_object']==2 and r['target_offset']+0x59024==target
  bindings.append(dict(address=address,target=target,relocation=r))
 cs=capstone.Cs(3,4);cs.detail=True
 code=exe[0xb5393+0x37000:0xb53a1+0x37000];ins={i.address:i for i in cs.disasm(code,0xb5393)}
 m=CreatureReplay(ins,b'');obj=0x400000;stack=0x410000;cases=[]
 for value in range(256):
  m.writemem(obj+0x14,4,0xa50000ff|(value<<16));m.regs.update(ebx=obj,esp=stack)
  m.execute(0xb5393,0xb53a0)
  result=m.readmem(obj+0x14,4);assert result==(0xa50000ff|(value<<16))&~0x20000
  assert m.regs['eax']==1 and m.regs['esp']==stack+16
  cases.append(dict(before=value,after=(result>>16)&255))
 audit=json.loads((ROOT/'docs/act-one-shops-source.json').read_text());entry=next(r for r in audit['entrances'] if r['room']=='magic_')
 commands=[bytes.fromhex(c) for c in entry['commands'] if c.startswith('09')]
 targets=[dict(kind=c[1],selector=int.from_bytes(c[2:4],'little'),subcommand=c[4]) for c in commands]
 assert targets==[dict(kind=3,selector=x,subcommand=10) for x in [484,485,428]]+[dict(kind=16,selector=100,subcommand=10),dict(kind=3,selector=429,subcommand=10)]
 report=dict(passed=True,executable_sha256=digest(exe),code_sha256=digest(code),bindings=bindings,cases=cases,targets=targets,scope='256 native subcommand10 byte updates, preserving adjacent bytes; source MAGIC entry commands verified. Object resolver results are not supplied here and selector100/kind16 is not assumed to be a literal prop index. Clears flags bit0x20000; visibility/collision meaning and resolved owners remain separate before live integration.')
 (ROOT/'docs/magic-shop-entry-flags-checks.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS256 source entry flag updates;five source target requests')
if __name__=='__main__':main()
