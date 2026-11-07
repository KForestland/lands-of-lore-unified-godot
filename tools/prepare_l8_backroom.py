#!/usr/bin/env python3
"""Stage original shaman doorway audio; source clip order from Grok shbak_news_card.md."""
import argparse,json,hashlib,subprocess,tempfile,wave,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from build_game_atlas import parse_mix
from lol2_movie_format import ww_hash_v1
out=root/'assets/lol2/generated/l8_backroom';out.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--game',type=Path,default=Path('~/lol2_runtime_root'))
args=parser.parse_args()
rows=[]
for line in range(225,238):
 room='SHAMAN' if line<228 or line>235 else 'SHBAK'
 speaker='01' if line in [225,233,234] else '42'
 suffix='AUD' if speaker=='01' else 'VQA'
 name=f'WOMS\\{room}\\{speaker}{line}11E.{suffix}'
 b=(args.game/'DAT'/(room+'.MIX')).read_bytes()
 rec=next(r for r in parse_mix(b) if r['key']==ww_hash_v1(name))
 blob=b[rec['offset']:rec['offset']+rec['size']]
 with tempfile.TemporaryDirectory(prefix='astra-news-') as tmp:
  src=Path(tmp)/('clip.'+suffix.lower());src.write_bytes(blob)
  wav=out/f'{line}.wav'
  result=subprocess.run(['ffmpeg','-v','error','-y','-threads','1','-i',str(src),'-vn','-ac','1','-c:a','pcm_s16le',str(wav)],capture_output=True,text=True)
  if result.returncode:raise RuntimeError(name+': '+result.stderr[-500:])
  with wave.open(str(wav)) as w:
   assert w.getnframes()>0
   duration=w.getnframes()/w.getframerate()
  rows.append(dict(line=line,name=name,archive_sha256=hashlib.sha256(b).hexdigest(),source_sha256=hashlib.sha256(blob).hexdigest(),wav=f'{line}.wav',wav_sha256=hashlib.sha256(wav.read_bytes()).hexdigest(),duration=duration))
  print(line,round(duration,2),flush=True)
(out/'manifest.json').write_text(json.dumps(dict(version=1,main=list(range(225,236)),followups=[236,237],clips=rows),indent=1)+'\n')
