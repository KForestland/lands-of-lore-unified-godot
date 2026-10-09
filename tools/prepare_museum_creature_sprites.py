#!/usr/bin/env python3
"""Stage L3_DH skel (definitions0/2) and Rat views, action rows and frame events.

Same decode path as prepare_jungle_dino_sprites.py. No AI, timing or encounter
semantics are implied. Original pixels stay local (ignored assets/generated).
"""
import hashlib,json,struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix
from lol2_creature_sprite_format import (parse_states, read_events, lcw, decode_blocks,
    decode_rows, group_frames, sections, rgb_palette)
import argparse, os, sys
# Older importing preparers still load their own RE helpers after this module.
# Keep their historical search path during migration; this standalone CLI does
# not import anything from it.
if __name__ != '__main__':
    import re_helper_root; re_helper_root.insert('draracle')  # LOL2_RE_ROOT
GAME=Path(os.environ.get('LOL2_GAME_ROOT', '/home/bob/lol2_out/museum_capture_20260913/game'))
ROOT=Path(__file__).resolve().parents[1]
TEXTURE=Path('/home/bob/lol2_out/museum_capture_20260913/museum_texture_blob.bin')
def sha(raw): return hashlib.sha256(raw).hexdigest()
def stage(archive_name,texture,indices,output, *, game=None):
    archive=((Path(game) if game is not None else GAME)/archive_name).read_bytes()
    entries=parse_mix(archive)
    metas=[archive[e['offset']:e['offset']+e['size']] for e in entries if archive[e['offset']:e['offset']+8]==struct.pack('<II',18,516)]
    assert len(metas)==1;meta=metas[0]
    entities=parse_states(meta)['entities']
    sec=sections(texture)
    descriptors={i:struct.unpack_from('<6H11I',texture,sec[2]+i*56) for i in range((sec[3]-sec[2])//56)}
    bases=sorted({v['resource_reference'] for i in indices for st in entities[i]['states'] for v in st['views']})
    grouped={}
    for base in bases:
        if base not in descriptors: continue
        first=descriptors[base]
        for resource in range(base,base+max(1,first[4]&255)):
            if resource in descriptors: grouped[resource]=descriptors[resource]
    groups={g['base']:g for g in group_frames({i:d for i,d in grouped.items() if d[3]==0x1246})}
    unsupported=[]
    event_count,event_offset=struct.unpack_from('<II',meta,0x50)
    output.mkdir(parents=True,exist_ok=True)
    palette_offset=struct.unpack_from('<I',texture,4)[0]
    palette=rgb_palette(texture[palette_offset:palette_offset+768],6)
    Image.frombytes('RGB',(256,1),bytes(palette)).save(output/'palette.png')
    frames={};books={};definitions={}
    for index in indices:
        source=entities[index];states=[]
        for state in source['states']:
            views=[]
            for view in state['views']:
                resource=view['resource_reference']
                ordinals=groups[resource]['frames'] if resource in groups else [resource]
                for ordinal in ordinals:
                    if ordinal in frames: continue
                    if ordinal not in descriptors:
                        unsupported.append(dict(resource=ordinal,type='missing'));continue
                    descriptor=descriptors[ordinal]
                    payload=texture[sec[3]+descriptor[7]:sec[3]+descriptor[7]+descriptor[12]]
                    assert len(payload)==descriptor[12]
                    if descriptor[3]==0x1246:
                        book_index=struct.unpack_from('<I',payload,8)[0]
                        if book_index not in books:
                            offset,allocation,packed=struct.unpack_from('<III',texture,sec[9]+book_index*12)
                            books[book_index]=lcw(texture[offset:offset+packed])
                        width,height,pixels,_,_=decode_blocks(payload,books[book_index])
                    else:
                        try: width,height,pixels,_=decode_rows(payload,allow_special=True)
                        except ValueError:
                            unsupported.append(dict(resource=ordinal,type=descriptor[3]));continue
                    assert (width,height)==descriptor[1:3]
                    filename=f'frame_{ordinal}.png'
                    Image.frombytes('L',(width,height),pixels).save(output/filename)
                    with Image.open(output/filename) as restored: assert restored.tobytes()==pixels
                    frames[ordinal]=dict(resource=ordinal,file=filename,width=width,height=height,png_sha256=sha((output/filename).read_bytes()))
                views.append(dict(slot=view['slot'],resource=resource,flags=view['flags_byte2'],frames=ordinals))
            raw=bytes.fromhex(state['raw_hex'])
            event_rows,_=read_events(meta,event_offset,event_count,struct.unpack_from('<H',raw,8)[0])
            states.append(dict(selector=state['selector'],views=views,native_interval_units=struct.unpack_from('<i',raw,4)[0]>>8,
                frame_events=[{k:v for k,v in e.items() if k!='raw_hex'} for e in event_rows]))
        definitions[str(index)]=dict(name=source['name'],action_rows=source['entries_bytes'],states=states)
    manifest=dict(version=1,source=dict(file=archive_name,sha256=sha(archive)),metadata_sha256=sha(meta),texture_sha256=sha(texture),
        palette=dict(file='palette.png',png_sha256=sha((output/'palette.png').read_bytes())),unsupported=unsupported,definitions=definitions,frames=list(frames.values()),
        scope=archive_name+' creature definitions '+','.join(map(str,indices))+': selectors, action rows, directional flags, frame events and indexed frames. Every PNG round-trips source indices. No live behavior implied.')
    (output/'sprites.json').write_text(json.dumps(manifest,indent=1)+'\n')
    print('unsupported',unsupported)
    print('PASS',{k:(v['name'],len(v['states'])) for k,v in definitions.items()},len(frames),'frames')
    for k,v in definitions.items():
        print(k,v['name'],'actions',[r[0] for r in v['action_rows']])
        for s in v['states']:
            print('  sel',s['selector'],'views',len(s['views']),'frames',len(s['views'][0]['frames']),'res',s['views'][0]['resource'],'iv',s['native_interval_units'],[(e['kind'],e['frame'],e['value_word']) for e in s['frame_events']])
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,default=GAME)
    parser.add_argument('--archive',default='DAT/L3_DH.MIX')
    parser.add_argument('--texture',type=Path,default=TEXTURE)
    parser.add_argument('--definition',type=int,action='append')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.output is not None and args.output.exists():
        parser.error('Use a fresh output directory')
    indices=args.definition if args.definition is not None else [0,1,2]
    if any(i<0 for i in indices):parser.error('Definition indices must be nonnegative')
    output=args.output if args.output is not None else ROOT/'assets/lol2/generated/museum_creature_sprites'
    stage(args.archive,args.texture.read_bytes(),indices,output,game=args.game)
if __name__=='__main__':main()
