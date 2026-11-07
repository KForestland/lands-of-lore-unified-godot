#!/usr/bin/env python3
"""Stage all source DINO views and frame events, without assigning live AI."""
import argparse,os,sys
import hashlib
import json
import struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix
from lol2_creature_sprite_format import parse_states,read_events,lcw,decode_blocks,decode_rows,group_frames
from lol2_material_format import sections,rgb_palette
GAME=Path(os.environ.get('LOL2_GAME_ROOT','~/lol2_out/museum_capture_20260913/game'))
TEXTURE=Path('~/lol2_out/jungle_geometry_20260914/texture.bin')

ROOT=Path(__file__).resolve().parents[1]


def sha(raw): return hashlib.sha256(raw).hexdigest()


def main(game=GAME,texture_path=TEXTURE,output_root=ROOT):
    profiles=json.loads((ROOT/'docs/game-geometry-profiles.json').read_text())
    area=next(a for a in profiles['areas'] if a['id']=='L4_HJ')
    proof=dict(source=area['source'],metadata_sha256='6ac3bee1526f18496a83ee6a80723be01048f28b1808e760fbe35b8d6685114b',prop195=dict(texture_sha256='98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b'))
    archive=(game/proof['source']['file']).read_bytes()
    assert sha(archive)==proof['source']['sha256']
    entries=parse_mix(archive)
    metadata=[archive[e['offset']:e['offset']+e['size']] for e in entries if archive[e['offset']:e['offset']+8]==struct.pack('<II',18,516)]
    assert len(metadata)==1
    meta=metadata[0];assert sha(meta)==proof['metadata_sha256']
    source=parse_states(meta)['entities'][4];assert source['name']=='DINO'
    texture=texture_path.read_bytes()
    assert sha(texture)==proof['prop195']['texture_sha256']
    sec=sections(texture)
    descriptors={i:struct.unpack_from('<6H11I',texture,sec[2]+i*56) for i in range((sec[3]-sec[2])//56)}
    groups={g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3]==0x1246})}
    event_count,event_offset=struct.unpack_from('<II',meta,0x50)
    assert event_offset+event_count*8+1==len(meta)
    output=output_root/'assets/lol2/generated/jungle_dino_sprites';output.mkdir(parents=True,exist_ok=True)
    palette_offset=struct.unpack_from('<I',texture,4)[0]
    palette=rgb_palette(texture[palette_offset:palette_offset+768],6)
    Image.frombytes('RGB',(256,1),bytes(palette)).save(output/'palette.png')
    with Image.open(output/'palette.png') as restored:
        assert restored.tobytes()==bytes(palette)
    frames={};books={};states=[]
    for state in source['states']:
        views=[]
        for view in state['views']:
            resource=view['resource_reference']
            ordinals=groups[resource]['frames'] if resource in groups else [resource]
            for ordinal in ordinals:
                if ordinal in frames: continue
                descriptor=descriptors[ordinal]
                payload=texture[sec[3]+descriptor[7]:sec[3]+descriptor[7]+descriptor[12]]
                assert len(payload)==descriptor[12]
                if descriptor[3]==0x1246:
                    book_index=struct.unpack_from('<I',payload,8)[0]
                    if book_index not in books:
                        offset,allocation,packed=struct.unpack_from('<III',texture,sec[9]+book_index*12)
                        assert sec[8]<=offset and offset+allocation<=sec[9] and 0<packed<=allocation
                        books[book_index]=lcw(texture[offset:offset+packed])
                    width,height,pixels,_,_=decode_blocks(payload,books[book_index])
                else:
                    assert descriptor[3:5]==(0x28e,1)
                    width,height,pixels,_=decode_rows(payload,allow_special=True)
                assert (width,height)==descriptor[1:3]
                filename=f'frame_{ordinal}.png'
                Image.frombytes('L',(width,height),pixels).save(output/filename)
                with Image.open(output/filename) as restored:
                    assert restored.size==(width,height) and restored.tobytes()==pixels
                frames[ordinal]=dict(resource=ordinal,file=filename,width=width,height=height,
                    payload_sha256=sha(payload),indices_sha256=sha(pixels),png_sha256=sha((output/filename).read_bytes()),special_pixels=pixels.count(1))
            views.append(dict(slot=view['slot'],resource=resource,flags=view['flags_byte2'],frames=ordinals))
        raw=bytes.fromhex(state['raw_hex'])
        event_rows,_=read_events(meta,event_offset,event_count,struct.unpack_from('<H',raw,8)[0])
        states.append(dict(selector=state['selector'],views=views,
            native_interval_units=struct.unpack_from('<i',raw,4)[0]>>8,
            frame_events=[{k:v for k,v in e.items() if k!='raw_hex'} for e in event_rows]))
    assert len(states)==11 and len(frames)==133
    manifest=dict(version=1,definition=4,source=proof['source'],metadata_sha256=sha(meta),texture_sha256=sha(texture),
        palette=dict(file='palette.png',png_sha256=sha((output/'palette.png').read_bytes()),rgb_sha256=sha(bytes(palette))),
        action_rows=source['entries_bytes'],states=states,frames=list(frames.values()),
        scope='All11 source DINO selectors, directional flags, frame-event records and133 unique indexed frames. Every PNG round-trips source indices. No source RNG/action scheduling, native clock-to-seconds, hit application, world scale, placement admission or live encounter implementation is implied. Original pixels stay local.')
    (output/'sprites.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (output_root/'docs').mkdir(parents=True,exist_ok=True)
    (output_root/'docs/jungle-dino-sprites-checks.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: {len(states)} selectors, {len(frames)} unique original frames and indexed PNG round trips')


def cli():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game',type=Path,required=True)
    p.add_argument('--texture',type=Path,required=True)
    p.add_argument('--output-root',type=Path,required=True)
    args=p.parse_args()
    if args.output_root.exists():p.error('Use a fresh output root')
    main(args.game,args.texture,args.output_root)

if __name__=='__main__':
    if len(sys.argv)>1:cli()
    else:main()
