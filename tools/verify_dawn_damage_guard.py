#!/usr/bin/env python3
"""Identify and replay the player timer that suppresses directional damage bonus."""
import hashlib,json
from pathlib import Path
from verify_player_item_effects import GAME,EXE_HASH,DEFINITIONS_SHA,load,machine,parse_mix
from verify_hive_executioner import u32,fixups
ROOT=Path(__file__).resolve().parents[1]
def main():
    exe=(GAME/'LOLG.DAT').read_bytes();assert hashlib.sha256(exe).hexdigest()==EXE_HASH
    archive=(GAME/'GLOBAL.MIX').read_bytes();entry=next(e for e in parse_mix(archive) if e['key']==3984507021)
    blob=archive[entry['offset']:entry['offset']+entry['size']];assert hashlib.sha256(blob).hexdigest()==DEFINITIONS_SHA
    base,count=u32(blob,4),u32(blob,0x34);names=base+count*91+4;names+=u32(blob,names-4)*16+4;names+=u32(blob,names-4)*12
    owners=[]
    for i in range(count):
        row=blob[base+i*91:base+(i+1)*91]
        if row[0x42]==86:owners.append(dict(index=i,name=blob[names+i*30:names+i*30+24].split(b'\0')[0].decode('latin1'),identity=u32(row,24)))
    assert owners==[dict(index=115,name='113-Brook flou',identity=0x2408d7)]
    le=0x39024+u32(exe,0x39060);first=u32(exe,le+u32(exe,le+0x40)+108);slot=0xc860+86*4
    relocation=fixups(exe,le,first-1+slot//4096)[slot%4096]
    assert relocation['target_object']==2 and relocation['target_offset']+0x59024==0x9a9b4
    ins={};spans={}
    for name,a,z in [('initial',0xcfc3c,0xcfc46),('extend',0xdb818,0xdb85b),('tick',0xd33fc,0xd3440),('caller',0x9aa62,0x9aa6f),('gate',0x627b9,0x627c0)]:spans[name]=dict(start=a,end=z,sha256=load(exe,ins,a,z))
    assert ins[0x9aa62].op_str=='0x22574' and ins[0x9aa67].op_str=='0xdb818'
    assert '0x2276a' in ins[0x627b9].op_str and 0x22574+0x1f6==0x2276a
    player=0x22574
    timers=[0,1,65535,65536,0x12345678,0x7fffffff,0x80000000,0xffff0000,0xffffffff]
    extend=[];ticks=[]
    for timer in timers:
        for flags,counter in [(0,0),(0xef,255),(255,7)]:
            m=machine(ins);m.writemem(m.regs['esp']+4,4,player)
            for a,n,v in [(0x2276a,4,timer),(0x23ab6,1,flags),(0x22798,1,counter),(0x23bd9,4,123)]:m.writemem(a,n,v)
            assert m.execute(0xdb818,0xdb85a)==0xdb85a
            expected=(timer&65535)|(((((timer>>16)+3600)&65535))<<16)
            assert m.readmem(0x2276a,4)==expected
            assert m.readmem(0x23ab6,1)==(flags|16 if timer==0 else flags)
            assert m.readmem(0x22798,1)==((counter+1)&255 if timer==0 else counter)
            assert m.readmem(0x23bd9,4)==(0 if timer==0 else 123)
            extend.append(dict(timer=timer,flags=flags,counter=counter,after=expected))
        for delta in [0,1,65536,0x7fffffff,0xffffffff]:
            m=machine(ins);m.regs['ebx']=player;m.writemem(0x2276a,4,timer);m.writemem(0x22c54,4,delta)
            pc=0xd33fc;calls=[]
            while True:
                pc=m.execute(pc,{0xd342b,0xd3438,0xd3440})
                if pc==0xd3440:break
                assert m.readmem(m.regs['esp'],4)==0x23819
                calls.append(ins[pc].op_str);pc+=ins[pc].size
            raw=(timer-delta)&0xffffffff;expired=timer!=0 and (raw==0 or raw>=0x80000000)
            expected=0 if timer==0 or expired else raw
            assert m.readmem(0x2276a,4)==expected
            assert calls==(['0x82d5c','0x82db8'] if expired else [])
            ticks.append(dict(timer=timer,delta=delta,after=expected,callbacks=calls))
    m=machine(ins);m.regs['ebx']=player;m.writemem(0x2276a,4,123);m.execute(0xcfc3c,0xcfc46);assert m.readmem(0x2276a,4)==0
    report=dict(passed=True,executable_sha256=EXE_HASH,definitions_sha256=DEFINITIONS_SHA,owners=owners,handler=86,relocation=relocation,spans=spans,extension_cases=extend,tick_cases=ticks,initial_zero=True,limits=['Actual original instructions replayed; expiry UI callbacks intercepted at their call boundaries.','Directional guard is player+1F6, not inferred pause/equipment state.','No claim about full item-use admission, availability in Act1, UI callback contents, or live shared-clock binding.'])
    (ROOT/'docs/dawn-damage-guard-checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'PASS: Brook flower handler86 guard timer; {len(extend)} extensions, {len(ticks)} ticks, initial zero and ordered callback boundaries.')
if __name__=='__main__':main()
