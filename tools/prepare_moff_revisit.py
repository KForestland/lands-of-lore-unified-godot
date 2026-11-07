#!/usr/bin/env python3
"""Stage Julian's revisit/exit clips (MOFF.MIX) and the original Power Orb icon.

Sequences are exactly the movie lists produced by docs/moff-revisit-checks.json.
Output: assets/lol2/generated/monastery_moff/moff.json (+ clips, icon) and
docs/moff-revisit-media-checks.json. Existing monastery_rooms assets are only read.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_moff_revisit.py --game GAME --checks docs/moff-revisit-checks.json --output-root FRESH
Published helpers only (tools/monastery_media.py, lol2_source_format, lol2_creature_sprite_format); stages the
monastery_moff pack and writes no docs. Without arguments the historical behaviour is unchanged.
"""
import json,struct,subprocess,sys,wave
from PIL import Image
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
 import argparse,shutil
 from pathlib import Path
 import monastery_media
 from monastery_media import digest,extract,movie
 from lol2_source_format import parse_mix,u32
 from lol2_creature_sprite_format import sections,rgb_palette,decode_rows
 ROOT=GAME=None  # set by cli()

 def stage_patch(source,target,record):
  return monastery_media.stage_patch(source,target,record,ROOT)

 def entry(filename,key):  # as prepare_hive_wax.entry
  archive=(GAME/filename).read_bytes()
  row=next(e for e in parse_mix(archive) if e['key']==key)
  return archive[row['offset']:][:row['size']]
else:
 from audit_monastery_rooms import ROOT,GAME,digest,extract,movie
 from prepare_monastery_rooms import stage_patch
 from prepare_hive_wax import entry,sections,rgb_palette,decode_rows,u32

SEQUENCES={'MOFF_REVISIT':[400,401,402,403,404,406],'MOFF_REVISIT_LATE':[450,451,452,453],'MOFF_HELD_RUNES':[500,501,502,503,504,505],
 'MOFF_TRANSLATED':[600,601,602,603,604],'MOFF_EXIT_FIRST':[384,385],'MOFF_EXIT_SECOND':[407,408,409,410,411,412],'MOFF_EXIT_LATER':[407],
 'MOFF_EXIT_RUNES':[506,507],'MOFF_EXIT_ORB':[564,565,566,567],'MOFF_EXIT_DEAD':[386,387]}
OUT=ROOT/'assets/lol2/generated/monastery_moff' if ROOT else None
ORB_ID='monastery:item83:Power_Orb'

def main(checks_path=None,write_docs=True):
 checks=json.loads((checks_path or ROOT/'docs/moff-revisit-checks.json').read_text())
 native={tuple(e[2] for e in c['effects'] if e[0]=='movie') for k in ('entry','exit') for c in checks['cases'][k]}
 for name,lines in SEQUENCES.items():assert any(tuple(lines)==m[:len(lines)] or tuple(lines)==m[-len(lines):] for m in native),name
 arc=(GAME/'DAT/MOFF.MIX').read_bytes();assert digest(arc)==checks['archive_sha256']
 OUT.mkdir(parents=True,exist_ok=True);cache=ROOT/'tmp/monastery_moff_source';cache.mkdir(parents=True,exist_ok=True)
 staged={};frames={};samples={}
 for name,lines in SEQUENCES.items():
  speaker=1 if name=='MOFF_EXIT_DEAD' else 22;clips=[]
  for line in lines:
   key=f'{speaker:02d}{line:03d}07E'
   if speaker==22:
    record=movie(arc,f'WOMS\\MOFF\\{key}.VQA');payload,_=extract(arc,f'WOMS\\MOFF\\{key}.VQA');path=cache/(key+'.VQA');path.write_bytes(payload)
    clip=stage_patch(path,OUT/(key+'.ogv'),record)
   else:
    payload,binding=extract(arc,f'WOMS\\MOFF\\{key}.AUD');rate,packed,decoded,_,_=struct.unpack_from('<HIIBB',payload);assert len(payload)==packed+12
    path=cache/(key+'.AUD');path.write_bytes(payload);target=OUT/(key+'.wav')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-ac','1','-c:a','pcm_s16le',str(target)],check=True)
    with wave.open(str(target)) as f:assert f.getnframes()*2==decoded and f.getframerate()==rate;n=f.getnframes()
    clip=dict(binding,frames=0,audio='res://'+str(target.relative_to(ROOT)),audio_samples=n*22050//rate,duration=n/rate)
   clips.append(clip)
  staged[name]=clips;frames[name]=[c['frames'] for c in clips];samples[name]=[c['audio_samples'] for c in clips]
 # Original item definition and inventory icon, as for the MAGIC shop grants.
 definitions=entry('GLOBAL.MIX',3984507021);graphics=entry('LOCAL.MIX',4018716831)
 base,n=u32(definitions,4),u32(definitions,0x34);so=base+n*91+4;fo=so+u32(definitions,so-4)*16+4;names=fo+u32(definitions,fo-4)*12
 index=next(i for i in range(n) if definitions[names+i*30:names+i*30+24].split(b'\0')[0]==b'83-Power orb')
 d=definitions[base+index*91:][:91];assert d[46]+d[47]==1
 resource=struct.unpack_from('<h',definitions,fo+index*12)[0];sec=sections(graphics);desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
 w,h,pixels,_=decode_rows(graphics[sec[3]+desc[7]:][:desc[12]],allow_special=True);assert (w,h)==desc[1:3]
 palette=rgb_palette(graphics[u32(graphics,4):][:768],6)
 Image.frombytes('RGBA',(w,h),bytes(c for p in pixels for c in (*palette[p*3:p*3+3],0 if p in (0,1) else 255))).save(OUT/'Power_Orb.png')
 item=dict(name='83-Power orb',label='Power Orb',definition=index,resource=resource,icon='res://assets/lol2/generated/monastery_moff/Power_Orb.png',definition_hex=d.hex(),pixels_sha256=digest(pixels),size=[w,h])
 manifest=dict(version=1,sequences=staged,items={ORB_ID:item})
 (OUT/'moff.json').write_text(json.dumps(manifest,indent=1)+'\n')
 report=dict(passed=True,manifest_sha256=digest((OUT/'moff.json').read_bytes()),frames=frames,samples=samples,item=item,
  scope='All34 Julian VQA patches and two Luther AUD lines requested by the native MOFF entry/exit matrix, exact frame and PCM counts; original 83-Power orb definition and inventory icon. Presentation flags and appearance are not verified here.')
 if write_docs:(ROOT/'docs/moff-revisit-media-checks.json').write_text(json.dumps(report,indent=1)+'\n')
 print('FRAMES',json.dumps(frames));print('SAMPLES',json.dumps(samples));print('ORB',index,resource,(w,h))
CHECKS_SHA256='93ab1761664c9e0df1daf7a9657979cfd72e23ba6d0e8b34a13a6a64fc5985b9'  # docs/moff-revisit-checks.json (published)
ITEM_ENTRIES={('GLOBAL.MIX',3984507021):'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891',
              ('LOCAL.MIX',4018716831):'36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'}

def cli():
 global ROOT,GAME,OUT
 p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
 for name in ['game','checks','output-root']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 if a.output_root.exists():p.error('--output-root must be a fresh directory')
 for tool in ['ffmpeg','ffprobe']:
  if shutil.which(tool) is None:p.error(tool+' not found on PATH')
 if not a.checks.is_file():p.error('Missing input: '+str(a.checks))
 if digest(a.checks.read_bytes())!=CHECKS_SHA256:p.error(f'{a.checks}: not the pinned MOFF revisit checks ({CHECKS_SHA256})')
 checks=json.loads(a.checks.read_text())
 for rel in ['DAT/MOFF.MIX','GLOBAL.MIX','LOCAL.MIX']:
  if not (a.game/rel).is_file():p.error('Missing original '+str(a.game/rel))
 GAME=a.game.resolve()
 try:
  arc=(GAME/'DAT/MOFF.MIX').read_bytes();assert digest(arc)==checks['archive_sha256'],'MOFF.MIX is not the pinned original'
  assert digest(extract(arc,'WOMS\\MOFF_.WOM')[0])==checks['dll_sha256'],'MOFF DLL'
  native={tuple(e[2] for e in c['effects'] if e[0]=='movie') for k in ('entry','exit') for c in checks['cases'][k]}
  for name,lines in SEQUENCES.items():
   assert any(tuple(lines)==m[:len(lines)] or tuple(lines)==m[-len(lines):] for m in native),name
   for line in lines:
    if name=='MOFF_EXIT_DEAD':extract(arc,f'WOMS\\MOFF\\01{line:03d}07E.AUD')
    else:movie(arc,f'WOMS\\MOFF\\22{line:03d}07E.VQA')
  for (rel,key),want in ITEM_ENTRIES.items():assert digest(entry(rel,key))==want,rel
 except (AssertionError,StopIteration,KeyError,ValueError,IndexError,struct.error) as error:
  p.error('Originals do not match the recorded inputs: '+(str(error) or type(error).__name__))
 ROOT=a.output_root.resolve();OUT=ROOT/'assets/lol2/generated/monastery_moff'
 main(a.checks.resolve(),write_docs=False)

if __name__=='__main__':
 if EXPLICIT:cli()
 else:main()
