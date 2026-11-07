#!/usr/bin/env python3
"""Prepare original Museum prop163 movie from pinned game archives; no research checkout required."""
import argparse,hashlib,json,tempfile
from pathlib import Path
from PIL import Image
from build_game_atlas import parse_mix
from lol2_movie_media import decode
from vqa_v2_decode import header
ROOT=Path(__file__).resolve().parents[1]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--game',required=True,type=Path);p.add_argument('--out',required=True,type=Path)
 a=p.parse_args();game=a.game.resolve();out=a.out.resolve()
 if out==game or out in game.parents or game in out.parents:p.error('Output overlaps game input')
 if out.exists():p.error('Output must be fresh')
 source=json.loads((ROOT/'scripts/lol2/museum_worm_source.json').read_text())
 arc=(game/'DAT/L3_DH.MIX').read_bytes()
 if sha(arc)!=source['archive_sha256']:raise ValueError('Museum source archive changed')
 def exact(offset,value):
  b=bytes.fromhex(value)
  if arc[offset:offset+len(b)]!=b:raise ValueError('Museum source record changed')
 exact(source['placement_offset'],source['placement_hex'])
 for row in source['runtime']['regions']:
  exact(row['region_archive_offset'],row['region_hex'])
  for c in row['commands']:exact(c['archive_offset'],c['raw_hex'])
 movie=source['movie'];arc=(game/'DAT/L3_DHI.MIX').read_bytes()
 if sha(arc)!=movie['archive_sha256']:raise ValueError('Museum movie archive changed')
 entry=next(e for e in parse_mix(arc) if e['key']==2592634170)
 if entry['offset']!=movie['entry']['offset'] or entry['size']!=movie['entry']['size']:raise ValueError('Movie entry changed')
 blob=arc[entry['offset']:entry['offset']+entry['size']]
 if sha(blob)!=movie['movie_sha256']:raise ValueError('Movie changed')
 top,fields=header(blob)
 if fields!=movie['header'] or any(tag.startswith(b'SND') for tag,payload in top):raise ValueError('Unexpected movie header or audio')
 with tempfile.TemporaryDirectory(prefix='museum-worm-') as temp:
  temp=Path(temp);path=temp/'WRM-PORT.VQA';path.write_bytes(blob)
  frames=decode(path,temp/'frames',60,(600,336))
  atlas=Image.new('RGBA',(6000,2016))
  for i,path in enumerate(frames):
   im=Image.open(path).convert('RGBA')
   if im.getpixel((0,0))[:3]!=(0,251,251):raise ValueError('Movie key changed')
   im.putdata([(r,g,b,0 if (r,g,b)==(0,251,251) else 255) for r,g,b,alpha in im.getdata()])
   atlas.paste(im,(i%10*600,i//10*336))
  out.mkdir(parents=True);atlas.save(out/'atlas.png')
  (out/'source.json').write_text(json.dumps(source['runtime'],indent=2)+'\n')
 print('PASS original Museum worm60frames15fps, pinned source events and placement')
if __name__=='__main__':main()
