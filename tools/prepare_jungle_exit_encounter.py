#!/usr/bin/env python3
"""Stage the Huline Jungle exit encounter (guards58-60, prop4398 endings) as a numeric source contract.

Every command group used by scripts/lol2/jungle_exit_encounter_state.gd is pinned byte for byte
against the hash-checked L4_HJ archive. Predicates are decoded with the native 0x66AB0 operator and
operand tables. Movie indices resolve through the opcode21 name table (index26 = e125e reproduces
the verified departure binding). Timer countdown words are 1/60 s ticks: each equals its range
maximum x60 (900 = 15x60), the scale used by the verified prop68/110 timer cases.
The prop552 kind5 group10720 (guard spawn) has no established producer; it is exposed as a
supplied trigger only.
"""
import hashlib,json,struct,sys
from pathlib import Path
from build_game_atlas import parse_mix,section,u32
from audit_game_actor_scripts import groups
from audit_game_transition_owners import GAME,collect_owners
import re_helper_root; re_helper_root.insert('draracle', 'tools')  # LOL2_RE_ROOT
from verify_special_pixel_table_binding import fixups
from lol2.map_video_inventory import lookup_movie
ROOT=Path(__file__).resolve().parents[1]
EXE_HASH='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
OPS={0:'==',1:'!=',2:'<=',3:'>=',4:'>',5:'<',6:'AND',7:'OR'}
GROUPS={
    (0,17748):('region',4437,138,'c60000003501 c60000002a01'),
    (0,17646):('region',4435,28,'09035d0b0200 090328020200 c60000002a02 10032e110100'),
    (0,17850):('region',4439,67,'c60000003802 09023a001100 09023c001100 09023b001100 091036000200 091035000200 091034000200'),
    (0,17922):('region',4442,29,'09023b001500 c60000002a03'),
    (0,18054):('region',4450,30,'0e023a0004000100 09032e111500'),
    (1,10720):('prop',552,182,'c60000003801 020100002500 091036000300 091035000300 091034000300 09023a000300 09023c000300 09023b000300 c60000000105 09032a020200 050328020100 0803280200000000 080328020700ff00 080328020a000400'),
    (1,28242):('actor',58,206,'0e023a0004000000 10032e110100 0d023a0006000000 0d023a000a000000 08023a0001000000 0d023a00040c0000 08023a0000000000 08023a0002000000'),
    (1,28310):('actor',58,206,'08023a0001000000 0d023a000d000000 0d023a0007000000 0e023a0003000100'),
    (1,28348):('actor',58,2,'0e023a0004000100 09032e111500'),
    (1,28376):('actor',58,54,'10032e110100 090328020200 09035d0b0200 c60000002a03 09023b001500'),
    (1,28606):('actor',59,54,'10032e110100 090328020200 09035d0b0200 c60000002a03 09023b001500'),
    (1,28884):('actor',60,54,'10032e110100 090328020200 09035d0b0200 c60000002a03 09023b001500'),
    (1,28412):('actor',58,None,'cf0000003001 10023a000a00 0e023a0003000100'),
    (1,28642):('actor',59,None,'cf0000003001'),
    (1,28920):('actor',60,None,'cf0000003001'),
    (1,28438):('actor',59,206,'0903c6000300 0903c5000300 0903c8000300 0903c7000300 d20000000a1e 10023b000100 0d023b0006000000 0d023b000a000000 08023b0001000000 0d023b0004080000 08023b0000000000 08023b0002000000'),
    (1,28528):('actor',59,207,'0e023a0003000000 08023b0001000000 0d023a0007000000 0d023c0007000000 0d023b0007000000 0d023a000d000000 0d023c000d000000 0d023b000d000000'),
    (1,16986):('prop',4398,50,'020100002400 c6000000300a 090328121500 15032e112100 020100004200 c60000002a05 0903c5000200 0903c8000200 0903c7000200 0903c6000200 09023d000200 12010000b715520f00000408eece000a0000'),
    (1,17076):('prop',4398,51,'020100002400 c6000000300a 090328121500 15032e113800 020100004200 09023d000200 09023b000200 09023a000200 09023c000200 12010000bb15520f00000408eece000a0000 020100000100'),
    (1,17160):('prop',4398,52,'020100002400 c6000000300a 090328121500 15032e113900 020100004200 c60000002a05 0903c5000200 0903c8000200 0903c7000200 0903c6000200 09023d000200 09023b000200 09023a000200 09023c000200 12010000b715520f00000408eece000a0000'),
}
TIMERS={58:['0a02526e30010f008403','0a02bc6e30010f008403']}
ENDINGS=[(50,16986),(51,17076),(52,17160)]

def predicate(table,n):
    r=table[n*5:n*5+5]
    def operand(kind,index):
        if kind==4:return dict(predicate=index,expression=predicate(table,index))
        return {0:dict(immediate=index),2:dict(shared=index),3:dict(local=index),5:dict(owner_state=True)}[kind]
    return dict(op=OPS[r[0]],left=operand(r[1],r[2]),right=operand(r[3],r[4]),raw=r.hex())

def main():
    inventory=json.loads((ROOT/'docs/game-source-inventory.json').read_text())
    area=next(a for a in inventory['areas'] if a['id']=='L4_HJ')
    archive=(GAME/area['source']['file']).read_bytes();assert hashlib.sha256(archive).hexdigest()==area['source']['sha256']
    entry=next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key'])
    raw=archive[entry['offset']:entry['offset']+entry['size']];assert hashlib.sha256(raw).hexdigest()==area['source']['geometry_sha256']
    owners,_=collect_owners(raw,entry['offset'],area['counts']['regions'])
    parsed={}
    for stream,(of,sf) in enumerate([(0x3c,0x84),(0x44,0x8c)]):
        _,_,blob=section(raw,of,sf,1)
        for group,commands in groups(blob):parsed[(stream,group)]=[body.hex() for _,body in commands]
    _,_,table=section(raw,0xbc,0xb8,5)
    group_rows=[]
    for (stream,group),(kind,owner,pred,expected) in GROUPS.items():
        assert parsed[(stream,group)]==expected.split(),(stream,group)
        match=[o for o in owners if o['stream']==stream and o['group']==group and o['owner_kind']==kind and o['owner']==owner]
        assert len(match)==1 and match[0]['predicate']==pred,(group,match)
        group_rows.append(dict(stream=stream,group=group,owner_kind=kind,owner=owner,record=match[0]['event'],value=match[0]['value'],predicate=pred,commands=expected.split()))
    predicates={str(p):predicate(table,p) for p in sorted({r['predicate'] for r in group_rows if r['predicate'] is not None}|{46})}
    _,_,actors=section(raw,0x1c,0x68,56);_,_,events=section(raw,0x40,0x88,1)
    actor_rows=[];names={a['actor']:a for a in next(x for x in json.loads((ROOT/'docs/game-actors.json').read_text())['areas'] if x['id']=='L4_HJ')['actors']}
    for i in (58,59,60,61):
        r=actors[i*56:(i+1)*56];x,z,h,y=struct.unpack_from('<hhHh',r,0);flags=struct.unpack_from('<H',r,8)[0]
        actor_rows.append(dict(actor=i,name=names[i]['name'],definition=names[i]['definition'],position=[x,y,-z],heading=h,health=struct.unpack_from('<H',r,30)[0],behavior=r[37],flags=flags,present=not flags&0x1000))
    timers=[]
    for actor,records in TIMERS.items():
        r=actors[actor*56:(actor+1)*56];offset=struct.unpack_from('<H',r,12)[0];found=[]
        cursor=offset
        while events[cursor] and events[cursor+1]:
            length=events[cursor]
            if events[cursor+1]==2:found.append(events[cursor:cursor+length].hex())
            cursor+=length
        assert found==records,(actor,found)
        for ordinal,record in enumerate(records):
            b=bytes.fromhex(record);assert b[5]&1 and b[7]*60==0 and b[6]*60==struct.unpack_from('<H',b,8)[0]
            timers.append(dict(actor=actor,ordinal=ordinal,group=struct.unpack_from('<H',b,2)[0],flags=b[5],range=[b[7],b[6]],countdown=struct.unpack_from('<H',b,8)[0],raw=record))
    exe=(GAME/'LOLG.DAT').read_bytes();assert hashlib.sha256(exe).hexdigest()==EXE_HASH
    le=0x39024+u32(exe,0x39060);ot=le+u32(exe,le+0x40);first=u32(exe,ot+108)
    def movie_name(index):
        slot=0xe568+index*4;rel=fixups(exe,le,first-1+slot//4096)[slot%4096];assert rel['target_object']==5
        return exe[0x1c1024+rel['target_offset']:].split(b'\0')[0].decode()
    assert movie_name(26)=='e125e'
    endings=[]
    for pred,group in ENDINGS:
        commands=[bytes.fromhex(c) for c in GROUPS[(1,group)][3].split()]
        movie=next(c for c in commands if c[0]==21);index=movie[4]
        name=movie_name(index);found=lookup_movie(GAME,'L4_HJ',name.upper()+'.VQA');assert found['status']=='exact'
        move=next(c for c in commands if c[0]==18);mx,mz,my=struct.unpack_from('<hhh',move,4)
        endings.append(dict(predicate=pred,group=group,movie_index=index,movie=name.upper()+'.VQA',movie_archive=found['archive'],movie_sha256=found['sha256'],
            player_position=[mx,my,-mz],player_move_raw=move.hex(),removes=[struct.unpack_from('<H',c,2)[0] for c in commands if c[0]==9 and c[1]==2 and c[4]==2],
            sets_local42_5=any(c.hex()=='c60000002a05' for c in commands)))
    geometry=json.loads(Path('/home/bob/lol2_out/all_maps_20260922/L4_HJ/geometry/geometry.json').read_text())
    regions=[]
    for index in (4437,4435,4439,4442,4450):
        reg=geometry['regions'][index];assert reg['id']==index
        regions.append(dict(region=index,polygon=[[geometry['vertices_fixed'][v][0]/65536,-geometry['vertices_fixed'][v][1]/65536] for v in reg['vertex_indices']],floor_min=min(reg['floor_corners']),floor_max=max(reg['floor_corners'])))
    _,_,props=section(raw,0x14,0x60,37)
    prop=props[552*37:553*37];px,pz,heading,py=struct.unpack_from('<hhHh',prop)
    assert (px,pz,py)==(3592,4145,-15)
    ga=(GAME/'GLOBAL.MIX').read_bytes();ge=next(e for e in parse_mix(ga) if e['key']==3984507021)
    globals_blob=ga[ge['offset']:ge['offset']+ge['size']]
    assert hashlib.sha256(globals_blob).hexdigest()=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    shared_names={}
    for n in [13,14,18,47]:
        off=u32(globals_blob,0x64)+u32(globals_blob,0x60)+n*41
        shared_names[str(n)]=globals_blob[off:off+41].split(b'\0')[0].decode()
    assert shared_names=={'13':'GV_BACATTA_RELATIONSHIP','14':'GV_RUNES_TRANSLATED','18':'GV_MET_BACATTA','47':'GV_LUTHER_KNOWS_ABOUT_DANIEL'}
    result=dict(version=1,source=area['source'],executable_sha256=EXE_HASH,actors=actor_rows,regions=regions,predicates=predicates,groups=group_rows,timers=timers,endings=endings,
        prop552=dict(position=[px,py,-pz],flags=struct.unpack_from('<H',prop,8)[0],present=not struct.unpack_from('<H',prop,8)[0]&0x1000,raw=prop.hex()),shared_names=shared_names,tick_rate=60,owned_locals=[42,48,53,56],supplied=dict(shared=[13,14,18,47],locals=[41,49,51]),
        unresolved=['prop552 kind5 group10720 producer (guard spawn) — supplied trigger only','kind9 hit acceptance rules','actor event0 (scripted pose endpoint) and event10 (counted defeat) producers','op9 property17 (region4439) and op13 subcommand10 meaning','opcode21 movie option byte / playback timing','guard60/Bacatta61 branch (event20 from Bacatta groups) not staged'])
    out=ROOT/'scripts/lol2/jungle_exit_encounter_source.json';out.write_text(json.dumps(result,indent=1)+'\n')
    print('PASS: %d groups pinned, %d predicates, %d timers, endings %s'%(len(group_rows),len(predicates),len(timers),[(e['movie_index'],e['movie']) for e in endings]))
if __name__=='__main__':main()
