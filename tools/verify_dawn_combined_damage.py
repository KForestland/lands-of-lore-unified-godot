#!/usr/bin/env python3
"""Replay original combined-mask Dawn chain/Plasma calculation; caller inputs explicit."""
import hashlib,itertools,json
from pathlib import Path
from verify_hive_damage_calculation import NativeDamage
from verify_player_item_effects import load,GAME,EXE_HASH
ROOT=Path(__file__).resolve().parents[1]
def main():
    exe=(GAME/'LOLG.DAT').read_bytes();assert hashlib.sha256(exe).hexdigest()==EXE_HASH
    native=NativeDamage();m=native.m;proof=[]
    for a,z in [(0xa6aa8,0xa6aca),(0xd8a10,0xd8a1b)]:proof.append(dict(start=a,end=z,sha256=load(exe,m.instructions,a,z)))
    raw=m.execute;returns={a for a,i in m.instructions.items() if i.mnemonic=='ret'};getters={0x629e8:0xa6aa8,0x62a05:0xd8a10};environmental=False
    def execute(start,stops):
        if start==0x62922:m.writemem(m.regs['esp']+0x20,4,int(environmental))
        stops={stops} if isinstance(stops,int) else set(stops)
        while True:
            pc=raw(start,stops|set(getters))
            if pc not in getters or pc in stops:return pc
            m.regs['esp']-=4;m.writemem(m.regs['esp'],4,pc+6)
            raw(getters[pc],returns);m.regs['esp']+=4;start=pc+6
    m.execute=execute
    descriptors=[[],[[(5,1,1)]],[[(5,16,1)]],[[(7,1,1)]],[[(7,16,1)]],[[(8,17,1)]],[[(9,1,1),(5,16,1)]],[[(6,0,0)]],[[(2,16,1)]],[[(7,1,1)],[(9,16,1)]]]
    cases=[]
    for tag,level,scalar,pair,environmental,desc,current in itertools.product([58,84],[1,10,30],[0,64,128],[(3,1),(10,1),(20,1),(3,9),(11,9),(22,9)],[False,True],descriptors,[0,1000]):
        amount,signature=pair
        m.writemem(0x440000+0x2c,4,0x450000);m.writemem(0x450000+0x83,1,10);m.writemem(0x22574+0x162,1,level)
        result=native.calculate(amount,scalar,signature,current,desc,damage_mask=17,request_kind=2,request_tag=tag)
        context=dict(amount=amount,scalar=scalar,signature=signature,current=current,descriptors=desc,damage_mask=17,request_kind=2,request_tag=tag,caster_factor=10,player_magic_level=level,environmental=environmental)
        cases.append(dict(context=context,expected=result))
    (ROOT/'tests/fixtures/dawn_combined_damage_native.json').write_text(json.dumps(cases,separators=(',',':'))+'\n')
    report=dict(passed=True,cases=len(cases),executable_sha256=EXE_HASH,code=native.proof+proof,limits=['Actual original62922 calculation and original caster/player factor getters; CALL/RET bridge only.','Environmental local20 supplied explicitly (false/true); its world producer not executed.','Adjusted amount/signature, equipment scalar/descriptors and current health supplied.','Final attacker callback, target receiver/health owner, and effects lifecycle outside replay.'])
    (ROOT/'docs/dawn-combined-damage-checks.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS:',len(cases),'native combined-mask calculation cases')
if __name__=='__main__':main()
