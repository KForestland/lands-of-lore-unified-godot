#!/usr/bin/env python3
"""Bind opcode21's first-use movie and stage source departure/arrival data.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_act_one_departure.py --game GAME --re-root RE --recipe scripts/lol2/act_one_departure_source.json \
      --output-root FRESH
The explicit path stages the complete assets/lol2/generated/act_one_departure pack: departure.ogv/departure.json here and
page_*.png/voice.wav/playback.json through prepare_departure_playback.stage_playback. The compact recipe carries only the
recorded native fields (two LE fixup records, three emulated opcode21 argument cases), checked at byte level against the
pinned executable; the movie binding (published map_video_inventory.lookup_movie) and the departure regions, level-8
arrival and destination source (published map_geometry.export_geometry of the original L4_HJ/L8_SJ archives, in a
temporary directory) are re-derived. Published helpers only; the RE checkout supplies only the pinned video converter.
No docs are written. Without arguments the historical native path is unchanged.
"""
import hashlib,json,struct,sys,subprocess
from pathlib import Path
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
 import argparse,shutil,tempfile
 import monastery_media
 from monastery_media import digest
 from lol2_source_format import u32
 from lol2.map_video_inventory import lookup_movie
 ROOT=GAME=convert=None  # set by cli()
else:
 from audit_monastery_rooms import ROOT,GAME,digest,capstone
 from build_game_atlas import u32
 from lol2.map_video_inventory import lookup_movie
 sys.path.insert(0,'~/lol2_re_publish_20260911/tools/draracle')
 from verify_special_pixel_table_binding import fixups
 from verify_creature_states import CreatureReplay
 sys.path.insert(0,'~/lol2_re_publish_20260911/tools')
 from convert_cave_video_review import convert

def stage_movie(out,source):
 """Bind E125E in the original L4_HJ movie MIX, convert it, and check the staged frame count and durations."""
 movie=lookup_movie(GAME,'L4_HJ','E125E.VQA');assert movie['status']=='exact' and movie['sha256']=='e8cd77b8d4f7412808e35f3659d31b76a22fdd8c8f066d5862f65cc4775bcef7'
 payload=movie.pop('payload',None)
 if payload is None:
  key=next(k for k,v in movie.items() if isinstance(v,bytes));payload=movie.pop(key)
 source.write_bytes(payload)
 convert(source,out/'departure.ogv')
 count=subprocess.run(['ffprobe','-v','error','-select_streams','v:0','-count_frames','-show_entries','stream=nb_read_frames','-of','csv=p=0',str(out/'departure.ogv')],capture_output=True,text=True,check=True).stdout.strip();assert int(count)==318
 streams=json.loads(subprocess.run(['ffprobe','-v','error','-show_entries','stream=codec_type,duration','-of','json',str(out/'departure.ogv')],capture_output=True,text=True,check=True).stdout)['streams']
 durations={v['codec_type']:float(v['duration']) for v in streams}
 assert set(durations)=={'video','audio'} and abs(durations['video']-318/15)<.001
 movie['staged_durations']=durations;movie['duration']=max(durations.values())
 return movie

def place(jungle,geometry,entries):
 """Departure regions 3186..3189 of the Jungle geometry and the level-8 entry-1 arrival."""
 regions=[]
 for i in range(3186,3190):
  r=jungle['regions'][i];regions.append(dict(region=i,polygon=[[jungle['vertices_fixed'][v][0]/65536,-jungle['vertices_fixed'][v][1]/65536] for v in r['vertex_indices']],floor=r['floor_corners'],ceiling=r['ceiling_corners']))
 arrival=next(a for a in entries if a['selector']==1)
 assert (arrival['x'],arrival['y'],arrival['heading_units'],arrival['region'])==(-4577,-1168,16384,2359)
 r=geometry['regions'][2359];assert r['floor_corners']==[0]*4 and r['ceiling_corners']==[100]*4
 arrival.update(godot_position=[-4577,32,1168],godot_yaw=-1.5707963267948966,floor=0,ceiling=100)
 return regions,arrival

def result_of(exe,rel,code,checks,name_rel,movie,regions,arrival,geometry):
 return dict(executable_sha256=digest(exe),command='150346001a00',opcode21_relocation=rel,handler_sha256=digest(code),native_argument_cases=checks,name_table_relocation=name_rel,movie=movie,movie_path='res://assets/lol2/generated/act_one_departure/departure.ogv',regions=regions,arrival=arrival,destination_source=geometry['source'],scope='Opcode21 dispatch slice with explicit eax==esi context produces movie index26/option0, not a control70 operation. Relocated name table gives e125e; unique sphere1/area hash/header binds original318-frame movie and staged conversion frame count. Source level8 entry1 position/flat floor/ceiling are pinned; full native movie pipeline, placement and live route not yet integrated.')

def main():
 exe=(GAME/'LOLG.DAT').read_bytes();assert digest(exe)=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
 le=0x39024+u32(exe,0x39060);ot=le+u32(exe,le+0x40)
 slot=0x5c878+20*4;first=u32(exe,ot+36);rel=fixups(exe,le,first-1+slot//4096)[slot%4096]
 assert rel['target_object']==2 and rel['target_offset']+0x59024==0xb5ab5
 md=capstone.Cs(3,4);md.detail=True;code=exe[0xb5ab5+0x37000:0xb5acb+0x37000];ins={i.address:i for i in md.disasm(code,0xb5ab5)}
 checks=[]
 for record in [0x400000,0x510000,0x620000]:
  m=CreatureReplay(ins,b'');m.mem[record:record+6]=bytes.fromhex('150346001a00');m.regs.update(esi=record,eax=record,esp=0x700000)
  m.execute(0xb5ab5,0xb5ac1);args=[m.readmem(m.regs['esp']+i*4,4) for i in range(2)]
  assert args==[26,0] and ins[0xb5ac1].operands[0].imm==0xcf2b4
  checks.append(dict(record=record,args=args))
 first=u32(exe,ot+108);slot=0xe568+26*4;name_rel=fixups(exe,le,first-1+slot//4096)[slot%4096]
 assert name_rel['target_object']==5
 name=exe[0x1c1024+name_rel['target_offset']:].split(b'\0')[0].decode();assert name=='e125e'
 out=ROOT/'assets/lol2/generated/act_one_departure';out.mkdir(parents=True,exist_ok=True)
 movie=stage_movie(out,ROOT/'tmp/E125E.VQA')
 jungle=json.loads(Path('~/lol2_out/jungle_geometry_20260914/geometry.json').read_text())
 base=Path('~/lol2_out/all_maps_20260922/L8_SJ/geometry')
 geometry=json.loads((base/'geometry.json').read_text());entries=json.loads((base/'arrivals.json').read_text())['entries']
 regions,arrival=place(jungle,geometry,entries)
 result=result_of(exe,rel,code,checks,name_rel,movie,regions,arrival,geometry)
 (out/'departure.json').write_text(json.dumps(result,indent=2)+'\n');(ROOT/'docs/act-one-departure-media-checks.json').write_text(json.dumps(result,indent=2)+'\n')
 print('PASS: opcode21 movie26 = E125E;318 frames staged; four departure regions and level8 entry1 pinned')

# ---- explicit inputs -------------------------------------------------------------------------------------------------
RECIPE_SHA256='5fcae467c10c0b0bd327c782643aa15d97b73f62728a08daa8a931328a0e6b4a'  # scripts/lol2/act_one_departure_source.json
ORIGINALS={'LOLG.DAT':'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775',
           'DAT/L4_HJ.MIX':'517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f',
           'DAT/L4_HJI.MIX':'bdb62b262d77ae3bba6bf57f6344947ea6440a45c3cedc9a729acf6581035b09',
           'DAT/L8_SJ.MIX':'3eff07430a453d2c6f09133f869874e0530af1b6a3bfff7f4297761b96a28bc2'}
CODE_BASE=0x37000  # file offset of handler address 0 (as main: exe[0xb5ab5+0x37000:...])

def check_recipe(exe,recipe):
 """Byte-level checks of the recorded native fields against the pinned executable; returns the handler bytes."""
 def record(rel):
  at=rel['record_file_offset'];assert exe[at:at+len(rel['record_hex'])//2].hex()==rel['record_hex'],'fixup record bytes'
 rel,name_rel,h=recipe['opcode21_relocation'],recipe['name_table_relocation'],recipe['handler']
 record(rel);assert rel['target_object']==2 and rel['target_offset']+0x59024==h['start']==0xb5ab5,'opcode21 target'
 code=exe[h['start']+CODE_BASE:h['end']+CODE_BASE];assert digest(code)==h['sha256'],'handler bytes'
 at=h['call']+CODE_BASE;assert exe[at]==0xe8 and h['call']+5+struct.unpack_from('<i',exe,at+1)[0]==h['call_target']==0xcf2b4,'handler call'
 assert recipe['command']=='150346001a00' and [c['args'] for c in recipe['native_argument_cases']]==[[26,0]]*3,'argument cases'
 record(name_rel);assert name_rel['target_object']==5 and exe[0x1c1024+name_rel['target_offset']:].split(b'\0')[0].decode()==recipe['name']=='e125e','name table'
 return code

def cli():
 global ROOT,GAME,convert
 import prepare_departure_playback as playback
 from lol2_movie_format import parse_vqa_chunks
 from lol2 import map_geometry
 p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
 for name in ['game','re-root','recipe','output-root']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 if a.output_root.exists():p.error('--output-root must be a fresh directory')
 for tool in ['ffmpeg','ffprobe']:
  if shutil.which(tool) is None:p.error(tool+' not found on PATH')
 codecs=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
 for codec in ['libtheora','libvorbis','vqavideo','pcm_s16le',' png ']:
  if codec not in codecs:p.error('ffmpeg lacks '+codec.strip())
 try:converter=monastery_media.load_converter(a.re_root)
 except ValueError as error:p.error(str(error))
 if not a.recipe.is_file():p.error('Missing input: '+str(a.recipe))
 if digest(a.recipe.read_bytes())!=RECIPE_SHA256:p.error(f'{a.recipe}: not the pinned departure recipe ({RECIPE_SHA256})')
 recipe=json.loads(a.recipe.read_text())
 for rel,want in ORIGINALS.items():
  if not (a.game/rel).is_file():p.error('Missing original '+str(a.game/rel))
  if digest((a.game/rel).read_bytes())!=want:p.error(f'{a.game/rel}: not the pinned original')
 GAME=a.game.resolve();exe=(GAME/'LOLG.DAT').read_bytes()
 try:
  code=check_recipe(exe,recipe)
  probe=lookup_movie(GAME,'L4_HJ','E125E.VQA');assert probe['status']=='exact' and probe['sha256']=='e8cd77b8d4f7412808e35f3659d31b76a22fdd8c8f066d5862f65cc4775bcef7','movie binding'
  with tempfile.TemporaryDirectory(prefix='departure-geometry-') as tmp:
   for area in ['L4_HJ','L8_SJ']:map_geometry.export_geometry(GAME,area,Path(tmp)/area)
   jungle=json.loads((Path(tmp)/'L4_HJ/geometry.json').read_text());geometry=json.loads((Path(tmp)/'L8_SJ/geometry.json').read_text())
   entries=json.loads((Path(tmp)/'L8_SJ/arrivals.json').read_text())['entries']
  regions,arrival=place(jungle,geometry,entries)
 except (AssertionError,StopIteration,KeyError,ValueError,IndexError,struct.error) as error:
  p.error('Originals do not match the recorded inputs: '+(str(error) or type(error).__name__))
 convert=converter;ROOT=a.output_root.resolve()
 out=ROOT/'assets/lol2/generated/act_one_departure';out.mkdir(parents=True);cache=ROOT/'tmp/departure_frames';cache.mkdir(parents=True)
 source=ROOT/'tmp/E125E.VQA'
 movie=stage_movie(out,source)
 result=result_of(exe,recipe['opcode21_relocation'],code,recipe['native_argument_cases'],recipe['name_table_relocation'],movie,regions,arrival,geometry)
 (out/'departure.json').write_text(json.dumps(result,indent=2)+'\n')
 playback.stage_playback(source,out,cache,parse_vqa_chunks)
 print('PASS explicit departure: movie 318 frames,',len(regions),'regions, arrival region',arrival['region'])

if __name__=='__main__':
 if EXPLICIT:cli()
 else:main()
