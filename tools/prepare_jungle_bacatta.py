#!/usr/bin/env python3
"""Stage the Huline Jungle Bacatta branch (prop552 → Bacatta61 → guard60 → prop4398 event20) as a numeric contract.

Every group, record, timer, path marker and media binding is read from the hash-pinned L4_HJ archive,
LOLG.DAT, the Jungle texture blob and the localized sound bank. Groups owned by the exit component
(jungle_exit_encounter_source.json) are listed as external, and the completeness check requires every
prop552/actor61/actor60 record to be either staged here or external.

Native facts used (static disassembly in docs/jungle-bacatta.md):
- kind8 walker AE510(list,value) is called only by the sound manager when a slot finishes: value = request.
- event22 is pushed by the behavior7 path follower (A3CFE) on a signed index decrease (path end).
- op9 property22 (B546A) acquires lock slot3, stores player+0x81 and halts the player; the player tick
  (D4D1E) turns/moves the player toward +0x81. Player property0x31 (D83D7) releases slot3 and clears +0x81.
- kind9 gate AE2C8: record masks vs hit-context words, byte9&7 mode table 0x55290, bit7 one-shot.
"""
import hashlib,json,struct,sys
from pathlib import Path
from build_game_atlas import parse_mix,section,u32
from audit_game_actor_scripts import groups
from audit_game_transition_owners import GAME,collect_owners,events
sys.path.insert(0,'/home/bob/lol2_re_publish_20260911/tools/draracle')
from lol2_wall_material_checkpoint import sections
from prepare_hive_wax import entry
ROOT=Path(__file__).resolve().parents[1]
EXE_HASH='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
BANK_HASH='e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6'
TEXTURE=Path('/home/bob/lol2_out/jungle_geometry_20260914/texture.bin')
GEOMETRY=Path('/home/bob/lol2_out/all_maps_20260922/L4_HJ/geometry/geometry.json')
OPS={0:'==',1:'!=',2:'<=',3:'>=',4:'>',5:'<',6:'AND',7:'OR'}
OWNED={'prop':[552,2909],'actor':[61,60],'region':[1921]}
# Groups executed by this component; everything else on these owners is exit-owned (listed below).
MINE=[3894,3926,10816,10904,10980,11026,11072,11148,11190]+list(range(11232,11737,42))+[16784,
      28932,28952,28980,29034,29076,29118,29152,29176,29200,29232,29264,29296,29328,29360,29384,
      28654,28684,28718,28762,28806,28850]
EXTERNAL={10720:'exit: prop552 kind5 value0 guard spawn (first eligible render, Codex visibility)',
          28884:'exit: guard60 kind9 hit (pred54)',28920:'exit: guard60 event10 defeat count',
          28876:'UNOWNED (reported to lead): guard60 event9 op13 subcommand16 value26; guards58/59 have the same record, not staged by the exit component'}
SOUND_REQUESTS=[3,1,4,1002,243,241,387,332]

def predicate(table,n):
    r=table[n*5:n*5+5]
    def operand(kind,index):
        if kind==4:return dict(predicate=index,expression=predicate(table,index))
        return {0:dict(immediate=index),2:dict(shared=index),3:dict(local=index),5:dict(owner_state=True)}[kind]
    return dict(op=OPS[r[0]],left=operand(r[1],r[2]),right=operand(r[3],r[4]),raw=r.hex())

def template_selectors(meta,template):
    offset,count=u32(meta,8),u32(meta,0x40);state_at=offset+count*55+4;frame_at=state_at+u32(meta,state_at-4)*16+4
    si=fi=0;out=[]
    for index in range(count):
        rec=meta[offset+index*55:offset+(index+1)*55]
        for sel in range(rec[46]+rec[47]):
            st=meta[state_at+si*16:state_at+(si+1)*16];frames=struct.unpack_from('<b',st,13)[0];frames=1 if frames<0 else frames
            if index==template: out.append([struct.unpack_from('<h',meta,frame_at+(fi+k)*12)[0] for k in range(frames)])
            si+=1;fi+=frames
    return out

def vqa_name(tex,sec,resource):
    d=struct.unpack_from('<6H11I',tex,sec[2]+resource*56)
    if d[3]!=0x342:return None
    payload=tex[sec[3]+d[7]:sec[3]+d[7]+d[12]];assert d[12]==22
    return payload[8:].rstrip(b'\0').decode().upper()

def main():
    inventory=json.loads((ROOT/'docs/game-source-inventory.json').read_text())
    area=next(a for a in inventory['areas'] if a['id']=='L4_HJ')
    archive=(GAME/area['source']['file']).read_bytes();assert hashlib.sha256(archive).hexdigest()==area['source']['sha256']
    entry_=next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key'])
    raw=archive[entry_['offset']:entry_['offset']+entry_['size']];assert hashlib.sha256(raw).hexdigest()==area['source']['geometry_sha256']
    assert hashlib.sha256((GAME/'LOLG.DAT').read_bytes()).hexdigest()==EXE_HASH
    owners,_=collect_owners(raw,entry_['offset'],area['counts']['regions'])
    parsed={}
    for stream,(of,sf) in enumerate([(0x3c,0x84),(0x44,0x8c)]):
        _,_,blob=section(raw,of,sf,1)
        for group,commands in groups(blob):parsed[(stream,group)]=[body.hex() for _,body in commands]
    _,_,table=section(raw,0xbc,0xb8,5);_,_,object_events=section(raw,0x40,0x88,1)
    rows=[]
    for o in owners:
        if o['group'] in MINE and o['owner'] in OWNED.get(o['owner_kind'],[]):
            rows.append(dict(stream=o['stream'],group=o['group'],owner_kind=o['owner_kind'],owner=o['owner'],record=o['event'],value=o['value'],predicate=o['predicate'],commands=parsed[(o['stream'],o['group'])]))
    rows.sort(key=lambda r:(r['stream'],r['group']))
    assert sorted({r['group'] for r in rows})==sorted(MINE),sorted(set(MINE)-{r['group'] for r in rows})
    # Completeness: every handler of the owned objects is staged here or explicitly exit-owned.
    _,_,actors=section(raw,0x1c,0x68,56);_,_,props=section(raw,0x14,0x60,37)
    records={}
    for kind,index,recs,stride in [('prop',552,props,37),('actor',61,actors,56),('actor',60,actors,56),('prop',2909,props,37)]:
        listed=[]
        for cursor,k,body,pred in events(object_events,struct.unpack_from('<H',recs,index*stride+12)[0]):
            listed.append(dict(kind=k,raw=body.hex(),predicate=pred))
            if k in (2,3,4,5,6,8,9,10):
                group=struct.unpack_from('<H',body,2)[0]
                assert group in MINE or group in EXTERNAL,(kind,index,body.hex())
        records[f'{kind}{index}']=listed
    predicates={str(p):predicate(table,p) for p in sorted({r['predicate'] for r in rows if r['predicate'] is not None})}
    # prop552 commands run by exit-owned groups (first-visibility loop; region4435/guard-hit removal).
    external_prop552={}
    for g in [10720,17646,28376,28606,28884]:
        stream=0 if g==17646 else 1
        external_prop552[str(g)]=[c for c in parsed[(stream,g)] if bytes.fromhex(c)[1]==3 and int.from_bytes(bytes.fromhex(c)[2:4],'little')==552]
    assert external_prop552['10720']==['050328020100','0803280200000000','080328020700ff00','080328020a000400']
    assert all(external_prop552[str(g)]==['090328020200'] for g in [17646,28376,28606,28884])
    def actor_row(i):
        r=actors[i*56:(i+1)*56];x,z,h,y=struct.unpack_from('<hhHh',r,0);flags=struct.unpack_from('<H',r,8)[0]
        return dict(actor=i,position=[x,y,-z],heading=h,health=struct.unpack_from('<H',r,30)[0],behavior=r[37],path=r[41],flags=flags,present=not flags&0x1000)
    bacatta,guard60=actor_row(61),actor_row(60)
    assert bacatta['path']==1 and guard60['path']==255 and not bacatta['present'] and not guard60['present']
    p=props[552*37:553*37];px,pz,_,py=struct.unpack_from('<hhHh',p,0);pflags=struct.unpack_from('<H',p,8)[0]
    prop552=dict(prop=552,position=[px,py,-pz],flags=pflags,present=not pflags&0x1000,template=85)
    assert (px,pz,py)==(3592,4145,-15)
    # Named globals for every shared index this branch reads or writes (same GLOBAL entry as the exit preparer).
    ga=(GAME/'GLOBAL.MIX').read_bytes();ge=next(e for e in parse_mix(ga) if e['key']==3984507021)
    gblob=ga[ge['offset']:ge['offset']+ge['size']]
    assert hashlib.sha256(gblob).hexdigest()=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    shared_names={}
    for n in [0,12,13,14,18,25,47]:
        off=u32(gblob,0x64)+u32(gblob,0x60)+n*41
        shared_names[str(n)]=gblob[off:off+41].split(b'\0')[0].decode()
    assert shared_names['13']=='GV_BACATTA_RELATIONSHIP' and shared_names['14']=='GV_RUNES_TRANSLATED'
    assert not prop552['present']
    # Timers (kind2) and the kind8/kind9/kind10 records of Bacatta and prop552.
    timers=[]
    for ordinal,r in enumerate([r for r in records['actor61'] if r['kind']==2]):
        b=bytes.fromhex(r['raw']);countdown=struct.unpack_from('<H',b,8)[0]
        assert b[5]&1 and countdown%60==0 and b[7]*60<=countdown<=b[6]*60  # initial countdown within range x60
        timers.append(dict(ordinal=ordinal,group=struct.unpack_from('<H',b,2)[0],flags=b[5],range=[b[7],b[6]],countdown=countdown,predicate=r['predicate'],raw=r['raw']))
    kind8=[dict(group=struct.unpack_from('<H',bytes.fromhex(r['raw']),2)[0],value=struct.unpack_from('<H',bytes.fromhex(r['raw']),4)[0],raw=r['raw']) for r in records['actor61'] if r['kind']==8]
    kind10=[dict(group=struct.unpack_from('<H',bytes.fromhex(r['raw']),2)[0],value=struct.unpack_from('<H',bytes.fromhex(r['raw']),4)[0],region=struct.unpack_from('<H',bytes.fromhex(r['raw']),6)[0],predicate=r['predicate'],raw=r['raw']) for r in records['actor61'] if r['kind']==10]
    hit=next(r for r in records['prop552'] if r['kind']==9);b=bytes.fromhex(hit['raw'])
    kind9=dict(raw=hit['raw'],group=struct.unpack_from('<H',b,2)[0],mask0=struct.unpack_from('<H',b,4)[0],mask2=struct.unpack_from('<H',b,6)[0],threshold=b[8],flags=b[9],mode=b[9]&7,latched=bool(b[9]&0x80))
    assert (kind9['mode'],kind9['threshold'],kind9['latched'])==(4,2,True)
    # Path1 markers (same records as tools/audit_game_paths.py).
    _,_,path_records=section(raw,0xdc,0xd8,4);_,_,markers=section(raw,0xc8,0xc4,8)
    first,count,flags=struct.unpack_from('<HBB',path_records,4)
    route=dict(index=1,first=first,count=count,flags=flags,points=[dict(zip(['x','z','region','flags'],struct.unpack_from('<hhHH',markers,(first+i)*8))) for i in range(count)])
    for pt in route['points']:pt['z']=-pt['z']
    assert [pt['region'] for pt in route['points']]==[3785,3781,1897,4417,4439,4435,4442,4390,4393]
    geometry=json.loads(GEOMETRY.read_text())
    def polygon(index):
        reg=geometry['regions'][index];assert reg['id']==index
        return dict(region=index,polygon=[[geometry['vertices_fixed'][v][0]/65536,-geometry['vertices_fixed'][v][1]/65536] for v in reg['vertex_indices']],floor_min=min(reg['floor_corners']),floor_max=max(reg['floor_corners']))
    regions=[polygon(i) for i in sorted({1921,1897}|{pt['region'] for pt in route['points']})]
    # Media bindings.
    tex=TEXTURE.read_bytes();sec=sections(tex)
    metas=[e for e in parse_mix(archive) if archive[e['offset']:e['offset']+8]==struct.pack('<II',18,516)];assert len(metas)==1
    meta=archive[metas[0]['offset']:metas[0]['offset']+metas[0]['size']]
    prop_selectors={str(i):dict(resource=res[0],vqa=vqa_name(tex,sec,res[0])) for i,res in enumerate(template_selectors(meta,85)) if i<=14}
    assert prop_selectors['1']['vqa']=='BC07.VQA' and prop_selectors['14']['vqa']=='1386604E.VQA' and all(prop_selectors[str(i)]['vqa'] for i in range(15))
    guard_manifest=json.loads((ROOT/'assets/lol2/generated/jungle_exit_guard_sprites/sprites.json').read_text())['definitions']['9']['states']
    guard_poses={str(s):dict(resource=guard_manifest[s]['views'][0]['frames'][0],vqa=vqa_name(tex,sec,guard_manifest[s]['views'][0]['frames'][0])) for s in (8,9,10,11)}
    assert all(v['vqa'] for v in guard_poses.values())
    bac_resources={1:460,2:459}
    bacatta_poses={str(s):dict(resource=r,vqa=vqa_name(tex,sec,r)) for s,r in bac_resources.items()}
    assert bacatta_poses['1']['vqa']=='1390104E.VQA' and bacatta_poses['2']['vqa']=='1390204E.VQA'
    bank=entry('LOCALLNG.MIX',1570429112);assert hashlib.sha256(bank).hexdigest()==BANK_HASH
    rcount,rtable=struct.unpack_from('<II',bank,0x258)
    sounds={str(q):bank[rtable+q*60+16:rtable+q*60+60].split(b'\0')[0].decode() for q in SOUND_REQUESTS};assert all(q<rcount for q in SOUND_REQUESTS)
    result=dict(version=1,source=area['source'],executable_sha256=EXE_HASH,groups=rows,external_groups={str(k):v for k,v in EXTERNAL.items()},
        records=records,predicates=predicates,prop552=prop552,bacatta=bacatta,guard60=guard60,timers=timers,kind8=kind8,kind10=kind10,kind9=kind9,
        route=route,regions=regions,external_prop552=external_prop552,prop_selectors=prop_selectors,guard_poses=guard_poses,bacatta_poses=bacatta_poses,bacatta_walk_pose=7,sounds=sounds,
        tick_rate=60,owned_locals=[37,51],shared_names=shared_names,shared_caps='opcode206/199 clamp 0..255; three indices held in runtime BSS bytes 0x23342/43/44 are further capped at 10/2/2 (loader-filled, not statically resolvable: host applies)',shared_writes='op206 signed add / op199 write, clamped 0..255 (caps for 0x23342-44 indices applied by host)',
        player_properties={'49':'0x31 release: lock slot3 + clear player+0x81 + halt (D83D7)'},
        adapters=['op8 load/start media completion = event0; op13 sub4/op5 sprite pose cycle end = event3 (convention across groups, not native-proven)',
            'kind5 value1 producer unknown (supplied)','kind9 hit context words/before/after and 0x23331==5 special supplied by host',
            'Bacatta walk speed and marker arrival radius are presentation adapters; index advancement reuses native-verified hive_path_control.gd',
            'kind10 value0x9000 word = actor-in-region (Bacatta word1897 is a path1 region; producer not traced)'])
    out=ROOT/'scripts/lol2/jungle_bacatta_source.json';out.write_text(json.dumps(result,indent=1)+'\n')
    print('PASS: %d groups pinned (+%d external), %d timers, kind8 %s, kind10 %s, kind9 mode%d thr%d latched, path1 %d markers, prop selectors 0-14 VQA, sounds %s'%(
        len(rows),len(EXTERNAL),len(timers),[(k['value'],k['group']) for k in kind8],[(k['region'],k['group']) for k in kind10],kind9['mode'],kind9['threshold'],count,list(sounds.values())))
if __name__=='__main__':main()
