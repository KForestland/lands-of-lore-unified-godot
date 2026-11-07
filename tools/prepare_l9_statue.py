#!/usr/bin/env python3
"""Extract the exact original STAT room background; no inferred dialogue ordering."""
import argparse,hashlib,json,tempfile,subprocess
from pathlib import Path
from monastery_media import extract,movie

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 archive=(a.game/'DAT/STAT.MIX').read_bytes();name='WOMS\\STAT\\STAT_.VQA';row=movie(archive,name)
 assert row['sha256']=='b59e12155b73ccf8241cef5a051ed9ffc2a635c75c7a796645e54d00ecba2477'
 assert (row['frames'],row['width'],row['height'],row['fps'])==(30,640,400,15)
 a.output.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='lol2-stat-')as temp:
  path=Path(temp)/'stat.vqa';path.write_bytes(extract(archive,name)[0])
  subprocess.run(['ffmpeg','-v','error','-y','-threads','1','-i',str(path),'-frames:v','30',str(a.output/'frame_%03d.png')],check=True)
 frames=[{'file':f'frame_{i:03d}.png','sha256':hashlib.sha256((a.output/f'frame_{i:03d}.png').read_bytes()).hexdigest()}for i in range(1,31)]
 dll,binding=extract(archive,'WOMS\\STAT_.WOM');assert binding['sha256']=='7a9366c52cadb104c45e3039da35aefcb5d11635b8f9c2619de27aac984aa097'
 report={'version':1,'background':row,'archive_sha256':hashlib.sha256(archive).hexdigest(),'dll':binding,'frames':frames,'fps':15,'scope':'Original room background. Region3185/group3774 requests room20 STAT through prop2622. Original bowl hotspot0(145,185)-(275,329). Modern Kit offering/guards and persistence; native stat_wlk transition and callback timing not replayed.'}
 (a.output/'statue.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS original STAT background30frames15fps and exact WOM binding')
if __name__=='__main__':main()
