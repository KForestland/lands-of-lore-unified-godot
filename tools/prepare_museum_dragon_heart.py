#!/usr/bin/env python3
"""Rebuild original Museum dragon-heart idle/movie/spent art, gem icon and audio."""
import argparse,hashlib,json,shutil,sys,tempfile
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/lol2'))
from lol2 import map_props as props,map_materials
from lol2_source_format import parse_mix
from lol2_movie_media import decode,audio
from vqa_v2_decode import header
from prepare_museum_key_locks import icon

def sha(b):return hashlib.sha256(b).hexdigest()
def prepare(game,out):
 game=game.resolve();out=out.resolve()
 if out==game or out in game.parents or game in out.parents:raise ValueError('Output overlaps input')
 if out.exists():raise ValueError('Output must be fresh')
 c=json.loads((ROOT/'scripts/lol2/museum_dragon_heart_source.json').read_text())
 arc=(game/'DAT/L3_DH.MIX').read_bytes()
 if sha(arc)!=c['source']['source']['sha256']:raise ValueError('Museum archive changed')
 def exact(offset,hexdata):
  data=bytes.fromhex(hexdata)
  if arc[offset:offset+len(data)]!=data:raise ValueError('Source record changed')
 p=c['template']['placement'];exact(p['placement_offset'],p['placement_hex'])
 exact(c['source']['item']['archive_offset'],c['source']['item']['raw'])
 for group in c['source']['groups']:
  for command in group['commands']:exact(command['archive_offset'],command['raw_hex'])
 ms=c['movie']['source'];moviearc=(game/ms['archive']).read_bytes()
 if sha(moviearc)!=ms['archive_sha256']:raise ValueError('Movie archive changed')
 e=next(e for e in parse_mix(moviearc) if e['key']==ms['key']);blob=moviearc[e['offset']:e['offset']+e['size']]
 if sha(blob)!=ms['sha256']:raise ValueError('Movie changed')
 top,fields=header(blob)
 if fields!=c['movie']['header']:raise ValueError('Movie header changed')
 with tempfile.TemporaryDirectory(prefix='museum-heart-') as tmp:
  tmp=Path(tmp);staged=tmp/'staged';staged.mkdir();movie=tmp/'DRGNHRT.VQA';movie.write_bytes(blob)
  frames=decode(movie,tmp/'frames',20,(304,168));atlas=Image.new('RGBA',(1520,672))
  # The pinned decoder expands source VGA blue 63 to 251, not 255.
  # Key only that exact colour; retain every foreground pixel and RGB byte.
  for i,path in enumerate(frames):
   im=Image.open(path).convert('RGBA');im.putdata([(r,g,b,0 if (r,g,b)==(0,0,251) else 255) for r,g,b,a in im.getdata()]);atlas.paste(im,(i%5*304,i//5*168))
  atlas.save(staged/'atlas.png')
  samples=sum(len(p)*2 for t,p in top if t==b'SND2');rate=audio(movie,staged/'voice.wav',samples)
  if samples!=40424 or rate!=22050:raise ValueError('Audio changed')
  map_materials.export_materials(game,'L3_DH',tmp/'materials')
  tex=(tmp/'materials/texture.bin').read_bytes();sec=props.mm.sections(tex);rgb=props.mm.rgb_palette(tex[props.u32(tex,4):][:768],6)
  art=tmp/'art';(art/'sprites').mkdir(parents=True)
  for descriptor in [121,836]:
   im=props.build_image(descriptor,tex,sec,rgb,art/'sprites',art,{})
   shutil.copyfile(art/im.get('frames',[im['image']])[0],staged/f'descriptor_{descriptor}.png')
  icon(86,staged/'gem.png',game=game)
  for name,wanted in c['assets']['files'].items():
   if sha((staged/name).read_bytes())!=wanted:raise ValueError('Prepared asset changed: '+name)
  shutil.copytree(staged,out)
 print('PASS original dragon-heart5assets; idle/spent/movie/audio/gem')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',required=True,type=Path);p.add_argument('--out',required=True,type=Path);a=p.parse_args();prepare(a.game,a.out)
