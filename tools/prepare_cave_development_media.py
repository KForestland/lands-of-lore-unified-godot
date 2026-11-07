#!/usr/bin/env python3
"""Prepare the two established Cave development clips and their three-clip provenance."""
import argparse,hashlib,json,struct,subprocess,sys,tempfile,shutil
from pathlib import Path
from lol2_source_format import parse_mix

def sha(data):return hashlib.sha256(data).hexdigest()
def require(value,message):
 if not value:raise ValueError(message)
def prepare(game,re_root,story,output):
 require(not output.exists(),'Output must be fresh')
 for source in (game,re_root,story):require(output!=source and output not in source.parents and source not in output.parents,'Output overlaps input')
 converter=re_root/'tools/convert_cave_video_review.py'
 require(sha(converter.read_bytes())=='fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d','Unsupported converter')
 blob=(game/'DAT/L1_DCI.MIX').read_bytes();require(sha(blob)=='941e6741f689aef0651c2f4a39f9c0c2741fac5b79fb7d0416da433767ea2322','Unsupported Cave movie archive')
 entries=parse_mix(blob)
 def original(index,key,size,digest):
  e=entries[index];raw=blob[e['offset']:e['offset']+e['size']]
  require((e['key'],e['size'],sha(raw))==(key,size,digest),'Original movie binding differs');return raw
 first_source=original(6,2902007471,14900260,'6bd39df40b4ed2517cc959fec347f8bbd40996c226c98ef7c8f5775e2e8a9642')
 first=next(c for c in json.loads((story/'chamber_provenance.json').read_text())['clips'] if c['file']=='kevin_entry6.ogv')
 require(first['source_sha256']==sha(first_source) and first['frames']==558 and first['fps']==15,'Prepared Kenneth binding differs')
 require(sha((story/'kevin_entry6.ogv').read_bytes())==first['sha256'],'Prepared Kenneth output hash differs')
 specs=[('kevin_entry20',20,1020287601,2480236,'acca7e041ae368bcbfc828a1d29c224efba5c60066dee3eadac5efa9f2eb1ae0',150),('bluescreen_entry24',24,1022645873,408250,'8940541d2abae8172fa64f1f8134ff43a70fc1831ece53a11353d5dee8eb5fe4',64)]
 inputs=[(name,original(index,key,size,digest),frames) for name,index,key,size,digest,frames in specs]
 rows=[{k:first[k] for k in ('file','sha256','source_sha256','frames','fps')}]
 with tempfile.TemporaryDirectory(prefix='cave-development-') as temporary:
  stage=Path(temporary)
  for name,raw,frames in inputs:
   source=stage/(name+'.vqa');source.write_bytes(raw);target=stage/(name+'.ogv')
   subprocess.run([sys.executable,str(converter),str(source),str(target)],check=True)
   report=json.loads(target.with_suffix('.json').read_text());require((report['frames'],report['fps'])==(frames,15),'Converted movie frame count differs')
   rows.append(dict(file=target.name,sha256=sha(target.read_bytes()),source_sha256=sha(raw),frames=frames,fps=15))
  out=output/'assets/lol2/video_review';out.mkdir(parents=True)
  for name,_,_ in inputs:shutil.copy2(stage/(name+'.ogv'),out/(name+'.ogv'))
  report=dict(clips=rows,identification='User identifies Kenneth in entries6/20; entry24 is blue-screen clip. Original filename mapping remains unresolved.',conversion='convert_cave_video_review.py, Theora all-keyframe video and Vorbis audio, lossy review assets',legacy_filenames='kevin_entry6.ogv and kevin_entry20.ogv retain their existing paths; displayed character name is Kenneth.')
  (out/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
 print('Prepared two development clips and provenance for three existing review clips')
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('game','re-root','story-root','output-root'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 try:prepare(a.game.resolve(),a.re_root.resolve(),a.story_root.resolve(),a.output_root.resolve())
 except (ValueError,OSError,KeyError,StopIteration,subprocess.CalledProcessError) as error:p.error(str(error))
if __name__=='__main__':main()
