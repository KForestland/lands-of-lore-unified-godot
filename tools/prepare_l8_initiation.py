#!/usr/bin/env python3
"""Pin SHAMAN's Silverleaf-to-arena branch and stage its four original speech clips."""
import argparse,hashlib,json,struct,subprocess,tempfile,wave
from pathlib import Path
from lol2_source_format import parse_mix
from lol2_movie_format import ww_hash_v1
from verify_chut_room_sources import slots,calls
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
blob=(a.game/'DAT/SHAMAN.MIX').read_bytes();rows=parse_mix(blob)
def extract(name):
 r=next(r for r in rows if r['key']==ww_hash_v1(name));return blob[r['offset']:r['offset']+r['size']]
dll=extract('WOMS\\SHAMAN_.WOM');assert hashlib.sha256(dll).hexdigest()=='f655c92f96aa2ca8ecb59a50d84d7cfed38e5a3736c8dc2b942efc4ead7eaab5'
im=dll[48:48+struct.unpack_from('<I',dll,36)[0]];table=slots(im);branch=calls(im,table,0x746,0x8ab)
assert [(x['host'],x['args']) for x in branch if x['host']=='movie'][:4]==[('movie',[42,329,11]),('movie',[1,330,11]),('movie',[42,331,11]),('movie',[42,332,11])]
assert any(x['host']=='place' and x['args']==[2679,4187] for x in branch)
assert im[0x1ce3:].split(b'\0')[0]==b'115-Silverleaf'
a.output.mkdir(parents=True,exist_ok=True);clips=[]
for speaker,line in [(42,329),(1,330),(42,331),(42,332)]:
 suffix='AUD' if speaker==1 else 'VQA';name=f'WOMS\\SHAMAN\\{speaker:02}{line:03}11E.{suffix}';data=extract(name)
 with tempfile.TemporaryDirectory(prefix='astra-initiation-') as directory:
  source=Path(directory)/('clip.'+suffix.lower());source.write_bytes(data);target=a.output/f'{line}.wav'
  subprocess.run(['ffmpeg','-v','error','-y','-threads','1','-i',str(source),'-vn','-ac','1','-c:a','pcm_s16le',str(target)],check=True,capture_output=True)
  with wave.open(str(target)) as w:duration=w.getnframes()/w.getframerate()
  clips.append(dict(speaker=speaker,line=line,view=11,name=name,source_sha256=hashlib.sha256(data).hexdigest(),wav=target.name,wav_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),duration=duration))
(a.output/'manifest.json').write_text(json.dumps(dict(version=1,archive_sha256=hashlib.sha256(blob).hexdigest(),clips=clips,place=[2679,4187],heading_interpretation=45,scope='Original four speech clips and source place call; audio-only presentation, combat and nonlethal outcome are adapters. Host120/124 meanings unjoined.'),indent=1)+'\n')
print('PASS SHAMAN source offer branch,4 original clips, place2679/4187; no native arena combat claim')
