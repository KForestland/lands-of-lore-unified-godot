#!/usr/bin/env python3
"""Stage original monastery garden/cellar first visits and source admission cases.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_monastery_side_rooms.py --game GAME --re-root RE --fixture tests/fixtures/monastery_side_rooms.json \
      --recipe scripts/lol2/monastery_side_rooms_source.json --output-root FRESH
The explicit path stages assets/lol2/generated/monastery_side_rooms only. Sequence effects come from the published
native admission fixture (the same flag/global/local queries the legacy replay uses); the compact recipe carries only
the recorded DLL callback addresses of rooms.json 'sources'. Published helpers only (tools/monastery_media.py); the RE
checkout supplies only the pinned video converter. It never writes the fixture or docs. Without arguments the
historical native path (RoomReplay, fixture and docs writes) is unchanged.
"""
import json,struct,itertools,sys
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
 import argparse,shutil,subprocess
 from pathlib import Path
 import monastery_media
 from monastery_media import extract,movie,digest
 ROOT=convert=None  # set by cli()

 def stage_patch(source,target,record):
  return monastery_media.stage_patch(source,target,record,ROOT)
else:
 from audit_weapon_shop import RoomReplay
 from audit_monastery_rooms import ROOT,extract,movie,digest
 from prepare_monastery_rooms import stage_patch,convert

def stage_room(name,archive,runs,out,cache):
 """Background, idle and the movies of each (sequence, effects) run, as the legacy loop stages them."""
 key=f'WOMS\\{name}\\{name}_.VQA';record=movie(archive,key);path=cache/f'{name}_.VQA';path.write_bytes(extract(archive,key)[0]);target=out/f'{name}_.ogv';convert(path,target)
 room=dict(background=dict(record,path='res://'+str(target.relative_to(ROOT))),movies=[]);seq={}
 speaker=24 if name=='MCEL' else 23
 key=f'WOMS\\{name}\\{speaker:02d}99907E.VQA';record=movie(archive,key);path=cache/f'{speaker}99907E.VQA';path.write_bytes(extract(archive,key)[0]);room['idle']=stage_patch(path,out/f'{speaker}99907E.ogv',record)
 for sequence,effects in runs:
  media=[]
  for e in effects:
   if e[0]!='movie':continue
   filename=f'{e[1]:02d}{e[2]:03d}{e[3]:02d}E.VQA';key=f'WOMS\\{name}\\{filename}';record=movie(archive,key);path=cache/filename;path.write_bytes(extract(archive,key)[0]);media.append(stage_patch(path,out/(filename[:-4]+'.ogv'),record))
  room['repeat_movies' if sequence=='MGAR_REPEAT' else 'movies']=media
  seq[sequence]=dict(frames=[m['frames'] for m in media],samples=[m['audio_samples'] for m in media],effects=effects)
 return room,seq

def main():
 out=ROOT/'assets/lol2/generated/monastery_side_rooms';out.mkdir(parents=True,exist_ok=True)
 cache=ROOT/'tmp/monastery_side_source';cache.mkdir(parents=True,exist_ok=True)
 rooms={};seq={};sources={};cases=[]
 for name in ['MCEL','MGAR']:
  r=RoomReplay(name);source={'dll_sha256':digest(r.dll),'archive_sha256':digest(r.archive),'callbacks':r.callbacks};sources[name]=source
  runs=[(sequence,r.run(9,flags=flags,locals_={'Met_Dawn':1})['effects']) for sequence,flags in [(name,{})]+([('MGAR_REPEAT',{'258':1})] if name=='MGAR' else [])]
  room,s=stage_room(name,r.archive,runs,out,cache);seq.update(s)
  rooms[name]=room
  if name=='MGAR':
   for dead,met,translated,departed,repeated in itertools.product(range(2),repeat=5):
    flags={'181':dead,'258':met,'140':translated,'259':departed,'260':repeated};q=r.run(9,flags=flags)
    present=any(e[0]=='animation' for e in q['setup']);expected=not(dead or(not met and translated)or departed or repeated)
    assert present==expected
    cases.append(dict(room=name,flags=flags,present=present,entry_effects=q['effects']))
  else:
   for talked,dead,met in itertools.product(range(2),repeat=3):
    flags={'170':talked};g={'GV_RIX_DEAD':dead};local={'Met_Dawn':met};q=r.run(9,flags,g,local)
    present=any(e[0]=='animation' for e in q['setup']);assert present==(not(talked or dead))
    speaking=any(e[0]=='movie' for e in q['effects']);assert speaking==bool(not talked and not dead and met)
    cases.append(dict(room=name,flags=flags,globals=g,locals=local,present=present,entry_effects=q['effects']))
 manifest=dict(rooms=rooms,sequences=seq,sources=sources)
 (out/'rooms.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (ROOT/'tests/fixtures/monastery_side_rooms.json').write_text(json.dumps(dict(cases=cases),indent=2)+'\n')
 (ROOT/'docs/monastery-side-rooms-source.json').write_text(json.dumps(dict(passed=True,sources=sources,sequences={k:v['effects'] for k,v in seq.items()},cases=len(cases),scope='Original setup/entry instruction replays with explicit flag/global/local/item query boundaries; first/repeat garden and first cellar conversation. Later power-orb/hostility/timers and response hotspots remain separate.'),indent=2)+'\n')
 print('PASS',len(cases),'native side-room admission cases;',sum(len(v['frames']) for v in seq.values()),'original clips')

# ---- explicit inputs -------------------------------------------------------------------------------------------------
FIXTURE_SHA256='9e320e791f039a73bf722926ce4910a53cf6186b2d580d1035f24e99615cb595'  # tests/fixtures/monastery_side_rooms.json (published)
RECIPE_SHA256='35746d58eaf42345a28da1f7f4767025530367232b940daaff875af83ec43fc8'  # scripts/lol2/monastery_side_rooms_source.json
ORIGINALS={'MCEL':('a6d0262394f0c4779894cca9e3232aac87cb0328633aefbf418732ce605643ce','e293f1e6c6f35d0502d2df00000c0eb784e82fa202ce641feb65f658b8b99332'),
           'MGAR':('4c3fd55ab5d17e78fea0572cf92600b2261aa988f86113cdc1d2085850fe7155','1c12d9d4301b75527a8f95ad1d8704b1caef86b1a1c6560eb2da8d44a1dd3ef7')}  # archive, DLL
# The legacy runs' queries, matched to fixture cases (Met_Dawn=1 for MCEL; the MGAR replay does not read it).
RUNS={'MCEL':[('MCEL',dict(flags={'170':0},globals={'GV_RIX_DEAD':0},locals={'Met_Dawn':1}))],
      'MGAR':[('MGAR',dict(flags={'181':0,'258':0,'140':0,'259':0,'260':0})),('MGAR_REPEAT',dict(flags={'181':0,'258':1,'140':0,'259':0,'260':0}))]}

def cli():
 global ROOT,convert
 p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
 for name in ['game','re-root','fixture','recipe','output-root']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 if a.output_root.exists():p.error('--output-root must be a fresh directory')
 for tool in ['ffmpeg','ffprobe']:
  if shutil.which(tool) is None:p.error(tool+' not found on PATH')
 codecs=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
 for codec in ['libtheora','libvorbis','vqavideo','pcm_s16le']:
  if codec not in codecs:p.error('ffmpeg lacks '+codec)
 try:converter=monastery_media.load_converter(a.re_root)
 except ValueError as error:p.error(str(error))
 for path,want,label in [(a.fixture,FIXTURE_SHA256,'side-room admission fixture'),(a.recipe,RECIPE_SHA256,'side-room recipe')]:
  if not path.is_file():p.error('Missing input: '+str(path))
  if digest(path.read_bytes())!=want:p.error(f'{path}: not the pinned {label} ({want})')
 fixture,recipe=json.loads(a.fixture.read_text()),json.loads(a.recipe.read_text())
 archives={}
 for name,(want,_) in ORIGINALS.items():
  path=a.game/'DAT'/f'{name}.MIX'
  if not path.is_file():p.error('Missing original '+str(path))
  archives[name]=path.read_bytes()
  if digest(archives[name])!=want:p.error(f'{path}: not the pinned original')
 from lol2_source_format import u32
 sources={};runs={}
 try:
  for name in ['MCEL','MGAR']:
   dll=extract(archives[name],f'WOMS\\{name}_.WOM')[0];assert digest(dll)==ORIGINALS[name][1],f'{name} DLL'
   image=dll[48:48+struct.unpack_from('<I',dll,36)[0]];callbacks=recipe['callbacks'][name];assert len(callbacks)==13,f'{name} callbacks'
   for j,target in enumerate(callbacks):
    w=u32(image,j*4);first=next(k for k in range(26) if image[w+k]==0xe8)
    assert w+first+5+struct.unpack_from('<i',image,w+first+1)[0]==target,f'{name} callback {j}'
   sources[name]={'dll_sha256':digest(dll),'archive_sha256':digest(archives[name]),'callbacks':callbacks}
   runs[name]=[]
   for sequence,query in RUNS[name]:
    hits=[c for c in fixture['cases'] if c['room']==name and all(c.get(k)==v for k,v in query.items())]
    assert len(hits)==1,f'{sequence} fixture case';effects=hits[0]['entry_effects'];runs[name].append((sequence,effects))
    for e in effects:
     if e[0]=='movie':movie(archives[name],f'WOMS\\{name}\\{e[1]:02d}{e[2]:03d}{e[3]:02d}E.VQA')
   speaker=24 if name=='MCEL' else 23
   movie(archives[name],f'WOMS\\{name}\\{name}_.VQA');movie(archives[name],f'WOMS\\{name}\\{speaker:02d}99907E.VQA')
 except (AssertionError,StopIteration,KeyError,ValueError,IndexError,struct.error) as error:
  p.error('Originals do not match the recorded inputs: '+(str(error) or type(error).__name__))
 convert=converter;ROOT=a.output_root.resolve()
 out=ROOT/'assets/lol2/generated/monastery_side_rooms';out.mkdir(parents=True);cache=ROOT/'tmp/monastery_side_source';cache.mkdir(parents=True)
 rooms={};seq={}
 for name in ['MCEL','MGAR']:
  room,s=stage_room(name,archives[name],runs[name],out,cache);rooms[name]=room;seq.update(s)
 (out/'rooms.json').write_text(json.dumps(dict(rooms=rooms,sequences=seq,sources=sources),indent=2)+'\n')
 print('PASS explicit side rooms:',{k:len(v['frames']) for k,v in seq.items()},'clips')

if __name__=='__main__':
 if EXPLICIT:cli()
 else:main()
