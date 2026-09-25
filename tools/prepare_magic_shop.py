#!/usr/bin/env python3
"""Stage source-pinned Rashar room media without rebuilding other rooms."""
import json,subprocess
from pathlib import Path
from audit_monastery_rooms import ROOT,GAME,digest,extract
from audit_act_one_shops import main as audit
from prepare_monastery_rooms import stage_patch,convert

def main():
 audit()
 source=json.loads((ROOT/'docs/act-one-shops-source.json').read_text())['rooms']['MAGIC']
 archive=(GAME/'DAT/MAGIC.MIX').read_bytes();assert digest(archive)==source['archive_sha256']
 out=ROOT/'assets/lol2/generated/magic_shop';out.mkdir(parents=True,exist_ok=True)
 cache=ROOT/'tmp/magic_shop_source';cache.mkdir(parents=True,exist_ok=True)
 staged={}
 for record in [source['background'],source['idle']]+source['movies']:
  name=record['name'].split('\\')[-1];payload,binding=extract(archive,record['name']);assert digest(payload)==record['sha256']
  path=cache/name;path.write_bytes(payload);target=out/(Path(name).stem+'.ogv')
  if record is source['background']:
   convert(path,target)
   png=out/'background.png';subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-frames:v','1',str(png)],check=True)
   staged['background']=dict(record,path='res://'+str(target.relative_to(ROOT)),duration=record['frames']/record['fps'])
   staged['background_still']='res://'+str(png.relative_to(ROOT))
  else:
   clip=stage_patch(path,target,record)
   if record is source['idle']:staged['idle']=clip
   else:staged.setdefault('lines',{})[str(int(Path(name).stem[2:5]))]=clip
 staged['canvas']=[640,400]
 (out/'room.json').write_text(json.dumps(staged,indent=2)+'\n')
 report=dict(passed=True,manifest='assets/lol2/generated/magic_shop/room.json',manifest_sha256=digest((out/'room.json').read_bytes()),lines=len(staged['lines']),frames=sum(x['frames'] for x in staged['lines'].values()),samples=sum(x['audio_samples'] for x in staged['lines'].values()),scope='Original Rashar background and idle plus30 source-audited dialogue patches decoded. Exact per-patch frame and PCM sample counts checked. Live integration, appearance review, entry effects and original timing remain separate.')
 (ROOT/'docs/magic-shop-media-checks.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
if __name__=='__main__':main()
