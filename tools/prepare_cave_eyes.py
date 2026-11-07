#!/usr/bin/env python3
"""Pin cave actor24's use/path/removal lifecycle and stage its original eyes."""
import argparse,hashlib,json,struct,sys
from pathlib import Path
from PIL import Image
from verify_actor_item_grants import ROOT, source_area
from prepare_museum_creature_sprites import stage,GAME
from lol2_material_format import sections
from lol2_creature_sprite_format import decode_rows
from build_game_atlas import section
from prepare_creature_audio_clips import stage_clips,sound_bank

def stage_media(game,texture,root):
 out=root/'assets/lol2/generated/cave_eyes';stage('DAT/L1_DC.MIX',texture,[8],out,game=game)
 manifest=json.loads((out/'sprites.json').read_text());sec=sections(texture);frames=[]
 for resource in list(range(166,176))+list(range(196,219)):
  d=struct.unpack_from('<6H11I',texture,sec[2]+resource*56);payload=texture[sec[3]+d[7]:sec[3]+d[7]+d[12]]
  w,h,pixels,_=decode_rows(payload,expected_flags=0x2c6);assert (w,h)==(123,78)
  name=f'frame_{resource}.png';Image.frombytes('L',(w,h),pixels).save(out/name)
  frames.append(dict(resource=resource,file=name,width=w,height=h,png_sha256=hashlib.sha256((out/name).read_bytes()).hexdigest()))
 manifest['definitions']['8']['states'][0]['views'][0]['frames']=list(range(166,176))
 manifest['definitions']['8']['states'][1]['views'][0]['frames']=list(range(196,219))
 manifest['frames']=frames;manifest['unsupported']=[];(out/'sprites.json').write_text(json.dumps(manifest,indent=2)+'\n')
 clips=stage_clips(root,'cave_eyes_audio',[232],game=game);(root/'assets/lol2/generated/cave_eyes_audio/audio.json').write_text(json.dumps(dict(clips=clips),indent=2)+'\n')
 return clips

def main():
 from lol2_cache_named_wall_fixture import load_named
 from lol2_extract_cave_materials import ASSET,HASH
 from verify_hive_executioner import EXE_HASH,CreatureReplay,capstone
 area,arc,entry,g,owners,streams=source_area('L1_DC')
 _,texture,_,_=load_named(GAME,ASSET);assert hashlib.sha256(texture).hexdigest()==HASH
 clips=stage_media(GAME,texture,ROOT)
 _,_,actors=section(g,0x1c,0x68,56);raw=actors[24*56:25*56]
 assert raw.hex()=='37f82d1600002c000207bd03461c00000000000000000000000000000000320008160000000e090900010032000000000000000000000000'
 exe=(GAME/'LOLG.DAT').read_bytes();assert hashlib.sha256(exe).hexdigest()==EXE_HASH
 md=capstone.Cs(3,4);md.detail=True;a,z=0xa239f,0xa2453;code=exe[a+0x37000:z+0x37000]
 machine=CreatureReplay({i.address:i for i in md.disasm(code,a)},b'');obj,stack=0x410000,0x430000
 machine.mem[obj:obj+188]=bytes(188);machine.mem[stack-0x44:stack-0x44+56]=raw;machine.regs.update(ebx=obj,ebp=stack);machine.execute(a,z)
 initial={k:machine.readmem(obj+v,1) for k,v in [('path',0xa4),('index',0xa5),('behavior',0xa8),('action',0xaa)]};assert initial==dict(path=1,index=0,behavior=14,action=9)
 _,_,paths=section(g,0xdc,0xd8,4);_,_,markers=section(g,0xc8,0xc4,8)
 first,count,flags=struct.unpack_from('<HBB',paths,4);assert (first,count,flags)==(9,7,0)
 points=[]
 for n in range(first,first+count):
  x,y,region,fl=struct.unpack_from('<hhHH',markers,n*8);points.append(dict(position=[x,44,-y],region=region,flags=fl))
 expected={9432:['14031905e800ffd53e00','100319050100','100218000100'],14132:['0d02180000070000','0d02180001000000'],14154:['0d02180001090000','060218000200','0e02180003000000'],14182:['090218000200'],14188:['090319051500','090218000e00']}
 packets={}
 for group,commands in expected.items():
  actual=streams[1][group];assert [r['raw_hex'] for r in actual]==commands
  packets[str(group)]=dict(commands=actual,handlers=[o for o in owners if o['stream']==1 and o['group']==group])
 _,_,events=section(g,0x40,0x88,1);offset=struct.unpack_from('<H',raw,12)[0];timer=None
 while events[offset] and events[offset+1]:
  record=events[offset:offset+events[offset]]
  if record[1]==2:timer=record
  offset+=len(record)
 assert timer.hex()=='0a026637300102007800'
 result=dict(version=1,source=area['source'],actor=24,position=[-1993,44,-5677],prop=1305,initial=initial,constructor=dict(executable_sha256=EXE_HASH,start=a,end=z,sha256=hashlib.sha256(code).hexdigest()),clips=dict(idle_frames=10,moving_frames=23,interval=1024),path=dict(index=1,flags=flags,points=points),groups=packets,timer=dict(raw=timer.hex(),flags=timer[5],remaining=struct.unpack_from('<H',timer,8)[0],rate=60),sound=dict(request=232,samples=clips['232']['samples'],rate=22050),limits=['Native constructor slice executed; source events and ordered commands pinned.','Path speed/height grounding and scheduling of state1 event3 are modern presentation adapters; no combat or loot.','Timer enabled at path end via opcode14; source120ticks at60/s.','Use admits actor kind4; kind5/hit alternative producers are not assumed.'])
 (ROOT/'scripts/lol2/cave_eyes_source.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS actor24 path1 seven points, five source groups, timer120ticks, 33 original eye frames and sound232')
def cli():
 parser=argparse.ArgumentParser(description='Prepare cave-eye animation and sound from explicit original inputs; retain tracked lifecycle configuration.')
 parser.add_argument('--game',type=Path,required=True)
 parser.add_argument('--texture',type=Path,required=True)
 parser.add_argument('--output-root',type=Path,required=True)
 args=parser.parse_args()
 if args.output_root.exists():parser.error('Use a fresh output root')
 source_area('L1_DC',game=args.game)  # Pinned original archive and geometry.
 texture=args.texture.read_bytes()
 if hashlib.sha256(texture).hexdigest()!='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97':
  parser.error('Original Cave texture does not match')
 sound_bank(args.game)  # Validate the audio bank before creating output.
 stage_media(args.game,texture,args.output_root)
 print('PASS original cave-eye frames and sound; tracked lifecycle source unchanged')
if __name__=='__main__':
 if len(sys.argv)>1:cli()
 else:main()
