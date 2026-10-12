"""Prepare the original drunk-villager movie with explicit inputs; original media stays local."""
import argparse,json,hashlib,sys,shutil
from pathlib import Path
from PIL import Image
from lol2.map_video_inventory import lookup_movie
from prepare_jungle_exit_movies import decode,audio,parse_vqa_chunks
from prepare_jungle_bacatta_media import segments
p=argparse.ArgumentParser();p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
assert not a.output.exists(),'Use a fresh output directory'
f=lookup_movie(a.game,'L4_HJ','E105E.VQA');assert f['status']=='exact' and f['sha256']=='eb14f0f7bc6309dc6ebf15e17f0332c8540742c5c53b9f13fe3159683e0064a7'
a.output.mkdir(parents=True);cache=a.output/'cache';cache.mkdir();vqa=cache/'E105E.VQA';vqa.write_bytes(f['blob']);h=f['vqhd'];assert (h['count'],h['width'],h['height'],h['fps'])==(582,252,492,15)
frames=decode(vqa,cache/'decoded',582,(252,492));out=a.output/'media';out.mkdir();rows=[]
for i,frame in enumerate(frames):
 im=Image.open(frame).convert('RGBA');key=im.getpixel((0,0))[:3];assert key==(0,251,251),key
 im=im.transpose(Image.Transpose.ROTATE_270);im.putdata([(r,g,b,0 if (r,g,b)==key else 255) for r,g,b,_ in im.getdata()]);name=f'frame_{i:04d}.png';im.save(out/name);rows.append(name)
samples=sum(len(v)*2 for k,v in parse_vqa_chunks(f['blob']) if k==b'SND2');rate=audio(vqa,out/'voice.wav',samples)
manifest=dict(version=1,sha256=f['sha256'],movie='E105E.VQA',frames=rows,width=492,height=252,fps=15,rotation=270,segments=segments(f['blob'],15),audio='voice.wav',samples=samples,rate=rate)
(out/'media.json').write_text(json.dumps(manifest,indent=2)+'\n');print('PASS',len(rows),'frames; samples',samples,'rate',rate)
