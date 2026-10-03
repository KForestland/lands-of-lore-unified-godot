#!/usr/bin/env python3
"""Stage original definition4 action9/10 clips; no AI/timing interpretation."""
import hashlib,json,struct
from pathlib import Path
from PIL import Image
from extract_creature_frame_events import load_events
from verify_creature_action_lookup import select
from build_creature_group_review import group_frames
from extract_block_sprite_frames import lcw,decode_blocks
from lol2_cache_named_wall_fixture import load_named
from lol2_extract_cave_materials import ASSET,HASH
from lol2_wall_material_checkpoint import sections
ROOT=Path(__file__).resolve().parents[1]
GAME=Path('/home/bob/lol2_out/museum_capture_20260913/game')
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    source=load_events(GAME);entity=source['entities'][4]
    assert entity['name']=='Roach'
    entrance=source['entities'][5];assert entrance['name']=='ROACH'
    placement=json.loads((ROOT/'assets/lol2/generated/cave_roach/actor.json').read_text())
    assert placement['actor']==23 and placement['definition']==5
    assert bytes.fromhex(placement['placement_hex'])[37:39]==bytes([14,9])
    _,blob,_,_=load_named(GAME,ASSET);assert sha(blob)==HASH
    sec=sections(blob)
    descriptors={i:struct.unpack_from('<6H11I',blob,sec[2]+i*56) for i in range((sec[3]-sec[2])//56)}
    groups={g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3]==0x1246})}
    base=json.loads((ROOT/'assets/lol2/generated/encounter_directions/animation.json').read_text())
    crop=tuple(base['crop_box']);out=ROOT/'assets/lol2/generated/cave_roach_extra_actions';out.mkdir(parents=True,exist_ok=True)
    clips=[];books={};lookup_cases=0
    for action,selector,resource in [(9,7,830),(10,8,838)]:
        for mask in range(256):
            for sample in [0,50,100]:
                for definition in [entity,entrance]:
                    assert select(definition['entries_bytes'],action,mask,-1,sample)==selector
                    lookup_cases+=1
        state=entity['states'][selector]
        assert len(state['views'])==1 and state['views'][0]['resource_reference']==resource
        assert state['views'][0]['flags_byte2']==0 and groups[resource]['count']==8
        entrance_views=entrance['states'][selector]['views']
        assert len(entrance_views)==1 and entrance_views[0]['resource_reference']==resource and entrance_views[0]['flags_byte2']==0
        frames=[]
        for ordinal in groups[resource]['frames']:
            d=descriptors[ordinal];payload=blob[sec[3]+d[7]:][:d[12]]
            ci=struct.unpack_from('<I',payload,8)[0]
            if ci not in books:
                offset,allocation,packed=struct.unpack_from('<III',blob,sec[9]+ci*12)
                assert sec[8]<=offset and offset+allocation<=sec[9] and 0<packed<=allocation
                books[ci]=lcw(blob[offset:offset+packed])
            w,h,pixels,_,_=decode_blocks(payload,books[ci]);assert (w,h)==(320,200) and 1 not in pixels
            image=Image.frombytes('L',(w,h),pixels);cropped=image.crop(crop)
            restored=Image.new('L',image.size);restored.paste(cropped,crop[:2])
            assert restored.tobytes()==pixels,'Existing shared canvas loses extra-action pixels'
            filename=f'action_{action}_frame_{ordinal}.png';cropped.save(out/filename)
            with Image.open(out/filename) as check:assert check.tobytes()==cropped.tobytes()
            frames.append(dict(descriptor=ordinal,file=filename,payload_sha256=sha(payload),indices_sha256=sha(pixels),png_sha256=sha((out/filename).read_bytes())))
        clips.append(dict(action=action,selector=selector,resource=resource,frames=frames,frame_events=[{k:v for k,v in event.items() if k!='raw_hex'} for event in state['frame_events']],state_offset=state['source_offset']))
    report=dict(version=1,entity=4,name='Roach',entrance_binding=dict(actor=23,definition=5,initial_goal=14,initial_action=9,shared_resources=[830,838]),source_entry_sha256=source['entry_sha256'],cache_sha256=HASH,lookup_cases=lookup_cases,canvas_size=base['canvas_size'],crop_box=list(crop),world_units_per_pixel=base['world_units_per_pixel'],centre_offset=base['centre_offset'],clips=clips,scope='Source action9→selector7/resource830 and action10→selector8/resource838;16 frames decoded and losslessly reconstructed on existing shared indexed canvas. Lookup uses the previously verified selector implementation with actual Roach rows. Not a new native replay. Original sound-event IDs retained; playback, native clock, world scale, live AI and hostile admission remain unclaimed.')
    (out/'animation.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'docs/cave-roach-extra-actions-checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS:16 original Roach action9/10 frames;3072 actual-table lookup cases;lossless shared canvas')
if __name__=='__main__':main()
