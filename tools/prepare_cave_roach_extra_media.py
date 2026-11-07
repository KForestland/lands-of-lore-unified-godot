#!/usr/bin/env python3
"""Prepare original Roach action9/10 clips using a freshly reconstructed shared canvas."""
import argparse,hashlib,json,struct,tempfile
from pathlib import Path
from PIL import Image
from prepare_cave_directions_media import load_events,select,export,HASH
from lol2_creature_sprite_format import group_frames,lcw,decode_blocks
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections

def sha(data):return hashlib.sha256(data).hexdigest()
def prepare(GAME,texture,ROOT):
    if ROOT.exists():raise ValueError('Output must be fresh')
    for source in (GAME,texture):
        if ROOT==source or ROOT in source.parents or source in ROOT.parents:raise ValueError('Output overlaps input')
    source=load_events(GAME);entity=source['entities'][4]
    assert entity['name']=='Roach'
    entrance=source['entities'][5];assert entrance['name']=='ROACH'
    archive=(GAME/'DAT/L1_DC.MIX').read_bytes()
    e=next(e for e in parse_mix(archive) if e['key']==2971673856)
    geo=archive[e['offset']:e['offset']+e['size']]
    placement=geo[u32(geo,0x1c)+23*56:][:56]
    assert placement[32]==5 and placement[37:39]==bytes([14,9])
    blob=texture.read_bytes();assert sha(blob)==HASH
    sec=sections(blob)
    descriptors={i:struct.unpack_from('<6H11I',blob,sec[2]+i*56) for i in range((sec[3]-sec[2])//56)}
    groups={g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3]==0x1246})}
    with tempfile.TemporaryDirectory(prefix='roach-directions-') as temp:
        fresh=Path(temp)/'directions'
        export(GAME,texture,fresh)
        base=json.loads((fresh/'animation.json').read_text())
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
    (ROOT/'docs').mkdir(exist_ok=True)
    (ROOT/'docs/cave-roach-extra-actions-checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS:16 original Roach action9/10 frames;3072 actual-table lookup cases;lossless shared canvas')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('game','texture','output-root'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
    except (ValueError,OSError,AssertionError,KeyError,IndexError,struct.error) as error:p.error(str(error) or 'Source validation failed')
if __name__=='__main__':main()
