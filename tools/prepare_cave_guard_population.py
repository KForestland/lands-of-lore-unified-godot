#!/usr/bin/env python3
"""Stage the live L1_DC guard population (GGUARD/GGCAPT) in the scripted-creature schema.

Presence = placement flag0x1000 clear (B49EC links flagged actors only on an op9
property3 spawn). Region groups: 631 spawns39 (one-shot, local4); 769/772/775 wake39
(property13/7); 1104 wakes52; 1941 spawns38; 106/121 spawn53; 969 spawns54;
23 spawns1/2. Control-driven sequences (109/114/119/120, captain56) are not live.
"""
import json,struct
from pathlib import Path
from build_game_atlas import parse_mix,section
from audit_game_transition_owners import GAME
from verify_cave_roach_attack import native_bases
ROOT=Path(__file__).resolve().parents[1]
REGIONS=[(631,[39],[]),(769,[],[39]),(772,[],[39]),(775,[],[39]),(1104,[],[52]),(1941,[38],[]),(106,[53],[]),(121,[53],[]),(969,[54],[]),(23,[1,2],[])]
def main():
    inventory=json.loads((ROOT/'docs/game-actors.json').read_text())
    area=next(a for a in inventory['areas'] if a['id']=='L1_DC')
    archive=(GAME/area['source']['file']).read_bytes()
    ge=next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key']);geo=archive[ge['offset']:ge['offset']+ge['size']]
    _,count,pl=section(geo,0x1c,0x68,56)
    definitions={d['definition']:d for d in area['definitions']}
    sprites=json.loads((ROOT/'assets/lol2/generated/cave_guard_sprites/sprites.json').read_text())
    # Sprite manifest indices 0/1/2 are entities GGCAPT/GGUARD/GGUARD = placement definitions0/1/2.
    actors=[]
    for i in [1,2,38,39,52,53,54,56]:
        r=pl[i*56:(i+1)*56];x,z,h,y=struct.unpack_from('<hhHh',r,0)
        d=next(a for a in area['actors'] if a['actor']==i)['definition']
        flags=struct.unpack_from('<H',r,8)[0];loot=struct.unpack_from('<I',r,52)[0]
        actors.append(dict(actor=i,definition=d,position=[x,y,-z],heading=h,health=struct.unpack_from('<H',r,30)[0],behavior=r[37],flags=flags,present=not flags&0x1000,
            loot=loot or None,reward_scale=archive[definitions[d]['archive_offset']+0x83]))
    geometry=json.loads(Path('/home/bob/lol2_out/all_maps_20260922/L1_DC/geometry/geometry.json').read_text())
    regions=[]
    for index,spawn,wake in REGIONS:
        reg=geometry['regions'][index];assert reg['id']==index
        regions.append(dict(region=index,spawn=spawn,wake=wake,polygon=[[geometry['vertices_fixed'][v][0]/65536,-geometry['vertices_fixed'][v][1]/65536] for v in reg['vertex_indices']],floor_min=min(reg['floor_corners']),floor_max=max(reg['floor_corners'])))
    base=None;bases={}
    for name in ['GGUARD','GGCAPT']:
        b=native_bases(name);fresh=[k for k,v in b['constructors'].items() if 0 in v];assert len(fresh)==1
        bases[name]=dict(base=fresh[0][0],total81=b['total'],minimum82=b['minimum'],stat_sha256=b['raw_sha256'])
    defs={}
    for key,d in sprites['definitions'].items():
        sel={}
        for i,row in enumerate(d['action_rows']): sel.setdefault(row[0],[]).append(i)
        st=d['states'];n=lambda s:len(st[s]['views'][0]['frames'])
        b=bases['GGCAPT' if d['name']=='GGCAPT' else 'GGUARD']['base']
        attacks=[]
        for s in sel[5]:
            hits=[(e['frame'],e['value_word']&255) for e in st[s]['frame_events'] if e['kind']==1]
            attacks.append(dict(selector=s,frames=n(s),hits=hits,damage=[b*p//100 for _,p in hits]))
        defs[key]=dict(name=d['name'],clips=dict(idle=dict(selector=sel[0][0],frames=n(sel[0][0])),walk=dict(selector=sel[1][0],frames=n(sel[1][0])),
            rise=dict(selector=sel[9][0],frames=n(sel[9][0])),death=dict(selector=sel[14][0],frames=n(sel[14][0])),corpse=dict(selector=sel[15][0],frames=n(sel[15][0])),attacks=attacks))
    # Spawned actors fight unless a later region wakes them (39); present beh14 52 waits for1104.
    result=dict(version=1,source=area['source'],actors=actors,definitions=defs,native_bases=bases,regions=regions,neighbour_wake={},counted=[],counter_target=0,
        scripted_dormant=[56])
    (ROOT/'scripts/lol2/cave_guard_population_source.json').write_text(json.dumps(result,indent=1)+'\n')
    print(json.dumps(dict(actors=[(a['actor'],a['definition'],a['health'],a['behavior'],a['present'],a['reward_scale']) for a in actors],attacks={k:v['clips']['attacks'] for k,v in defs.items()},bases=bases)))
if __name__=='__main__':main()
