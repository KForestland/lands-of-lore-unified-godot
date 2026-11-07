#!/usr/bin/env python3
"""Bind the seven cave Stalagmite formations to their source pickup/state command groups."""
import argparse, hashlib, json, shutil, struct
from pathlib import Path
from build_game_atlas import parse_mix, u32, section
from audit_game_actor_scripts import groups
from audit_game_transition_owners import events
from lol2.map_props import load_templates


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,default=Path('~/lol2_out/museum_capture_20260913/game'))
    p.add_argument('--map',type=Path,default=Path('~/lol2_out/all_maps_20260922/L1_DC'))
    p.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[1]/'assets/lol2/generated/cave_stalagmite')
    a=p.parse_args();arc=(a.game/'DAT/L1_DC.MIX').read_bytes()
    sha=lambda b:hashlib.sha256(b).hexdigest()
    assert sha(arc)=='6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
    def entry(key):
        e=next(e for e in parse_mix(arc) if e['key']==key)
        return arc[e['offset']:e['offset']+e['size']]
    geo=entry(2971673856);meta=entry(2971019266)
    template=load_templates(meta)['templates'][67]
    assert template['selector_count']==5
    _,_,stream=section(geo,0x44,0x8c,1);commands=dict(groups(stream))
    _,_,event_table=section(geo,0x40,0x88,1)
    review=json.loads((a.map/'review.json').read_text())
    a.out.mkdir(parents=True,exist_ok=True)
    states=[]
    for sel in template['selectors']:
        assert len(sel['frames'])==1
        f=sel['frames'][0];resource=f['descriptor'];assert resource==[122,123,124,122,125][sel['selector']]
        source=a.map/review['indexed_materials'][f'prop_{resource}']
        target=a.out/f'{resource}.png';shutil.copyfile(source,target)
        states.append(dict(selector=sel['selector'],image=target.name,sha256=sha(target.read_bytes()),
            left=f['left'],right=f['right'],bottom=f['bottom'],top=sel['state_height']-f['top_trim']))
    plants=[]
    for record in [144,145,146,147,148,149,641]:
        raw=geo[u32(geo,0x14)+record*37:][:37]
        assert struct.unpack_from('<H',raw,32)[0]==67 and raw[35]==0
        offset=struct.unpack_from('<H',raw,12)[0]
        links=[]
        for _,kind,body,predicate in events(event_table,offset):
            if kind!=4: continue
            assert predicate in [46,47]
            state=0
            assert geo[u32(geo,0xbc)+predicate*5:][:5]==bytes([6,4,41 if predicate==46 else 40,4,4])
            for reference,expected in [(4,bytes([0,5,0,0,0])),(40,bytes([0,3,16,0,1])),(41,bytes([0,3,16,0,0]))]:
                assert geo[u32(geo,0xbc)+reference*5:][:5]==expected
            group=struct.unpack_from('<H',body,2)[0];children=commands[group]
            grants=[b for _,b in children if b[:4]==bytes([3,1,0,0])]
            assert grants==[bytes.fromhex('03010000f3f6830501000000')]
            selectors=[b for _,b in children if b[:2]==bytes([5,3])]
            assert selectors==[struct.pack('<BBHBB',5,3,record,3,0)]
            writes=[b for _,b in children if b[:2]==bytes([16,3])]
            assert writes==[struct.pack('<BBHH',16,3,record,state+1)]
            links.append(dict(owner_state=state,next_state=state+1,selector=3,
                predicate=predicate,group=group,commands=[b.hex() for _,b in children]))
        assert len(links)==2
        x,y,_,z=struct.unpack_from('<4h',raw)
        plants.append(dict(record=record,position=[x,z,-y],initial_selector=0,
            placement_hex=raw.hex(),transitions=links))
    report=dict(version=1,item_identity=92534515,item_label='Stalagmite',
        archive_sha256=sha(arc),geometry_sha256=sha(geo),metadata_sha256=sha(meta),
        scope='Pinned source event kind4, owner-state predicates, selector/state writes and player opcode3 item identity. Modern E/range interaction; native callback scheduling and secondary audio/effect commands not emulated.',
        states=states,plants=plants)
    (a.out/'stalagmite.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS seven original Stalagmite formations, fourteen state/grant groups, five source sprite states')


if __name__=='__main__':main()
