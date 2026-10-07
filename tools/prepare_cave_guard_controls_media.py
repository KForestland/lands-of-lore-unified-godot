#!/usr/bin/env python3
"""Decode four original cave support-cutscene VQAs without replacing their media."""
import argparse,hashlib,json,sys,os
from pathlib import Path
from PIL import Image
from lol2.map_video_inventory import lookup_movie
from lol2_movie_format import parse_vqa_chunks
from prepare_jungle_exit_movies import decode,audio
GAME=Path(os.environ.get('LOL2_GAME_ROOT','/home/bob/lol2_out/museum_capture_20260913/game'))
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'scripts/lol2/cave_guard_controls_source.json'
PINS={1912:('ba0c7699b4f9c7e2c7cdd8ddd9b76de96bf96b9a7ef7d8abf084de4108df26e4',30,188,196),1913:('1065dce09ee6f1740c7cd0614c4a5a4af0d829bc4bb798f276748b226e879050',26,96,188),1914:('ff43f22013f261af519e69d38d636b827dc78eb24bc51b7366c556b6219c098a',60,224,196),1916:('a66fa24e55d7ffe374578f1372051288684a7e6f103378775fbdd5ee13aaa1af',164,356,640)}
def main():
 source=json.loads(SOURCE.read_text());out=ROOT/'assets/lol2/generated/cave_guard_controls';out.mkdir(parents=True,exist_ok=True);cache=ROOT/'tmp/cave_guard_controls';cache.mkdir(parents=True,exist_ok=True);clips={}
 for binding in source['bindings']:
  ident=binding['resource'];pin,count,width,height=PINS[ident];found=lookup_movie(GAME,'L1_DC',binding['movie']);head=found['vqhd'];assert found['sha256']==pin and(head['count'],head['width'],head['height'],head['fps'])==(count,width,height,15)
  path=cache/binding['movie'];path.write_bytes(found['blob']);frames=decode(path,cache/str(ident),count,(width,height));folder=out/str(ident);folder.mkdir(exist_ok=True);rows=[];keys=set()
  for i,p in enumerate(frames):
   im=Image.open(p).convert('RGBA');key=im.getpixel((0,0))[:3];keys.add(key)
   if ident==1916:im=im.transpose(Image.Transpose.ROTATE_270)
   # Pinned pure palette matte, sampled before any manipulation and asserted below.
   im.putdata([(r,g,b,0) if (r,g,b)==key else (r,g,b,255) for r,g,b,_ in im.getdata()])
   target=folder/f'frame_{i:03d}.png';im.save(target);rows.append(dict(file='res://'+str(target.relative_to(ROOT)),sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
  assert len(keys)==1 and next(iter(keys)) in [(0,0,255),(0,251,251)],keys
  samples=sum(len(v)*2 for k,v in parse_vqa_chunks(found['blob']) if k==b'SND2');rate=audio(path,folder/'voice.wav',samples) if samples else 0
  clips[str(ident)]=dict(resource=ident,movie=binding['movie'],sha256=pin,archive=found['archive'],frames=rows,fps=15,width=im.width,height=im.height,matte=list(next(iter(keys))),rotation=270 if ident==1916 else 0,samples=samples,rate=rate,audio='res://'+str((folder/'voice.wav').relative_to(ROOT)),duration=max(count/15,samples/rate if rate else 0))
 (out/'media.json').write_text(json.dumps(dict(version=1,clips=clips),indent=1)+'\n');print('PASS original guardcontrol clips',[(k,len(v['frames']),v['samples'],v['matte']) for k,v in clips.items()])
def cli():
 global GAME,ROOT,SOURCE
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--game',type=Path,required=True)
 parser.add_argument('--source',type=Path,required=True)
 parser.add_argument('--output-root',type=Path,required=True)
 args=parser.parse_args()
 if args.output_root.exists():parser.error('--output-root must be a fresh directory')
 if not args.source.is_file():parser.error('Missing source contract')
 GAME=args.game.resolve();ROOT=args.output_root.resolve();SOURCE=args.source.resolve()
 main()
if __name__=='__main__':
 if len(sys.argv)>1:cli()
 else:main()

