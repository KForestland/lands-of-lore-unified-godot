#!/usr/bin/env python3
"""Extract the exact original EMPT room background; no inferred dialogue ordering."""
import argparse,hashlib,json,tempfile,subprocess
from pathlib import Path
from monastery_media import extract,movie

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 archive=(a.game/'DAT/EMPT.MIX').read_bytes();name='WOMS\\EMPT\\EMPT_.VQA';row=movie(archive,name)
 assert row['sha256']=='9a9a785a4b9f2b261bc6caf7aee09eee10509fb5a9f42bc7a9f5d1e4630bb6be'
 assert (row['frames'],row['width'],row['height'],row['fps'])==(30,640,400,15)
 a.output.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='lol2-empt-')as temp:
  path=Path(temp)/'empt.vqa';path.write_bytes(extract(archive,name)[0])
  subprocess.run(['ffmpeg','-v','error','-y','-threads','1','-i',str(path),'-frames:v','30',str(a.output/'frame_%03d.png')],check=True)
 frames=[{'file':f'frame_{i:03d}.png','sha256':hashlib.sha256((a.output/f'frame_{i:03d}.png').read_bytes()).hexdigest()}for i in range(1,31)]
 dll,binding=extract(archive,'WOMS\\EMPT_.WOM');assert binding['sha256']=='5398dc17f94f5bfcfaa8ebea09f7b15a6012883443c4ee047793fde28a5ab8c4'
 report={'version':1,'background':row,'archive_sha256':hashlib.sha256(archive).hexdigest(),'dll':binding,'frames':frames,'fps':15,'scope':'Original room background. Region3789/group922 requests room21 EMPT through prop254. Modern coffin hotspot/E reward and guards; no native callback/dialogue sequencing replay.'}
 (a.output/'emperor.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS original EMPT background30frames15fps and exact WOM binding')
if __name__=='__main__':main()
