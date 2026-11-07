#!/usr/bin/env python3
"""Stage source SLAVES room background, idle/refusal patches and full release movie.

Media/source preparation only. World globe joins and the native dead-Ruloi producer
remain separate from this pinned room consumer; this tool does not implement them.
"""
import argparse,hashlib,json,struct,subprocess
from pathlib import Path
from monastery_media import extract,movie,stage_patch

def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output-root',type=Path,default=Path('.'));a=p.parse_args();root=a.output_root.resolve()
 out=root/'assets/lol2/generated/l13_prison';out.mkdir(parents=True,exist_ok=True);cache=root/'tmp/l13_prison_media';cache.mkdir(parents=True,exist_ok=True)
 archive=(a.game/'DAT/SLAVES.MIX').read_bytes();dll,binding=extract(archive,'WOMS\\SLAVES_.WOM');assert binding['sha256']=='9a6b48c823cc9c31d5a58ae4c87e0eb560afd84a3769ddbbdfc88e7a3b3db818'
 module=dll[48:48+struct.unpack_from('<I',dll,36)[0]]
 assert module[0x9c0:].split(b'\0')[0]==b'LV_RULOI_DEAD'
 assert module[0x9d5:].split(b'\0')[0]==b'LV_SLAVES_CELL_OPEN'
 # Read-only disassembly witness: room setup loads both named locals; release
 # branch requires cached dead !=0 and open ==0, sets open1, plays51/200/13.
 # Pin the exact consumer branch as well as the complete WOM, without pretending
 # to execute native callbacks or joining the world's local-variable producer.
 branch=module[0x5ff:0x6b3]
 background=movie(archive,'WOMS\\SLAVES\\SLAVES_.VQA');assert background['sha256']=='9290b8ee09206cb6033092ff2a57b9cf8b71f68fc8f3ce8d41b2d9a0e211f2c3'
 data,_=extract(archive,background['name']);vqa=cache/'slaves.vqa';vqa.write_bytes(data)
 subprocess.run(['ffmpeg','-v','error','-y','-threads','1','-i',str(vqa),'-frames:v','30',str(out/'background_%03d.png')],check=True)
 patches={}
 pins={999:'14c07a3feacc9f1fcdd0905768db101d3d17ba9281b50c034c996fa745221a77',11:'6f33035dedb3af3b4e86290ba9d012a773df8af4773a94d0cb2c333246281bba'}
 for line,pin in pins.items():
  name=f'WOMS\\SLAVES\\51{line:03}13E.VQA';row=movie(archive,name);assert row['sha256']==pin;data,_=extract(archive,name);vqa=cache/f'{line}.vqa';vqa.write_bytes(data)
  patches[str(line)]=stage_patch(vqa,out/f'{line}.png',row,root)
 name='WOMS\\SLAVES\\5120013E.VQA';release=movie(archive,name);assert release['sha256']=='cd0609e95ee3761ae0ec99032d608aad095956e33edd7bb90b2d8bfbcb6ae70e';data,_=extract(archive,name);vqa=cache/'release.vqa';vqa.write_bytes(data)
 release=stage_patch(vqa,out/'release.png',release,root)
 report=dict(version=1,archive_sha256=sha(archive),dll=binding,release_branch=dict(module_offset=0x5ff,raw_hex=branch.hex()),background=background,patches=patches,release=release,scope='Original room media and named-local consumer. No world globe/room trigger or live-Ruloi producer join; no native runtime acceptance.')
 (out/'prison.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS original SLAVES30 background frames,60 idle/140 refusal patch frames,722 release frames; room hosting pending')
if __name__=='__main__':main()
