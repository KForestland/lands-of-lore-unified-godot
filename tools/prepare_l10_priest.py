#!/usr/bin/env python3
"""Extract original prop158/template34/selector1 idle movie; cyan matte is an explicit presentation adapter."""
import argparse,hashlib,json,tempfile
from pathlib import Path
from PIL import Image
from lol2.map_video_inventory import lookup_movie
from lol2_movie_media import decode

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 row=lookup_movie(a.game,'L10_DC','47loiter.vqa')
 assert row['status']=='exact' and row['sha256']=='51239900c4a033feb81613e9efc0af891d5a4f02d7467b59dd2e896402316c99'
 h=row['vqhd'];assert (h['count'],h['width'],h['height'],h['fps'])==(20,236,196,15)
 a.output.mkdir(parents=True,exist_ok=True);frames=[]
 with tempfile.TemporaryDirectory(prefix='lol2-priest-') as folder:
  root=Path(folder);movie=root/'47loiter.vqa';movie.write_bytes(row['blob'])
  for i,path in enumerate(decode(movie,root/'frames',20,(236,196))):
   source=Image.open(path).convert('RGBA');key=source.getpixel((0,0))[:3]
   assert key[0]==0 and key[1]>200 and key[2]>200
   source.putdata([(r,g,b,0 if (r,g,b)==key else 255) for r,g,b,_ in source.getdata()])
   out=a.output/f'frame_{i:03d}.png';source.save(out);frames.append({'file':out.name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
 report={'version':1,'prop':158,'template':34,'selector':1,'descriptor':322,'movie':'47loiter.vqa','sha256':row['sha256'],'frames':frames,'fps':15,'source_position':[3396,20,-3010],'scope':'Original idle movie pixels/rate; cyan-key billboard, visibility after blue tomb and carried bracers, and interaction are modern adapters. No recovered dialogue or gift timing claim.'}
 (a.output/'priest.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS original priest idle:20 frames,15fps, exact movie hash')
if __name__=='__main__':main()
