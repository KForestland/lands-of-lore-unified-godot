#!/usr/bin/env python3
"""Extract original standing Baccata idle movie; inversion into a hanging trap is a separate modern adapter."""
import argparse,hashlib,json,tempfile
from pathlib import Path
from PIL import Image
from lol2.map_video_inventory import lookup_movie
from lol2_movie_media import decode

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 root=Path(__file__).resolve().parents[1]
 blob=(a.game/'DAT/L8_SJ.MIX').read_bytes()
 assert hashlib.sha256(blob).hexdigest()=='3eff07430a453d2c6f09133f869874e0530af1b6a3bfff7f4297761b96a28bc2'
 native=json.loads((root/'scripts/lol2/native_scripts/L8_SJ.json').read_text())
 objects=[o for o in native['objects'] if o['ref'] in ['prop:100','prop:101','prop:1117','prop:1122','actor:116']]
 for obj in objects:
  raw=bytes.fromhex(obj['placement_hex']);at=obj['file_offset'];assert blob[at:at+len(raw)]==raw
 groups=[g for g in native['groups'] if g['group'] in [9604,11282]]
 for group in groups:
  raw=bytes.fromhex(group['raw_hex']);at=group['file_offset'];assert blob[at:at+len(raw)]==raw
 assert len(objects)==5 and len(groups)==2
 row=lookup_movie(a.game,'L8_SJ','bc08.vqa')
 assert row['status']=='exact' and row['sha256']=='2de265038589dd81c5916ee73d9b334cf90a36dccb5cfb0604a30e1cfea77314'
 h=row['vqhd'];assert (h['count'],h['width'],h['height'],h['fps'])==(47,268,200,15)
 a.output.mkdir(parents=True,exist_ok=True);frames=[]
 with tempfile.TemporaryDirectory(prefix='lol2-priest-') as folder:
  root=Path(folder);movie=root/'bc08.vqa';movie.write_bytes(row['blob'])
  for i,path in enumerate(decode(movie,root/'frames',47,(268,200))):
   source=Image.open(path).convert('RGBA');key=source.getpixel((0,0))[:3]
   assert key[0]==0 and key[1]>200 and key[2]>200
   source.putdata([(r,g,b,0 if (r,g,b)==key else 255) for r,g,b,_ in source.getdata()])
   out=a.output/f'frame_{i:03d}.png';source.save(out);frames.append({'file':out.name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
 report={'version':1,'prop':100,'template':32,'selector':0,'descriptor':253,'movie':'bc08.vqa','sha256':row['sha256'],'frames':frames,'fps':15,'source_position':[4549,100,-1006],'scope':'Original standing idle pixels/rate; inversion, cyan-key billboard, post-shore visibility and cut interaction are modern adapters. No recovered hanging animation, conversation or native trap state claim.'}
 (a.output/'trap.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS original Baccata standing idle:47 frames,15fps, exact movie hash')
if __name__=='__main__':main()
