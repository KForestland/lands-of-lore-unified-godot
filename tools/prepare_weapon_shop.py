#!/usr/bin/env python3
"""Stage native-checked first-visit weapon shop interactions and source media.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_weapon_shop.py --game GAME --re-root RE --data scripts/lol2/weapon_shop_data.gd \
      --entrances scripts/lol2/weapon_shop_entrance_source.json --output-root FRESH
The explicit path stages the complete assets/lol2/generated/weapon_shop pack (rooms.json, backgrounds, idle, the
plan media and the prepare_weapon_shop_items icons/items.json). Plans come from the published runtime contract
weapon_shop_data.gd (recorded paired native callbacks), not a replay. Entrance polygons and the return pose are
re-derived from the original L4_HJ geometry for the recorded room-name selection in the compact entrance recipe.
Published helpers only (tools/monastery_media.py and the published source readers); the RE checkout supplies only the
pinned video converter. It never writes weapon_shop_data.gd or docs. Without arguments the historical native path
(paired replays, docs/act-one-shops-source.json, .gd and docs writes) is unchanged.
"""
import json,struct,subprocess,sys,wave
from PIL import Image
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
 import argparse,re,shutil
 from pathlib import Path
 import monastery_media
 from monastery_media import extract,movie,digest
 ROOT=GAME=convert=None  # set by cli()

 def stage_patch(source,target,record):
  return monastery_media.stage_patch(source,target,record,ROOT)
else:
 from audit_weapon_shop import RoomReplay
 from audit_monastery_rooms import ROOT,GAME,extract,movie,digest
 from prepare_monastery_rooms import stage_patch,convert

def stage_media(plans,archive,out,cache):
 rooms={};media={}
 for name in ['WPN','WPNEXT']:
  arc=(GAME/'DAT'/f'{name}.MIX').read_bytes();key=f'WOMS\\{name}\\{name}_.VQA';record=movie(arc,key)
  path=cache/f'{name}_.VQA';path.write_bytes(extract(arc,key)[0]);target=out/f'{name}_.ogv'
  if name=='WPN':convert(path,target)
  else:
   clip=stage_patch(path,target,record)
   proc=subprocess.Popen(['ffmpeg','-v','error','-y','-f','rawvideo','-pix_fmt','rgb24','-s',f"{record['width']}x{record['height']}",'-r','15','-i','-','-c:v','libtheora','-q:v','8',str(target)],stdin=subprocess.PIPE)
   for frame in range(record['frames']):
    sheet=Image.open(ROOT/clip['atlases'][frame//16].removeprefix('res://'));w,h=record['width'],record['height'];x,y=(frame%4)*w,((frame%16)//4)*h
    proc.stdin.write(sheet.crop((x,y,x+w,y+h)).convert('RGB').tobytes())
   proc.stdin.close();assert proc.wait()==0
  rooms[name]=dict(background=dict(record,path='res://'+str(target.relative_to(ROOT))),movies=[])
 movies=sorted({tuple(e[1:4]) for plan in plans.values() for e in plan if e[0]=='movie'})
 for speaker,line,chapter in movies:
  name=f'{speaker:02d}{line:03d}{chapter:02d}E';key=f'WOMS\\WPN\\{name}.VQA'
  if speaker in [1,2]:
   audkey=key.replace('.VQA','.AUD');payload,binding=extract(archive,audkey);path=cache/f'{name}.aud';path.write_bytes(payload);target=out/f'{name}.wav'
   subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-ac','1','-c:a','pcm_s16le',str(target)],check=True)
   with wave.open(str(target)) as wav: samples=wav.getnframes();rate=wav.getframerate()
   assert samples*2==struct.unpack_from('<I',payload,6)[0]
   media[f'{speaker}:{line}:{chapter}']=dict(binding,frames=0,audio='res://'+str(target.relative_to(ROOT)),audio_samples=samples,duration=samples/rate)
   continue
  record=movie(archive,key);path=cache/f'{name}.VQA';path.write_bytes(extract(archive,key)[0]);target=out/f'{name}.ogv'
  media[f'{speaker}:{line}:{chapter}']=stage_patch(path,target,record)
 # File-backed default idle animation is installed by the original WPN setup.
 key='WOMS\\WPN\\2599904E.VQA';record=movie(archive,key);path=cache/'2599904E.VQA';path.write_bytes(extract(archive,key)[0]);rooms['WPN']['idle']=stage_patch(path,out/'2599904E.ogv',record)
 return rooms,media

def main():
 out=ROOT/'assets/lol2/generated/weapon_shop';out.mkdir(parents=True,exist_ok=True)
 cache=ROOT/'tmp/weapon_shop_source';cache.mkdir(parents=True,exist_ok=True)
 r=RoomReplay('WPN');loose=RoomReplay('WPN',True)
 plans={};witnesses=[]
 configs=[('intro',9,0,{}),('orb',3,2,{}),('orb_known',3,2,{'254':1}),('orb_preknown',3,2,{}),('longarm',3,0,{}),('gargoyle',3,1,{}),('gargoyle_after_sword',3,1,{'62':1}),('shortsword',4,0,{}),('refuse',5,0,{}),('offer_orb',5,0,{}),('offer_orb_repeat',5,0,{'63':1}),('offer_dagger',5,0,{})]
 for name,event,arg,flags in configs:
  globals_={'GV_KNOWLEDGE_OF_POWER_ORB':1} if name=='orb_preknown' else {}
  held={'offer_orb':'83-Power orb','offer_orb_repeat':'83-Power orb','offer_dagger':'10-Th Dagger'}.get(name,'')
  a=r.run(event,flags=flags,arg=arg,globals_=globals_,held=held);b=loose.run(event,flags=flags,arg=arg,globals_=globals_,held=held);assert a==b,(name,a,b)
  plans[name]=[e for e in a['effects'] if e[0] in ['movie','set_flag','clear_flag','set_global','set_local','give_item','consume_held']]
  witnesses.append(dict(name=name,event=event,arg=arg,flags=flags,globals=globals_,held=held,effects=a['effects'],editions_match=True))
 rooms,media=stage_media(plans,r.archive,out,cache)
 source=json.loads((ROOT/'docs/act-one-shops-source.json').read_text())
 entrances=[e for e in source['entrances'] if e['room']=='wpnext_']
 raw=bytes.fromhex(entrances[0]['commands'][1]);x,y=struct.unpack_from('<hh',raw,4);bearing=struct.unpack_from('<H',raw,12)[0]
 result=dict(rooms=rooms,media=media,plans=plans,entrances=[o['polygon'] for e in entrances for o in e['owners']],return_pose=dict(x=x,z=-y,bearing=bearing),source=dict(archive_sha256=digest(r.archive),dll_sha256=digest(r.dll),loose_sha256=digest(loose.dll)))
 data_code='extends RefCounted\n## Generated from paired original WPN callbacks; regenerate with prepare_weapon_shop.py.\nconst PLANS := '+json.dumps(plans)+'\nconst DURATIONS := '+json.dumps({k:v['duration'] for k,v in media.items()})+'\n'
 (ROOT/'scripts/lol2/weapon_shop_data.gd').write_text(data_code)
 (out/'rooms.json').write_text(json.dumps(result,indent=2)+'\n')
 (ROOT/'docs/weapon-shop-source-checks.json').write_text(json.dumps(dict(passed=True,witnesses=witnesses,source=result['source'],limits='First-visit normal living-NPC branches only. Native host services mocked. Archive/loose equivalence limited to these callbacks. Admission, later departures, combat and original timer/presentation remain separate.'),indent=2)+'\n')
 print('PASS',len(witnesses),'paired native callbacks;',len(media),'original speech clips')

# ---- explicit inputs -------------------------------------------------------------------------------------------------
DATA_SHA256='cd540144a976617d0c3da864c54048fb0d4d3c88046f9a5e4da1878d560c0ee1'  # scripts/lol2/weapon_shop_data.gd (published)
ENTRANCES_SHA256='c7733cbe3bbe1bf7bbeb3b51778e7e581ff7f8426dae60b52dc7c5758753495b'  # scripts/lol2/weapon_shop_entrance_source.json
ORIGINALS={'DAT/WPN.MIX':'88fea12df000d0139802907408e0d91895b9589ec0165a61ec82f7d60ada12f9',
           'DAT/WPNEXT.MIX':'77d152aaa7d5de0a5e66fc99d19a4be559d7b628bba0970b36d8da26bf7c24aa',
           'WOMS/WPN_.WOM':'946a6e1dda9ab51b70a11e42540f30089641d38fcb2776290d21e1fca41afe7f',  # loose override DLL
           'LOLG.DAT':'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775',
           'DAT/L4_HJ.MIX':'517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'}
WPN_DLL_SHA256='3492035c2e1dbe94d39989ad65d2039fbf589d319db2136c84afd4569a96738e'  # WOMS\WPN_.WOM inside WPN.MIX
ITEM_ENTRIES=[('GLOBAL.MIX',3984507021),('LOCAL.MIX',4018716831)]  # pinned by prepare_weapon_shop_items.stage_items

def entry(blob,key):
 from lol2_source_format import parse_mix
 row=next(e for e in parse_mix(blob) if e['key']==key)
 return blob[row['offset']:][:row['size']]

def derive_entrances(blobs,recipe):
 """Recorded room-name row checked against LOLG.DAT bytes; commands, owners, polygons and return pose re-derived from
 the original L4_HJ geometry with published readers."""
 from lol2_source_format import parse_mix,u32
 from build_game_atlas import section
 from audit_game_actor_scripts import groups
 from audit_game_transition_owners import collect_owners
 exe,room=blobs['LOLG.DAT'],recipe['room_name']
 rel=room['relocation'];at=rel['record_file_offset']
 assert exe[at:at+len(rel['record_hex'])//2].hex()==rel['record_hex'],'room-name fixup record'
 assert room['file_offset']==0x1c1024+rel['target_offset'] and exe[room['file_offset']:].split(b'\0')[0].decode()==room['name']=='wpnext_','room name'
 area=recipe['area'];assert area['id']=='L4_HJ' and area['source']['sha256']==ORIGINALS['DAT/L4_HJ.MIX']
 arc=blobs['DAT/L4_HJ.MIX'];row=next(e for e in parse_mix(arc) if e['key']==area['source']['geometry_key'])
 raw=arc[row['offset']:][:row['size']];assert digest(raw)==area['source']['geometry_sha256'],'geometry entry'
 found=[]
 for stream,(of,cf) in enumerate([(0x3c,0x84),(0x44,0x8c)]):
  for group,cmds in groups(section(raw,of,cf,1)[2]):
   for _,b in cmds:
    if b[0]==12 and b[1]==3 and int.from_bytes(b[4:6],'little')==room['index']:
     found.append(dict(stream=stream,group=group,command=b.hex(),commands=[d.hex() for _,d in cmds]))
 assert found==recipe['entrances'],'room-select commands differ from the recorded selection'
 owners,_=collect_owners(raw,row['offset'],u32(raw,0x58))
 vertices=list(struct.iter_unpack('<ii',raw[u32(raw,4):][:u32(raw,0x50)*8]));ro=u32(raw,12)
 polygons=[]
 for e in found:
  mine=[o for o in owners if o['stream']==e['stream'] and o['group']==e['group']]
  assert mine and all(o['owner_kind']=='region' for o in mine),'entrance owners'
  for o in mine:
   indices=struct.unpack_from('<22H',raw,ro+o['owner']*44)[6:10]
   polygons.append([[vertices[v][0]/65536,-vertices[v][1]/65536] for v in indices])
 pick=recipe['return_pose'];cmd=bytes.fromhex(found[pick['entrance']]['commands'][pick['command']]);assert cmd[0]==0x12,'return command'
 x,y=struct.unpack_from('<hh',cmd,4);bearing=struct.unpack_from('<H',cmd,12)[0]
 return polygons,dict(x=x,z=-y,bearing=bearing)

def cli():
 global ROOT,GAME,convert
 import prepare_weapon_shop_items as items_tool
 from lol2_creature_sprite_format import sections,rgb_palette,decode_rows
 from lol2_source_format import u32
 p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
 for name in ['game','re-root','data','entrances','output-root']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 if a.output_root.exists():p.error('--output-root must be a fresh directory')
 for tool in ['ffmpeg','ffprobe']:
  if shutil.which(tool) is None:p.error(tool+' not found on PATH')
 codecs=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
 for codec in ['libtheora','libvorbis','vqavideo','pcm_s16le','rawvideo','adpcm_ima_ws',' png ']:
  if codec not in codecs:p.error('ffmpeg lacks '+codec.strip())
 try:converter=monastery_media.load_converter(a.re_root)
 except ValueError as error:p.error(str(error))
 for path,want,label in [(a.data,DATA_SHA256,'weapon shop runtime contract'),(a.entrances,ENTRANCES_SHA256,'weapon shop entrance recipe')]:
  if not path.is_file():p.error('Missing input: '+str(path))
  if digest(path.read_bytes())!=want:p.error(f'{path}: not the pinned {label} ({want})')
 gd=a.data.read_text();found={k:re.search(rf'^const {k} := (.*)$',gd,re.M) for k in ['PLANS','DURATIONS']}
 if not all(found.values()):p.error('Runtime contract lacks PLANS/DURATIONS')
 plans,durations=(json.loads(found[k].group(1)) for k in ['PLANS','DURATIONS'])
 recipe=json.loads(a.entrances.read_text())
 blobs={}
 for rel,want in ORIGINALS.items():
  if not (a.game/rel).is_file():p.error('Missing original '+str(a.game/rel))
  blobs[rel]=(a.game/rel).read_bytes()
  if digest(blobs[rel])!=want:p.error(f'{a.game/rel}: not the pinned original')
 for rel,_ in ITEM_ENTRIES:
  if not (a.game/rel).is_file():p.error('Missing original '+str(a.game/rel))
 try:
  archive=blobs['DAT/WPN.MIX'];dll=extract(archive,'WOMS\\WPN_.WOM')[0];assert digest(dll)==WPN_DLL_SHA256,'WPN DLL'
  movies=sorted({tuple(e[1:4]) for plan in plans.values() for e in plan if e[0]=='movie'})
  assert sorted(durations)==sorted(f'{s}:{l}:{c}' for s,l,c in movies),'DURATIONS keys differ from PLANS movies'
  for s,l,c in movies:
   key=f'WOMS\\WPN\\{s:02d}{l:03d}{c:02d}E.'+('AUD' if s in [1,2] else 'VQA')
   extract(archive,key) if s in [1,2] else movie(archive,key)
  movie(archive,'WOMS\\WPN\\2599904E.VQA');movie(blobs['DAT/WPNEXT.MIX'],'WOMS\\WPNEXT\\WPNEXT_.VQA');movie(archive,'WOMS\\WPN\\WPN_.VQA')
  item_blobs=[entry((a.game/rel).read_bytes(),key) for rel,key in ITEM_ENTRIES]
  assert [digest(b) for b in item_blobs]==['b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891','36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'],'item entries'
  polygons,pose=derive_entrances(blobs,recipe)
 except (AssertionError,StopIteration,KeyError,ValueError) as error:
  p.error('Originals do not match the recorded inputs: '+str(error))
 convert=converter;GAME=a.game.resolve();ROOT=a.output_root.resolve()
 out=ROOT/'assets/lol2/generated/weapon_shop';out.mkdir(parents=True);cache=ROOT/'tmp/weapon_shop_source';cache.mkdir(parents=True)
 rooms,media=stage_media(plans,archive,out,cache)
 assert {k:v['duration'] for k,v in media.items()}==durations,'Staged durations differ from the runtime contract'
 result=dict(rooms=rooms,media=media,plans=plans,entrances=polygons,return_pose=pose,source=dict(archive_sha256=digest(archive),dll_sha256=digest(dll),loose_sha256=digest(blobs['WOMS/WPN_.WOM'])))
 (out/'rooms.json').write_text(json.dumps(result,indent=2)+'\n')
 items_tool.stage_items(*item_blobs,out,ROOT,sections,rgb_palette,decode_rows,digest,u32)
 print('PASS explicit weapon shop:',len(media),'plan clips,',len(polygons),'entrance polygons, return pose',pose)

if __name__=='__main__':
 if EXPLICIT:cli()
 else:main()
