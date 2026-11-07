#!/usr/bin/env python3
"""Stage source rune-room Ancient Stone item and seekable original pickup film."""
import json,struct,subprocess,sys,wave
from pathlib import Path
from PIL import Image
from prepare_hive_wax import entry,sections,rgb_palette,decode_rows,ROOT,digest,u32
from monastery_media import extract,movie
from lol2_movie_format import parse_vqa_chunks
GAME = None

def main():
 definitions=entry('GLOBAL.MIX',3984507021)
 assert digest(definitions)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
 base,n=u32(definitions,4),u32(definitions,0x34);so=base+n*91+4;fo=so+u32(definitions,so-4)*16+4;names=fo+u32(definitions,fo-4)*12
 assert n==170 and u32(definitions,so-4)==u32(definitions,fo-4)==170
 assert definitions[names+68*30:names+68*30+24].split(b'\0')[0]==b'66-Ancients stn'
 d=definitions[base+68*91:][:91];resource=struct.unpack_from('<h',definitions,fo+68*12)[0]
 assert u32(d,24)==3764690106 and d[46]+d[47]==1 and d[50]==4 and resource==308
 graphics=entry('LOCAL.MIX',4018716831);assert digest(graphics)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
 sec=sections(graphics);desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
 w,h,pixels,_=decode_rows(graphics[sec[3]+desc[7]:][:desc[12]],allow_special=True);assert (w,h)==desc[1:3]
 palette=rgb_palette(graphics[u32(graphics,4):][:768],6);rgba=bytes(c for i in pixels for c in (*palette[i*3:i*3+3],0 if i in (0,1) else 255))
 out=ROOT/'assets/lol2/generated/hive_ancient_stone';out.mkdir(parents=True,exist_ok=True)
 Image.frombytes('RGBA',(w,h),rgba).save(out/'stone.png')
 archive=(GAME/'DAT/RUNES.MIX').read_bytes();assert digest(archive)=='095a7e016786edb83ca9b83ad15f174d3ff7a1848f444281fd471b52f435c4dd'
 payload,binding=extract(archive,'WOMS\\RUNES\\RUNES3_.VQA');record=movie(archive,'WOMS\\RUNES\\RUNES3_.VQA');assert digest(payload)=='8633ff784e9457a0dcf3a3658fdcd328704cc729a5cd6e7ce5361bb0f28a07d2'
 cache=ROOT/'tmp/ancient_stone_frames';cache.mkdir(parents=True,exist_ok=True);source=cache/'RUNES3_.VQA';source.write_bytes(payload)
 # Partial-codebook VQA v2 uses the Python decoder (FFmpeg mis-decodes some codebook groups; see tools/vqa_v2_decode.py).
 from vqa_v2_decode import frames_to_dir
 if not frames_to_dir(source,cache): subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vsync','0',str(cache/'%04d.png')],check=True)
 frames=sorted(cache.glob('*.png'));assert len(frames)==record['frames']==55
 atlases=[]
 for first in range(0,55,16):
  sheet=Image.new('RGB',(2560,1600))
  for i,path in enumerate(frames[first:first+16]):
   picture=Image.open(path);assert picture.size==(640,400);sheet.paste(picture,((i%4)*640,(i//4)*400))
  path=out/f'page_{first//16}.png';sheet.save(path);atlases.append('res://'+str(path.relative_to(ROOT)))
 chunks=parse_vqa_chunks(payload);assert sum(tag==b'VQFR' for tag,data in chunks)==55;expected=sum(len(data)*2 for tag,data in chunks if tag==b'SND2');audio='';rate=22050
 if expected:
  path=out/'voice.wav';subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vn','-ac','1','-c:a','pcm_s16le',str(path)],check=True)
  with wave.open(str(path)) as f: assert f.getnframes()==expected and f.getnchannels()==1;rate=f.getframerate()
  audio='res://'+str(path.relative_to(ROOT))
 media=dict(frames=55,fps=15,width=640,height=400,x=0,y=0,atlases=atlases,audio=audio,audio_samples=expected,audio_rate=rate,duration=max(55/15,expected/rate))
 report=dict(item='hive:runes:Ancients_Stone',name='66-Ancients stn',definition=68,identity=3764690106,resource=308,size=[w,h],definitions_sha256=digest(definitions),graphics_sha256=digest(graphics),pixels_sha256=digest(pixels),omitted_remap_pixels=pixels.count(1),archive_sha256=digest(archive),movie=record,media=media,scope='Pinned RUNES hotspot4 orders overlay removal, original RUNES3_ film, item grant, flag7, numeric speech100/2/24. Parallel global item-name/definition/state/view tables bind definition68/resource308. Full film frames/audio staged; numeric follow-up speech and item-use effects remain open.')
 (out/'stone.json').write_text(json.dumps(report,indent=2)+'\n');(ROOT/'docs/hive-ancient-stone-source.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS Ancient Stone definition68/resource308:',w,h,'film55frames',expected,'audio samples')
def cli():
 import argparse
 import prepare_hive_wax as wax
 global ROOT,GAME
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--game',type=Path,required=True)
 parser.add_argument('--output-root',type=Path,required=True)
 a=parser.parse_args();GAME=a.game.resolve();ROOT=a.output_root.resolve()
 if ROOT.exists():parser.error('Output must be a fresh directory')
 if ROOT==GAME or ROOT in GAME.parents or GAME in ROOT.parents:parser.error('Output overlaps original game')
 try:
  for name,wanted in [('DAT/RUNES.MIX','095a7e016786edb83ca9b83ad15f174d3ff7a1848f444281fd471b52f435c4dd'),
                      ('GLOBAL.MIX','1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
                      ('LOCAL.MIX','d0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
   if digest((GAME/name).read_bytes())!=wanted:raise ValueError('Unsupported original '+name)
  wax.GAME=GAME
  (ROOT/'docs').mkdir(parents=True)
  main()
 except (OSError,ValueError,AssertionError) as error:parser.error(str(error) or type(error).__name__)

if __name__=='__main__':cli()
