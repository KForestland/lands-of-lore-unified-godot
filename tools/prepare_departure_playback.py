#!/usr/bin/env python3
"""Seekable original exit frames/audio for persistent cinematic playback.

stage_playback() takes the source movie, output/cache directories and the VQA chunk parser, so
prepare_act_one_departure.py --game ... can stage this media with published helpers. Run as a script, main() keeps the
historical repository paths (tmp/E125E.VQA written by prepare_act_one_departure.py) and companion-RE parser.
"""
import json,subprocess,wave,sys
from pathlib import Path
from PIL import Image

def stage_playback(source,out,cache,parse_vqa_chunks):
 # Partial-codebook VQA v2 uses the Python decoder (FFmpeg mis-decodes some codebook groups; see tools/vqa_v2_decode.py).
 from vqa_v2_decode import frames_to_dir
 if not frames_to_dir(source,cache): subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vsync','0',str(cache/'%04d.png')],check=True)
 frames=sorted(cache.glob('*.png'));assert len(frames)==318
 atlases=[]
 for first in range(0,len(frames),16):
  sheet=Image.new('RGB',(2560,1600))
  for i,p in enumerate(frames[first:first+16]):
   im=Image.open(p);assert im.size==(640,400);sheet.paste(im,((i%4)*640,(i//4)*400))
  name=f'page_{first//16}.png';sheet.save(out/name);atlases.append('res://assets/lol2/generated/act_one_departure/'+name)
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vn','-ac','1','-c:a','pcm_s16le',str(out/'voice.wav')],check=True)
 with wave.open(str(out/'voice.wav')) as w:
  assert w.getnchannels()==1;rate=w.getframerate();samples=w.getnframes()
 chunks=parse_vqa_chunks(source.read_bytes())
 assert sum(k==b'VQFR' for k,v in chunks)==318
 assert sum(len(v)*2 for k,v in chunks if k==b'SND2')==samples
 result=dict(source_audio_samples=samples,source_frame_count=318,decoder_note='FFmpeg may report a terminal demuxer packet diagnostic; all318 source VQFR frames and all478484 source SND2 samples are required and verified.',frames=318,fps=15,width=640,height=400,columns=4,atlases=atlases,audio='res://assets/lol2/generated/act_one_departure/voice.wav',audio_samples=samples,audio_rate=rate,duration=max(318/15,samples/rate))
 (out/'playback.json').write_text(json.dumps(result,indent=2)+'\n');print(result['frames'],samples,rate,result['duration'])
 return result

def main():
 ROOT=Path(__file__).resolve().parents[1];out=ROOT/'assets/lol2/generated/act_one_departure';cache=ROOT/'tmp/departure_frames';cache.mkdir(exist_ok=True)
 sys.path.insert(0,'~/lol2_re_publish_20260911/tools')
 from lol2_vqa_decode import parse_vqa_chunks
 stage_playback(ROOT/'tmp/E125E.VQA',out,cache,parse_vqa_chunks)

if __name__=='__main__':main()
