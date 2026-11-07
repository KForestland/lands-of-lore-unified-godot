#!/usr/bin/env python3
"""Stage byte-pinned CHV room movies/background to an explicit output directory.
Default is tmp: safe during a frozen gameplay regression. No gameplay/script files written.
"""
import argparse,hashlib,json,struct,shutil,subprocess,wave
from pathlib import Path
from lol2_source_format import parse_mix
from lol2_movie_format import ww_hash_v1
from prepare_cave_entrance_death import encode
import lol2_movie_media
from prepare_cave_cfall_room import bank_cue,LOCALLNG_SHA256,SOUND_BANK

def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('tmp/l14_chv_staged'));p.add_argument('--cache',type=Path,default=Path('tmp/l14_chv_media_cache'));a=p.parse_args()
 b=(a.game/'DAT/CHV.MIX').read_bytes();assert sha(b)=='2abeaa022c28d20c18494661f8195fbe3b688f43f639d19ddb7c6217a525e8ed'
 entries={e['key']:e for e in parse_mix(b)};a.output.mkdir(parents=True,exist_ok=True);cache=a.cache;cache.mkdir(parents=True,exist_ok=True)
 def extract(name):
  row=entries[ww_hash_v1(name)];return b[row['offset']:row['offset']+row['size']]
 dll=extract('WOMS\\CHV_.WOM');assert sha(dll)=='eb84dac706126385234b1e84af00be7437438bbec5a893751b05dccbd3520555'
 m=dll[48:48+struct.unpack_from('<I',dll,36)[0]]
 assert m[0x600:0x60e]==b'134-Dreamstone'
 assert m[0x621:0x630]==b'go_to_level_16\0'
 source={'archive_sha256':sha(b),'module_sha256':sha(dll),'room':30,'hotspot':[194,88,396,218],'callbacks':{str(i):{'offset':o,'raw_hex':m[o:e].hex()} for i,o,e in [(1,0x47c,0x4cd),(4,0x4f7,0x5ae),(9,0x5b7,0x5f5)]},'scope':'Static room byte witness; host item predicates and execution not replayed. Kit consumption and scene binding are separate.'}
 media={}
 for name,count,pinned in [('voices',450,'e2edacd2ddc8de0b357864f49da636c815606c637fe00bc4fb9df1f9d39f7492'),('CITY',1540,'1bef3659f3c62fda4bc1fdf1ac0edb250fe6929bee522143e39e5ad43d7036dd')]:
  data=extract('WOMS\\CHV\\'+name.upper()+'.VQA');assert sha(data)==pinned;vqa=cache/(name+'.vqa');vqa.write_bytes(data);target=a.output/(name.lower()+'.ogv')
  info=encode(vqa,cache/name,count,target);info.update(source_sha256=pinned,sha256=sha(target.read_bytes()),file=target.name);media[name.lower()]=info;print('PASS',name,info['frames'],flush=True)
 data=extract('WOMS\\CHV\\CHV_.VQA');assert sha(data)=='a93e5cb02b52ddcc28647376d082142150faa0b5cf573de1317011c9c7af7d5c';vqa=cache/'chv.vqa';vqa.write_bytes(data)
 frames=lol2_movie_media.decode(vqa,cache/'background',30,(640,400));shutil.copyfile(frames[-1],a.output/'background.png');media['background']={'source_sha256':sha(data),'frame':30,'sha256':sha((a.output/'background.png').read_bytes())}
 loc=(a.game/'LOCALLNG.MIX').read_bytes();assert sha(loc)==LOCALLNG_SHA256
 row=next(e for e in parse_mix(loc) if e['key']==SOUND_BANK[0]);bank=loc[row['offset']:row['offset']+row['size']];assert sha(bank)==SOUND_BANK[1]
 media['cues']={}
 for line in [28]:
  audio,info=bank_cue(bank,line);aud=cache/('cue_2_'+str(line)+'.aud');aud.write_bytes(audio);wav=a.output/('cue_2_'+str(line)+'.wav')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(aud),'-ac','1','-c:a','pcm_s16le','-fflags','+bitexact','-flags:a','+bitexact',str(wav)],check=True)
  with wave.open(str(wav)) as w:rate,samples=w.getframerate(),w.getnframes()
  assert rate==info['rate'] and samples*2==info['decoded']
  media['cues'][str(line)]=dict(info,file=wav.name,samples=samples,sha256=sha(wav.read_bytes()))
 source['sound_bank_sha256']=SOUND_BANK[1]
 (a.output/'source.json').write_text(json.dumps(source,indent=1)+'\n');(a.output/'media.json').write_text(json.dumps(media,indent=1)+'\n');print('PASS CHV original media and source pins',flush=True)
if __name__=='__main__':main()
