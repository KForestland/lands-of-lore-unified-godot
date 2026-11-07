#!/usr/bin/env python3
"""Stage original DSLAVE release dialogue branches pinned by its room module."""
import argparse,json,struct,subprocess,wave
from pathlib import Path
from monastery_media import extract,movie,stage_patch
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output-root',type=Path,default=Path('.'));a=p.parse_args();root=a.output_root.resolve();out=root/'assets/lol2/generated/l13_dawn';cache=root/'tmp/l13_dawn_media';out.mkdir(parents=True,exist_ok=True);cache.mkdir(parents=True,exist_ok=True)
b=(a.game/'DAT/DSLAVE.MIX').read_bytes();dll,binding=extract(b,'WOMS\\DSLAVE_.WOM');assert binding['sha256']=='747559de48b7955444d36267ec34ad2146d7ac4e7a1d79a16fd902fc53465b6f'
m=dll[48:48+struct.unpack_from('<I',dll,36)[0]]
for off,text in [(0xbec,b'GV_DAWN_RELATIONSHIP'),(0xc18,b'134-Dreamstone'),(0xc27,b'GV_LUTHERS_SOUL'),(0xc37,b'78-Bestial disk')]:assert m[off:].split(b'\0')[0]==text
rows={}
raw,audio=extract(b,'WOMS\\DSLAVE\\0150013E.AUD');assert audio['sha256']=='6d730f9f970d8de76db9baaf73717ad151511e4fca1de54538592fbb44612187'
aud=cache/'500.aud';aud.write_bytes(raw);wav=out/'cue_500.wav';subprocess.run(['ffmpeg','-v','error','-y','-i',str(aud),str(wav)],check=True)
with wave.open(str(wav)) as w:audio.update(duration=w.getnframes()/w.getframerate(),audio='res://'+str(wav.relative_to(root)))
rows['500']=audio
for actor,line in [(3,600),(3,951)]:
 name=f'WOMS\\DSLAVE\\{actor:02}{line:03}13E.VQA';row=movie(b,name);assert row['sha256']=={600:'de5ad66a16ac8a77a1a9a4f77caedf1e45c71a7a21f5d64b0cbd9f400d2f12a2',951:'0249751c7352982bb9548ef0a226e4c10832b56de069dadf3f53021765df351d'}[line];raw,_=extract(b,name);vqa=cache/f'{actor}_{line}.vqa';vqa.write_bytes(raw);rows[str(line)]=stage_patch(vqa,out/f'cue_{line}.png',row,root)
 print(line,row['sha256'],row['frames'],flush=True)
(out/'release.json').write_text(json.dumps(dict(version=1,dll=binding,branch=dict(module_offset=0x67e,raw_hex=m[0x67e:0x7cf].hex()),cues=rows),indent=1)+'\n');print('PASS original DSLAVE release branch and dialogue media')
