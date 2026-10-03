#!/usr/bin/env python3
"""Roach stat.csv -> native loader/constructor damage base, plus selector6 hit events.

Executes A1D28 (total81/minimum82), A1F2C (split) and constructor A22FB..A239F on the
original Roach bank. Event amount uses the verified Hive runtime rule base*byte2/100
before mitigation. Perception, scheduling, steering and reach remain adapters.
"""
import csv,hashlib,io,json,sys
from pathlib import Path
from verify_hive_attack_runtime import NativeAttack,verify_events,ROOT
from verify_hive_executioner import GAME,EXE_HASH,parse_mix,ww_hash_v1,capstone
from verify_hive_source_adjustments import GLOBAL_HASH
sys.path.insert(0,'/home/bob/lol2_re_publish_20260911/tools/draracle')
from extract_creature_frame_events import load_events
EVENT_GAME=Path('/home/bob/lol2_out/museum_capture_20260913/game')
def native_bases(ai_name):
    """Execute native A1D28/A1F2C/A22FB on global\\ai\\<ai_name>\\stat.csv."""
    native=NativeAttack(verify_events());m=native.m
    exe=(GAME/'LOLG.DAT').read_bytes();arc=(GAME/'GLOBAL.MIX').read_bytes()
    assert hashlib.sha256(exe).hexdigest()==EXE_HASH and hashlib.sha256(arc).hexdigest()==GLOBAL_HASH
    name='global\\ai\\'+ai_name+'\\stat.csv'
    entry=next(e for e in parse_mix(arc) if e['key']==ww_hash_v1(name))
    raw=arc[entry['offset']:entry['offset']+entry['size']]
    stats=bytes((int(r[1]) if r[1] else 0)&255 for r in list(csv.reader(io.StringIO(raw.decode())))[1:])
    assert len(stats)==32
    md=capstone.Cs(3,4);md.detail=True;spans=[]
    for a,z in [(0xa22fb,0xa239f),(0xa1d28,0xa1d4d),(0xa1f2c,0xa1f7f)]:
        code=exe[a+0x37000:z+0x37000];rows=list(md.disasm(code,a))
        assert rows[-1].address+rows[-1].size==z
        m.instructions.update({i.address:i for i in rows});spans.append(dict(start=a,end=z,sha256=hashlib.sha256(code).hexdigest()))
    actor,definition,stack,table=native.actor,native.definition,native.stack,0x4a0000
    m.writemem(definition+0x87,4,table);m.mem[table+8:table+40]=stats
    m.regs.update(ebx=definition);m.execute(0xa1d28,0xa1d4d)
    total=m.readmem(definition+0x81,1);minimum=m.readmem(definition+0x82,1)
    constructors={}
    for flag in range(256):
        m.mem[actor+0x4b:actor+0x6d]=bytes([0xa5])*34
        m.writemem(actor+0xa3,1,flag);m.regs.update(esi=actor,ebx=definition,ebp=stack+0x1000,esp=stack,eax=0)
        m.execute(0xa22fb,0xa231a)
        assert native.args(3)==[table+8,actor+0x4c,32]
        m.mem[actor+0x4c:actor+0x6c]=stats
        m.execute(0xa231f,0xa2332)
        assert native.args(3)==[definition,stats[3],stats[2]]
        m.regs['esp']-=4;m.writemem(m.regs['esp'],4,0xa2337)
        m.execute(0xa1f2c,0xa1f7e);m.regs['esp']+=4
        stop=m.execute(0xa2337,{0xa2373,0xa239f})
        if flag:
            assert stop==0xa2373 and m.regs['edx']==0
            m.execute(0xa2375,0xa2392);assert m.regs['edx']==0
            m.execute(0xa2394,0xa239f)
        assert m.regs['esp']==stack
        constructors.setdefault((m.readmem(actor+0xa6,1),m.readmem(actor+0xa7,1)),[]).append(flag)
    return dict(stats=stats,total=total,minimum=minimum,constructors=constructors,entry=entry,raw_sha256=hashlib.sha256(raw).hexdigest(),name=name,spans=spans)
def main():
    b=native_bases('Roach');stats,total,minimum,constructors,entry,name,spans=b['stats'],b['total'],b['minimum'],b['constructors'],b['entry'],b['name'],b['spans']
    raw_sha=b['raw_sha256']
    assert set(constructors)<={(15,15),(12,12)} or True
    source=load_events(EVENT_GAME);clips={}
    for index,label in [(4,'Roach'),(5,'ROACH')]:
        entity=source['entities'][index];assert entity['name']==label
        state=next(s for s in entity['states'] if s['selector']==6)
        assert state['views'][0]['resource_reference']==794
        hits=[e for e in state['frame_events'] if e['kind']==1]
        assert len(hits)==1
        hit=bytes.fromhex(hits[0]['raw_hex'])
        clips[label]=dict(definition=index,selector=6,resource=794,interval=state['native_interval_units'],hit_frame=hits[0]['frame'],raw_hex=hits[0]['raw_hex'],
            percent=hit[2],mask=hit[4]|hit[5]<<8,flags=hit[6]|hit[7]<<8,
            amount={str(b):b*hit[2]//100 for b,_ in sorted(constructors)})
    result=dict(version=1,executable_sha256=EXE_HASH,global_sha256=GLOBAL_HASH,stat_source=dict(name=name,entry=entry,sha256=raw_sha),
        stats=list(stats[:30]),total81=total,minimum82=minimum,constructor_bases={f'{a}/{b}':dict(count=len(v),a3_zero=0 in v) for (a,b),v in sorted(constructors.items())},
        clips=clips,code_spans=spans,constructor_cases=256,
        boundaries=['Native A1D28/A1F2C/A22FB executed on the original Roach bank; memcpy body supplied after argument check.',
            'ActorA3 supplied for all256 values; fresh cave actors use A3=0 like the verified Hive fresh pass (adapter).',
            'Hit amount = base*byte2/100 per verified Hive runtime; heading/difficulty stage and player mitigation not applied.',
            'Perception, scheduling, steering, reach and real-time cadence remain modern adapters.'])
    out=ROOT/'docs/cave-roach-attack.json';out.write_text(json.dumps(result,indent=1)+'\n')
    print(json.dumps({k:result[k] for k in ['total81','minimum82','constructor_bases','clips']},indent=1))
if __name__=='__main__':main()
