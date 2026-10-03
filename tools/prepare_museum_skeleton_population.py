#!/usr/bin/env python3
"""Stage the live L3_DH skeleton/Rat population from pinned source records.

Placements, loot identities, region/neighbour wake commands (property13/7 and
0x400/0x0C writes), the ten-death local23 counter (op207, predicate58) and its
prop93 state3 result, attack clips/hit events and native damage bases. The
ordering of the predicate58 check versus the op207 increment is not executed;
the live owner applies the designed result after the tenth counted death.
"""
import hashlib,json,struct
from pathlib import Path
from build_game_atlas import parse_mix,section
from audit_game_transition_owners import GAME
from verify_cave_roach_attack import native_bases
ROOT=Path(__file__).resolve().parents[1]
def sha(b): return hashlib.sha256(b).hexdigest()
def main():
    archive=(GAME/'DAT/L3_DH.MIX').read_bytes()
    inventory=json.loads((ROOT/'docs/game-actors.json').read_text())
    area=next(a for a in inventory['areas'] if a['id']=='L3_DH')
    assert sha(archive)==area['source']['sha256']
    ge=next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key']);geo=archive[ge['offset']:ge['offset']+ge['size']]
    _,count,pl=section(geo,0x1c,0x68,56)
    sprites=json.loads((ROOT/'assets/lol2/generated/museum_creature_sprites/sprites.json').read_text())
    definitions={d['definition']:d for d in area['definitions']}
    actors=[]
    for i in range(20,33):
        r=pl[i*56:(i+1)*56];x,z,h,y=struct.unpack_from('<hhHh',r,0)
        d=next(a for a in area['actors'] if a['actor']==i)['definition']
        loot=struct.unpack_from('<I',r,52)[0]
        flags=struct.unpack_from('<H',r,8)[0]
        # Placement flag0x1000 = not linked into the world until an op9 property3 spawn (B49EC).
        actors.append(dict(actor=i,definition=d,position=[x,y,-z],heading=h,health=struct.unpack_from('<H',r,30)[0],behavior=r[37],flags=flags,present=not flags&0x1000,
            loot=loot if loot else None,reward_scale=archive[definitions[d]['archive_offset']+0x83]))
    geometry=json.loads(Path('/home/bob/lol2_out/all_maps_20260922/L3_DH/geometry/geometry.json').read_text())
    assert geometry['source']['sha256']==area['source']['sha256']
    regions=[]
    for index,wake in [(35,[26,25,24]),(346,[28,27,31,32]),(1057,[29])]:
        reg=geometry['regions'][index];assert reg['id']==index
        regions.append(dict(region=index,wake=wake,polygon=[[geometry['vertices_fixed'][v][0]/65536,-geometry['vertices_fixed'][v][1]/65536] for v in reg['vertex_indices']],
            floor_min=min(reg['floor_corners']),floor_max=max(reg['floor_corners'])))
    def clips(defn,action_rows,states):
        sel={}
        for i,row in enumerate(action_rows): sel.setdefault(row[0],[]).append(i)
        def pick(action,first=True): return sel[action][0]
        attacks=[]
        for s in sel[5]:
            st=states[s];hits=[(e['frame'],e['value_word']&255) for e in st['frame_events'] if e['kind']==1]
            attacks.append(dict(selector=s,frames=len(st['views'][0]['frames']),hits=hits))
        return dict(idle=dict(selector=pick(0),frames=len(states[pick(0)]['views'][0]['frames'])),
            walk=dict(selector=pick(1),frames=len(states[pick(1)]['views'][0]['frames'])),
            rise=dict(selector=pick(9),frames=len(states[pick(9)]['views'][0]['frames'])),
            death=dict(selector=pick(14),frames=len(states[pick(14)]['views'][0]['frames'])),
            corpse=dict(selector=pick(15),frames=len(states[pick(15)]['views'][0]['frames'])),attacks=attacks)
    defs={}
    bases={}
    for name in ['skel','Rat']:
        b=native_bases(name);fresh=[k for k,v in b['constructors'].items() if 0 in v];assert len(fresh)==1
        bases[name]=dict(base=fresh[0][0],total81=b['total'],minimum82=b['minimum'],stat_sha256=b['raw_sha256'])
    for key,d in sprites['definitions'].items():
        c=clips(int(key),d['action_rows'],d['states'])
        base=bases['Rat' if d['name']=='Rat' else 'skel']['base']
        for a in c['attacks']: a['damage']=[base*p//100 for _,p in a['hits']]
        defs[key]=dict(name=d['name'],clips=c)
    result=dict(version=1,source=area['source'],actors=actors,definitions=defs,native_bases=bases,regions=regions,
        neighbour_wake={'24':[25,26],'25':[26,24],'26':[25,24]},counted=[23,24,25,26,27,28,29,30,31,32],counter_target=10,scripted_dormant=[20,21,30],
        controls=[dict(control=92,position=[3049,35,-826],group=7596,use=dict(owner_state=0,next_state=1,wake=[20]),
            note='event4 value0 predicate206: control92 state1 and actor20 operations/properties (exact property semantics not replayed)')],
        counter_result=dict(prop=93,state=3,audio_level=0))
    (ROOT/'scripts/lol2/museum_skeleton_population_source.json').write_text(json.dumps(result,indent=1)+'\n')
    print(json.dumps(dict(actors=[(a['actor'],a['definition'],a['health'],a['behavior'],a['loot'],a['reward_scale']) for a in actors],defs={k:{'attacks':v['clips']['attacks'],'rise':v['clips']['rise'],'death':v['clips']['death']} for k,v in defs.items()},bases=bases)))
if __name__=='__main__':main()
