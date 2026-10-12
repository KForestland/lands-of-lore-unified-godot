#!/usr/bin/env python3
"""Stage original scenic explosion, oil-fire sprites and source command audio."""
import argparse,hashlib,json,struct,sys,shutil,os
from pathlib import Path
from PIL import Image
from lol2_movie_format import parse_vqa_chunks
from lol2_movie_media import decode,audio
from lol2.map_video_inventory import lookup_movie
from lol2_source_format import parse_mix,u32
from lol2.map_props import load_templates
from prepare_creature_audio_clips import stage_clips

REPO = Path(__file__).resolve().parents[1]
ROOT = REPO
GAME = Path(os.environ.get('LOL2_GAME_ROOT','/home/bob/lol2_out/museum_capture_20260913/game'))
MAP = Path('/home/bob/lol2_out/all_maps_20260922/L1_DC')
SOURCE = REPO/'scripts/lol2/cave_scenic_guard_source.json'
INVENTORY = REPO/'docs/game-source-inventory.json'

def cave_source():
    area = next(a for a in json.loads(INVENTORY.read_text())['areas'] if a['id']=='L1_DC')
    archive = (GAME/area['source']['file']).read_bytes()
    assert hashlib.sha256(archive).hexdigest()==area['source']['sha256']
    entry = next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key'])
    geo = archive[entry['offset']:entry['offset']+entry['size']]
    assert hashlib.sha256(geo).hexdigest()==area['source']['geometry_sha256']
    return archive,geo

def main():
    out=ROOT/'assets/lol2/generated/cave_scenic_guard_movie';out.mkdir(parents=True,exist_ok=True)
    cache=ROOT/'tmp/cave_scenic_guard_movie';cache.mkdir(parents=True,exist_ok=True)
    found=lookup_movie(GAME,'L1_DC','EXPLODE.VQA');assert found['status']=='exact' and found['sha256']=='872f3939203ea1b920b4c07987e361f2efa072f0b51e5eb699e86ae2e5200ecf'
    blob=found['blob'];path=cache/'explode.vqa';path.write_bytes(blob)
    head=found['vqhd'];assert (head['count'],head['width'],head['height'],head['fps'])==(90,640,400,15)
    frames=decode(path,cache/'frames',90,(640,400));rows=[]
    for i,p in enumerate(frames):
        im=Image.open(p).convert('RGBA')
        # Original black matte; indexed cave compositor uses its own palette.
        im.putdata([(r,g,b,0) if (r,g,b)==(0,0,0) else (r,g,b,255) for r,g,b,_ in im.getdata()])
        dst=out/f'frame_{i:03d}.png';im.save(dst);rows.append(dict(file=dst.name,sha256=hashlib.sha256(dst.read_bytes()).hexdigest()))
    samples=sum(len(v)*2 for k,v in parse_vqa_chunks(blob) if k==b'SND2')
    rate=audio(path,out/'voice.wav',samples) if samples else 0
    arc,geo=cave_source();e=next(e for e in parse_mix(arc) if e['key']==2971019266)
    templates=load_templates(arc[e['offset']:e['offset']+e['size']])['templates']
    source=json.loads(SOURCE.read_text())
    oil_ids=sorted({int(c['target']) for c in source['groups']['5926']['commands'] if c['op']==5})
    originals=MAP/'props/sprites'
    fires=[]
    for index in oil_ids:
        r=geo[u32(geo,0x14)+index*37:][:37];template=templates[struct.unpack_from('<H',r,32)[0]];selector=template['selectors'][2];frame=selector['frames'][0]
        assert frame['descriptor']==126
        x,y,heading,z=struct.unpack_from('<hhHh',r)
        fires.append(dict(prop=index,position=[x,z,-y],placement_hex=r.hex(),template=template['index'],left=frame['left'],right=frame['right'],bottom=frame['bottom'],top=selector['state_height']-frame['top_trim'],flags=frame['frame_flags']))
    images=sorted(originals.glob('prop_126_frame_*_index.png'),key=lambda p:int(p.name.split('_')[3]))
    assert len(images)>1
    fire_frames=[]
    for p in images:
        dst=out/p.name;shutil.copyfile(p,dst);fire_frames.append(dict(file=dst.name,sha256=hashlib.sha256(dst.read_bytes()).hexdigest()))
    sounds=stage_clips(ROOT,'cave_scenic_guard_audio',[411,426],game=GAME)
    movers=json.loads((MAP/'movables/movables.json').read_text())
    template=next(t for t in movers['source_templates'] if t['index']==54);assert template['child_count']==0 and template['dimensions']==[1,1,1]
    moving=[p for p in movers['placements'] if p['index'] in [21,22]];assert len(moving)==2
    result=dict(version=1,movie='EXPLODE.VQA',sha256=found['sha256'],archive=found['archive'],fps=15,duration=6.0,frames=rows,samples=samples,rate=rate,fire_frames=fire_frames,fires=fires,sounds=sounds,movables=moving,movable_template=template)
    (out/'movie.json').write_text(json.dumps(result,indent=1)+'\n')
    print('PASS explosion90frames/audio',samples,'oil fires',len(fires),'original fire frames',len(images),'sounds',list(sounds),'nonvisual movables21/22')
def cli():
    global ROOT,GAME,MAP,SOURCE,INVENTORY
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--map',type=Path,required=True,help='Prepared L1_DC props/sprites and movables')
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--inventory',type=Path,required=True)
    parser.add_argument('--output-root',type=Path,required=True)
    args=parser.parse_args()
    if args.output_root.exists():parser.error('--output-root must be a fresh directory')
    for path in [args.source,args.inventory,args.map/'movables/movables.json']:
        if not path.is_file():parser.error('Missing input: '+str(path))
    GAME=args.game.resolve();MAP=args.map.resolve();SOURCE=args.source.resolve();INVENTORY=args.inventory.resolve();ROOT=args.output_root.resolve()
    main()

if __name__=='__main__':
    if len(sys.argv)>1:cli()
    else:main()
