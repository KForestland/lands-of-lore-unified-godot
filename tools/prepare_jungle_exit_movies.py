#!/usr/bin/env python3
"""Stage the Jungle exit encounter's original movies and scripted guard pose clips (local only).

Endings: prop4398 opcode21 movies HW-BRDGE (33), E068E (56), E069E (57), hash-bound to
scripts/lol2/jungle_exit_encounter_source.json. Pose clips: GGuard definition9 selectors 8 and 12
(opcode13 subcommand4 poses for guard59/guard58) are texture type0x342 descriptors whose 22-byte
payload names an in-world VQA (resource464 = 1790004E, resource461 = 1795004E). Every VQFR frame
and every SND2 sample is required. Pose frames keep the source's pure blue key as alpha0.
Output: assets/lol2/generated/jungle_exit_movies/ (ignored; original media stays local).
"""
import argparse,hashlib,json,os,struct,subprocess,sys,wave
from pathlib import Path
from PIL import Image
from lol2_movie_media import decode, audio
from lol2.map_video_inventory import lookup_movie
from lol2_movie_format import parse_vqa_chunks
from lol2_material_format import sections
GAME=Path(os.environ.get('LOL2_GAME_ROOT','/home/bob/lol2_out/museum_capture_20260913/game'))
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/lol2/generated/jungle_exit_movies'
CACHE=ROOT/'tmp/jungle_exit_movies'
TEXTURE=Path('/home/bob/lol2_out/jungle_geometry_20260914/texture.bin')
SPRITES=ROOT/'assets/lol2/generated/jungle_exit_guard_sprites/sprites.json'
SOURCE=ROOT/'scripts/lol2/jungle_exit_encounter_source.json'
POSES={8:(464,'1790004E.VQA'),12:(461,'1795004E.VQA')}
KEY=(0,0,255)
def sha(raw): return hashlib.sha256(raw).hexdigest()
def res(path): return 'res://'+str(path.relative_to(ROOT))
def fetch(name):
    found=lookup_movie(GAME,'L4_HJ',name);assert found['status']=='exact' and found['archive']=='DAT/L4_HJI.MIX',name
    blob=found['blob'];assert len(blob)==found['length'] and sha(blob)==found['sha256']
    path=CACHE/name;path.write_bytes(blob)
    chunks=parse_vqa_chunks(blob);head=found['vqhd']
    assert sum(k==b'VQFR' for k,v in chunks)==head['count']
    return found,path,head,sum(len(v)*2 for k,v in chunks if k==b'SND2')
def main():
    CACHE.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    source=json.loads(SOURCE.read_text())
    endings=[]
    for e in source['endings']:
        found,path,head,samples=fetch(e['movie']);assert found['sha256']==e['movie_sha256']
        assert (head['width'],head['height'],head['fps'])==(640,400,15)
        name=e['movie'][:-4].lower();folder=OUT/name;frames=decode(path,CACHE/name,head['count'],(640,400))
        folder.mkdir(exist_ok=True)
        for old in folder.glob('page_*.png'): old.unlink()
        atlases=[]
        for first in range(0,len(frames),16):
            sheet=Image.new('RGB',(2560,1600))
            for i,p in enumerate(frames[first:first+16]): sheet.paste(Image.open(p).convert('RGB'),((i%4)*640,(i//4)*400))
            target=folder/f'page_{first//16}.png';sheet.save(target);atlases.append(res(target))
        rate=audio(path,folder/'voice.wav',samples)
        endings.append(dict(movie=e['movie'],movie_index=e['movie_index'],predicate=e['predicate'],group=e['group'],movie_sha256=found['sha256'],
            frames=head['count'],fps=15,width=640,height=400,columns=4,per_page=16,atlases=atlases,audio=res(folder/'voice.wav'),audio_samples=samples,audio_rate=rate,
            duration=max(head['count']/15,samples/rate)))
    texture=TEXTURE.read_bytes();sec=sections(texture)
    manifest=json.loads(SPRITES.read_text());states=manifest['definitions']['9']['states']
    poses=[]
    for selector,(resource,name) in POSES.items():
        assert states[selector]['views'][0]['frames']==[resource]
        d=struct.unpack_from('<6H11I',texture,sec[2]+resource*56)
        payload=texture[sec[3]+d[7]:sec[3]+d[7]+d[12]]
        assert d[3]==0x342 and d[12]==22 and payload[8:].rstrip(b'\0').decode().upper()==name,(selector,payload)
        found,path,head,samples=fetch(name)
        size=(head['width'],head['height']);folder=OUT/f'pose_{selector}'
        frames=decode(path,CACHE/f'pose_{selector}',head['count'],size)
        folder.mkdir(exist_ok=True)
        for old in folder.glob('*.png'): old.unlink()
        rows=[]
        for i,p in enumerate(frames):
            image=Image.open(p).convert('RGBA')
            image.putdata([(r,g,b,0) if (r,g,b)==KEY else (r,g,b,255) for r,g,b,_ in image.getdata()])
            target=folder/f'frame_{i:03d}.png';image.save(target);rows.append(dict(file=res(target),png_sha256=sha(target.read_bytes())))
        rate=audio(path,folder/'voice.wav',samples)
        poses.append(dict(selector=selector,resource=resource,descriptor_type=d[3],vqa=name,vqa_sha256=found['sha256'],frames=head['count'],fps=head['fps'],
            width=size[0],height=size[1],frame_files=rows,audio=res(folder/'voice.wav'),audio_samples=samples,audio_rate=rate,
            duration=head['count']/head['fps']))
    result=dict(version=1,archive='DAT/L4_HJI.MIX',texture_sha256=sha(texture),sprites_sha256=sha(SPRITES.read_bytes()),endings=endings,poses=poses,
        note='Original media, local only. Pose clip duration is frames/15fps; whether native opcode8 waits exactly for clip end is not claimed.')
    (OUT/'movies.json').write_text(json.dumps(result,indent=1)+'\n')
    print('PASS endings',[(e['movie'],e['frames'],e['audio_samples']) for e in endings],'poses',[(p['selector'],p['vqa'],p['frames'],p['audio_samples']) for p in poses])
def cli():
    global ROOT,OUT,CACHE,GAME,TEXTURE,SPRITES,SOURCE
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--texture',type=Path,required=True)
    parser.add_argument('--sprites',type=Path,required=True)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--output-root',type=Path,required=True)
    args=parser.parse_args()
    if args.output_root.exists(): parser.error('--output-root must be a fresh directory')
    for path in [args.texture,args.sprites,args.source]:
        if not path.is_file(): parser.error('Missing input: '+str(path))
    GAME=args.game.resolve();TEXTURE=args.texture.resolve();SPRITES=args.sprites.resolve();SOURCE=args.source.resolve()
    ROOT=args.output_root.resolve();OUT=ROOT/'assets/lol2/generated/jungle_exit_movies';CACHE=ROOT/'tmp/jungle_exit_movies'
    main()
if __name__=='__main__':
    if len(sys.argv)>1: cli()
    else: main()

