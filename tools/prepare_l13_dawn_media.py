#!/usr/bin/env python3
"""Stage original DSLAVE background and Dawn's imprisoned idle patch; no speech order inference."""
import argparse,json,hashlib,subprocess
from pathlib import Path
from monastery_media import extract,movie,stage_patch
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output-root',type=Path,default=Path('.'));a=p.parse_args();root=a.output_root.resolve();out=root/'assets/lol2/generated/l13_dawn';out.mkdir(parents=True,exist_ok=True);cache=root/'tmp/l13_dawn_media';cache.mkdir(parents=True,exist_ok=True)
b=(a.game/'DAT/DSLAVE.MIX').read_bytes();dll,binding=extract(b,'WOMS\\DSLAVE_.WOM');assert binding['sha256']=='747559de48b7955444d36267ec34ad2146d7ac4e7a1d79a16fd902fc53465b6f'
bg=movie(b,'WOMS\\DSLAVE\\DSLAVE_.VQA');assert bg['sha256']=='bda4a8e3bc08bed252f5dd58d918dfbd26d84b2c41e9fc3c830efae24f21aa3e';raw,_=extract(b,bg['name']);vqa=cache/'background.vqa';vqa.write_bytes(raw);subprocess.run(['ffmpeg','-v','error','-y','-threads','1','-i',str(vqa),'-frames:v','30',str(out/'background_%03d.png')],check=True)
name='WOMS\\DSLAVE\\0399913E.VQA';idle=movie(b,name);assert idle['sha256']=='54b0725b08f7af619fb6c80ce317f0eb7dbdd2d589d9813c88d9c1caaa7c43d2';raw,_=extract(b,name);vqa=cache/'idle.vqa';vqa.write_bytes(raw);idle=stage_patch(vqa,out/'idle.png',idle,root)
(out/'dawn.json').write_text(json.dumps(dict(version=1,archive_sha256=hashlib.sha256(b).hexdigest(),dll=binding,background=bg,idle=idle,scope='Original imprisoned Dawn idle and room background; interaction, speech order and item offer separate.'),indent=1)+'\n');print('PASS original DSLAVE30 background frames and60 imprisoned Dawn idle frames')
