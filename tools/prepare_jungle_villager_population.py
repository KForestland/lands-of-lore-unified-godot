#!/usr/bin/env python3
"""Stage the present L4_HJ Huline villagers (TIG_MAL/FEM/CUB, actors39-56) in the scripted-creature schema.

All are present (flag0x1000 clear), behaviour6, no event groups or literal commands.
They are friendly village population: dormant (idle) until hit, then they defend.
Absent rogues36-38 and scripted actors (57-66) are excluded.
"""
import json,struct
from pathlib import Path
from build_game_atlas import parse_mix,section
from audit_game_transition_owners import GAME
from verify_cave_roach_attack import native_bases
ROOT=Path(__file__).resolve().parents[1]
def main():
    inventory=json.loads((ROOT/'docs/game-actors.json').read_text())
    area=next(a for a in inventory['areas'] if a['id']=='L4_HJ')
    archive=(GAME/area['source']['file']).read_bytes()
    ge=next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key']);geo=archive[ge['offset']:ge['offset']+ge['size']]
    _,count,pl=section(geo,0x1c,0x68,56)
    definitions={d['definition']:d for d in area['definitions']}
    scripts=json.loads((ROOT/'docs/game-actor-scripts.json').read_text())
    sarea=next(a for a in scripts['areas'] if a['id']=='L4_HJ');scripted={a['actor'] for a in sarea['actors'] if a['events'] or a['addressed_commands']}
    sprites=json.loads((ROOT/'assets/lol2/generated/jungle_villager_sprites/sprites.json').read_text())
    actors=[]
    for i in range(39,57):
        r=pl[i*56:(i+1)*56];x,z,h,y=struct.unpack_from('<hhHh',r,0);flags=struct.unpack_from('<H',r,8)[0]
        d=next(a for a in area['actors'] if a['actor']==i)['definition']
        assert not flags&0x1000 and i not in scripted and r[37]==6
        actors.append(dict(actor=i,definition=d,position=[x,y,-z],heading=h,health=struct.unpack_from('<H',r,30)[0],behavior=r[37],flags=flags,present=True,
            loot=struct.unpack_from('<I',r,52)[0] or None,reward_scale=archive[definitions[d]['archive_offset']+0x83]))
    defs={}
    for key,d in sprites['definitions'].items():
        if key=='0': continue
        b=native_bases(d['name'])
        fresh=[k for k,v in b['constructors'].items() if 0 in v];base=fresh[0][0]
        sel={}
        for i,row in enumerate(d['action_rows']): sel.setdefault(row[0],[]).append(i)
        st=d['states'];n=lambda s:len(st[s]['views'][0]['frames'])
        attacks=[]
        for s in sel[5]:
            hits=[(e['frame'],e['value_word']&255) for e in st[s]['frame_events'] if e['kind']==1]
            if hits: attacks.append(dict(selector=s,frames=n(s),hits=hits,damage=[base*p//100 for _,p in hits]))
        defs[key]=dict(name=d['name'],native_base=base,clips=dict(idle=dict(selector=sel[0][0],frames=n(sel[0][0])),walk=dict(selector=sel[1][0],frames=n(sel[1][0])),
            rise=dict(selector=sel[9][0],frames=n(sel[9][0])),death=dict(selector=sel[14][0],frames=n(sel[14][0])),corpse=dict(selector=sel[15][0],frames=n(sel[15][0])),attacks=attacks))
    result=dict(version=1,source=area['source'],actors=actors,definitions=defs,regions=[],neighbour_wake={},counted=[],counter_target=0,
        scripted_dormant=[a['actor'] for a in actors],dormant_pose='idle')
    (ROOT/'scripts/lol2/jungle_villager_population_source.json').write_text(json.dumps(result,indent=1)+'\n')
    print(json.dumps(dict(actors=[(a['actor'],a['definition'],a['health'],a['reward_scale']) for a in actors],defs={k:v['clips']['attacks'] for k,v in defs.items()})))
if __name__=='__main__':main()
