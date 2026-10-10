#!/usr/bin/env python3
"""Stage exact control120/template27/resource1911 original intro VQA."""
import argparse,hashlib,json,sys,struct,os
from pathlib import Path
from PIL import Image
from lol2.map_video_inventory import lookup_movie
from lol2_movie_format import parse_vqa_chunks
from lol2_movie_media import decode,audio
from prepare_creature_audio_clips import stage_clips
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections
ROOT=Path(__file__).resolve().parents[1]
INPUT_ROOT=ROOT
GAME=Path(os.environ.get('LOL2_GAME_ROOT','/home/bob/lol2_out/museum_capture_20260913/game'))
MAP=Path('/home/bob/lol2_out/all_maps_20260922/L1_DC')
HASH='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
def source_area():
 area=next(a for a in json.loads((INPUT_ROOT/'docs/game-source-inventory.json').read_text())['areas'] if a['id']=='L1_DC')
 archive=(GAME/area['source']['file']).read_bytes()
 assert hashlib.sha256(archive).hexdigest()==area['source']['sha256']
 entry=next(e for e in parse_mix(archive) if e['key']==area['source']['geometry_key'])
 geo=archive[entry['offset']:entry['offset']+entry['size']]
 assert hashlib.sha256(geo).hexdigest()==area['source']['geometry_sha256']
 return area,archive,geo
def main():
 out=ROOT/'assets/lol2/generated/cave_captain_movie';out.mkdir(parents=True,exist_ok=True)
 cache=ROOT/'tmp/cave_captain_movie';cache.mkdir(parents=True,exist_ok=True)
 area,archive,geo=source_area()
 control=geo[u32(geo,0x18)+120*33:][:33];assert control.hex()=='75f82d12993928000204300222181883000000000100000000000000140004001b'
 templates=json.loads((MAP/'movables/movables.json').read_text())['source_templates']
 template=next(t for t in templates if t['index']==27);raw=bytes.fromhex(template['raw_hex']);assert archive.count(raw)==1 and struct.unpack_from('<H',raw,0x24)[0]==1911 and template['dimensions']==[185,1,88]
 texture=(MAP/'texture.bin').read_bytes();assert hashlib.sha256(texture).hexdigest()==HASH
 sec=sections(texture);d=struct.unpack_from('<6H11I',texture,sec[2]+1911*56)
 payload=texture[sec[3]+d[7]:sec[3]+d[7]+d[12]];assert payload.hex()=='43019001f800160030343130343031652e7671610000'
 found=lookup_movie(GAME,'L1_DC','0410401E.VQA');assert found['sha256']=='0da89aa0b31f0560cd0a8081b8f707fc32bd82da81f63e3b1317837f7c96cf11'
 head=found['vqhd'];assert(head['count'],head['width'],head['height'],head['fps'])==(157,192,400,15)
 path=cache/'0410401e.vqa';path.write_bytes(found['blob']);frames=decode(path,cache/'frames',157,(192,400))
 rows=[]
 for i,p in enumerate(frames):
  im=Image.open(p).convert('RGBA');im=im.transpose(Image.Transpose.ROTATE_270)
  im.putdata([(r,g,b,0) if (r,g,b)==(0,251,251) else (r,g,b,255) for r,g,b,_ in im.getdata()])
  dst=out/f'frame_{i:03d}.png';im.save(dst);rows.append(dict(file='res://'+str(dst.relative_to(ROOT)),sha256=hashlib.sha256(dst.read_bytes()).hexdigest()))
 samples=sum(len(v)*2 for k,v in parse_vqa_chunks(found['blob']) if k==b'SND2');rate=audio(path,out/'voice.wav',samples) if samples else 0
 proof=json.loads((INPUT_ROOT/'docs/captain-region-admission-checks.json').read_text());support=json.loads((INPUT_ROOT/'scripts/lol2/cave_support_controls_source.json').read_text())
 speech=stage_clips(ROOT,"cave_captain_audio",[1031],{1031:"0120716e.aud"},game=GAME)
 result=dict(source=area["source"],control_hex=control.hex(),position=[-1931,40,-4653],dimensions=[185,88],template_hex=raw.hex(),descriptor=list(d),descriptor_payload=payload.hex(),speech=speech,version=1,movie='0410401E.VQA',sha256=found['sha256'],archive=found['archive'],template=27,resource=1911,fps=15,duration=157/15,frames=rows,width=400,height=192,samples=samples,rate=rate,audio='res://'+str((out/'voice.wav').relative_to(ROOT)),regions=proof['regions'],plates=[p for p in support['plates'] if p['id']==89])
 (out/'movie.json').write_text(json.dumps(result,indent=1)+'\n');print('PASS captain original157frames',samples,'audio samples',rate)
def cli():
 global ROOT,INPUT_ROOT,GAME,MAP
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--game',type=Path,required=True)
 parser.add_argument('--map',type=Path,required=True,help='Prepared cave texture.bin and movables/movables.json')
 parser.add_argument('--source-root',type=Path,required=True,help='Repository source contracts')
 parser.add_argument('--output-root',type=Path,required=True)
 args=parser.parse_args()
 if args.output_root.exists():parser.error('--output-root must be a fresh directory')
 for path in [args.map/'texture.bin',args.map/'movables/movables.json',args.source_root/'docs/game-source-inventory.json',args.source_root/'docs/captain-region-admission-checks.json',args.source_root/'scripts/lol2/cave_support_controls_source.json']:
  if not path.is_file():parser.error('Missing input: '+str(path))
 ROOT=args.output_root.resolve();INPUT_ROOT=args.source_root.resolve();GAME=args.game.resolve();MAP=args.map.resolve()
 main()
if __name__=='__main__':
 if len(sys.argv)>1:cli()
 else:main()
