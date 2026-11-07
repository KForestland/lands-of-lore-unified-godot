#!/usr/bin/env python3
"""Bind RUNES audio-only callbacks to the original localized sound-bank trailer.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_hive_rune_speech.py --game GAME --room-plan scripts/lol2/hive_rune_room.gd \
      --speech scripts/lol2/hive_rune_speech.gd --liz-source scripts/lol2/liz_room_source.json --output-root FRESH
The explicit path stages assets/lol2/generated/hive_rune_speech from the original LOCALLNG.MIX sound bank with no native
replay: the 15 lines are this tool's constants, checked against the published runtime plans (hive_rune_room.gd movie
effects/line choices and hive_rune_speech.gd RESPONSE_LINES); speaker-2 requests use the published trailer formula
(prepare_magic_shop_offers.bank_audio, bias 141) and speaker-100 line 2 is checked against the published LIZ cue record
(trailer 270 = 2 + 268, request, sha256). No docs are written. Without arguments the historical native producer runs
unchanged.
"""
import struct,json,sys,subprocess,wave
from pathlib import Path
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
 import argparse,hashlib,re,shutil
 from lol2_source_format import parse_mix,u32
 import prepare_magic_shop_offers as offers  # published trailer formula (bias141)
 def digest(b):return hashlib.sha256(b).hexdigest()
 ROOT=GAME=None  # set by cli()
else:
 from audit_hive_rune_rooms import ROOT,GAME,PINS,extract,digest,fixups,u32,capstone
 from prepare_hive_wax import entry
 from verify_creature_states import CreatureReplay

 class SpeechReplay(CreatureReplay):
  def execute(self,start,stop):
   stops=stop if isinstance(stop,set) else {stop};signed_loads={pc for pc,i in self.instructions.items() if i.mnemonic=='movsx'}
   pc=start
   for _ in range(16):
    pc=super().execute(pc,stops|signed_loads)
    if pc in stops:return pc
    i=self.instructions[pc];value=self.get(i,i.operands[1]);bits=i.operands[1].size*8
    value=value-(1<<bits) if value&(1<<(bits-1)) else value
    self.put(i,i.operands[0],value);pc+=i.size
   raise AssertionError('Signed-load budget')

def main():
 exe=(GAME/'LOLG.DAT').read_bytes();assert digest(exe)=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
 dll,_=extract((GAME/'DAT/RUNES.MIX').read_bytes(),'WOMS\\RUNES_.WOM');assert digest(dll)==PINS['RUNES'];module=dll[48:]
 md=capstone.Cs(3,4);md.detail=True;init=list(md.disasm(module[0xf6:0x47c],0xf6));le=0x39024+u32(exe,0x39060);first=u32(exe,le+u32(exe,le+0x40)+108);bindings={}
 for slot,offset,host in [(0x770,0x54,0xee784),(0x81c,0xfc,0xf133c),(0x820,0x100,0xf14cc)]:
  i=next(i for i,row in enumerate(init) if row.mnemonic=='mov' and row.op_str==f'dword ptr [{hex(slot)}], edx');assert init[i-1].op_str==f'edx, dword ptr [eax + {hex(offset)}]'
  address=0xe92c+offset;rel=fixups(exe,le,first-1+address//4096)[address%4096];assert rel['target_object']==2 and rel['target_offset']+0x59024==host;bindings[hex(slot)]=dict(table_offset=offset,host=host,relocation=rel)
 raw=entry('LOCALLNG.MIX',1570429112);assert digest(raw)=='e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6'
 ins={};code=[]
 for a,z in [(0xe3725,0xe3747),(0xeea7f,0xeeaae),(0xeeac2,0xeeafe),(0xee8c0,0xee8eb),(0xee901,0xee93d),(0xf14cc,0xf14df)]:
  data=exe[a+0x37000:z+0x37000];rows=list(md.disasm(data,a));assert rows[-1].address+rows[-1].size==z;ins.update({i.address:i for i in rows});code.append(dict(start=a,end=z,sha256=digest(data)))
 m=SpeechReplay(ins,b'');stack,table=0x600000,0x500000;m.regs.update(esp=stack,esi=0x23c68,edi=77);m.writemem(0x269cc,4,table);m.execute(0xe3725,0xe372d);assert [m.readmem(m.regs['esp']+i*4,4) for i in range(3)]==[77,0xfffffcd8,2]
 m.execute(0xe3732,0xe3742);assert [m.readmem(m.regs['esp']+i*4,4) for i in range(3)]==[77,table,808]
 m.mem[table:table+808]=raw[-808:];m.writemem(0xe920,1,127);m.writemem(0xbb54,4,0)
 out=ROOT/'assets/lol2/generated/hive_rune_speech';out.mkdir(parents=True,exist_ok=True);cache=ROOT/'tmp/hive_rune_speech';cache.mkdir(parents=True,exist_ok=True);media={};checks=[]
 for speaker,lines,bias in [(2,[20,21,24,26,27,33,35,51,56,57,58,62,64,66],141),(100,[2],268)]:
  for line in lines:
   m.regs.update(esp=stack,edi=line,eax=0)
   if speaker==2:
    m.execute(0xeea7f,0xeea99);m.execute(0xeea9e,0xeeaa9)
   else:
    m.execute(0xee8c0,0xee8d6);m.execute(0xee8db,0xee8e6)
   assert m.regs['ebx']==line+bias
   request=struct.unpack_from('<H',raw,len(raw)-808+(line+bias)*2)[0];assert request<u32(raw,0x258)
   m.regs['esp']=stack
   m.execute(0xeeac2 if speaker==2 else 0xee901,0xeeaf9 if speaker==2 else 0xee938)
   args=[m.readmem(m.regs['esp']+4*i,4) for i in range(5)];assert args[0:3]==[0x23c68,request,0] and args[4]==1
   row=raw[u32(raw,0x25c)+request*60:][:60];audio=raw[u32(row,0):][:u32(row,4)];rate,packed,decoded,flags,codec=struct.unpack_from('<HIIBB',audio);assert len(audio)==packed+12 and flags==2 and codec==99
   name=f'{speaker}_{line}';source=cache/(name+'.aud');source.write_bytes(audio);target=out/(name+'.wav')
   subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ac','1','-c:a','pcm_s16le',str(target)],check=True)
   with wave.open(str(target)) as f: assert f.getframerate()==rate and f.getnframes()*2==decoded and f.getnchannels()==1;samples=f.getnframes()
   media[f'{speaker}:{line}']=dict(path='res://'+str(target.relative_to(ROOT)),duration=samples/rate,samples=samples,rate=rate,request=request,trailer_index=line+bias,source_name=row[16:].split(b'\0')[0].decode(),audio_sha256=digest(audio),wav_sha256=digest(target.read_bytes()))
   checks.append(dict(speaker=speaker,line=line,bias=bias,request=request,args=args))
 # Setup callback clears only the upper trigger bits, preserving the low response history byte.
 for mask in [0,1,255,256,511,0xffffffff]:
  m.writemem(0xdb500,4,mask);m.execute(0xf14cc,0xf14de);assert m.readmem(0xdb500,4)==mask&255
 manifest=dict(version=1,clips=media,response_lines=[56,21,27,58,26,33,57,20]);(out/'speech.json').write_text(json.dumps(manifest,indent=2)+'\n')
 report=dict(executable_sha256=digest(exe),sound_bank_sha256=digest(raw),bindings=bindings,code=code,producer_cases=checks,clips=media,scope='Pinned RUNES DLL callback relocation; native producer arithmetic/request slices and loader trailer seek/read replayed with explicit manager/volume fixtures. Final808 bytes map404 logical slots to60-byte localized audio records. All15 original AUD clips decoded with exact PCM sample counts. RUNES setup slot820 resets trigger bits, preserving response history. Global manager scheduling, native RNG and captions are not reproduced here.')
 (ROOT/'docs/hive-rune-speech-source.json').write_text(json.dumps(report,indent=2)+'\n');print('PASS15 source audio callbacks, trailer mapping, exact PCM counts; setup response reset')

# ---- explicit inputs -------------------------------------------------------------------------------------------------
SPEECH=[(2,[20,21,24,26,27,33,35,51,56,57,58,62,64,66],141),(100,[2],268)]  # as main()
RESPONSE_LINES=[56,21,27,58,26,33,57,20]
PINS_EXPLICIT={'room_plan':'6010102d9883073069d27e23f6a5c9b3da88d9c7b9e1f9895c8473054ac97e82',  # scripts/lol2/hive_rune_room.gd
 'speech':'5894aac2bac4a04c95ed37054bbcb1fe77297852d30e3c0e83e3dfbc2476615d',  # scripts/lol2/hive_rune_speech.gd
 'liz_source':'c941a0066dbf40753e7d4bab961780426eb28910ff27cdcf635e4ef0b00cecf5'}  # scripts/lol2/liz_room_source.json
OFFERS_SHA256='50a043e423e0b99ecbd87679499e3c13cbf652c3a016eeadfe05994a2ed951c4'  # tools/prepare_magic_shop_offers.py
LOCALLNG_SHA256='113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8'
BANK=(1570429112,'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6')  # LOCALLNG.MIX entry key, sha256

def published_lines(plan,speech):
 """Speaker/line pairs named by the published runtime plans."""
 pairs={(int(a),int(b)) for a,b in re.findall(r'\["movie",(\d+),(\d+),24\]',plan)}
 if '["movie",2,line,24]' in plan:pairs|={(2,int(x)) for x in re.findall(r'\bline :?= (\d+)',plan)}
 response=json.loads(re.search(r'const RESPONSE_LINES := (\[[0-9, ]*\])',speech).group(1))
 return pairs|{(2,x) for x in response},response

def cli():
 global ROOT,GAME
 p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
 for name in ['game','room-plan','speech','liz-source','output-root']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 if a.output_root.exists():p.error('--output-root must be a fresh directory')
 if shutil.which('ffmpeg') is None:p.error('ffmpeg not found on PATH')
 texts={}
 for key,path in [('room_plan',a.room_plan),('speech',a.speech),('liz_source',a.liz_source)]:
  if not path.is_file():p.error('Missing input: '+str(path))
  if digest(path.read_bytes())!=PINS_EXPLICIT[key]:p.error(f'{path}: not the pinned published {key.replace("_","-")} ({PINS_EXPLICIT[key]})')
  texts[key]=path.read_text()
 if digest(Path(offers.__file__).read_bytes())!=OFFERS_SHA256:p.error(f'{offers.__file__}: not the pinned trailer-formula tool')
 mix=a.game/'LOCALLNG.MIX'
 if not mix.is_file():p.error('Missing original '+str(mix))
 blob=mix.read_bytes()
 if digest(blob)!=LOCALLNG_SHA256:p.error(f'{mix}: not the pinned original')
 try:
  row=next(e for e in parse_mix(blob) if e['key']==BANK[0]);raw=blob[row['offset']:][:row['size']];assert digest(raw)==BANK[1],'sound bank'
  pairs,response=published_lines(texts['room_plan'],texts['speech'])
  assert pairs=={(s,l) for s,lines,_ in SPEECH for l in lines},'published plans name a different line set'
  assert response==RESPONSE_LINES,'RESPONSE_LINES'
  cue=json.loads(texts['liz_source'])['cues']['100:2'];assert cue['trailer_index']==2+268,'speaker-100 bias'
  plan=[]
  for speaker,lines,bias in SPEECH:
   for line in lines:
    if speaker==2:request,source_name,audio,decoded=offers.bank_audio(raw,line,u32)
    else:
     request=struct.unpack_from('<H',raw,len(raw)-808+(line+bias)*2)[0];assert request<u32(raw,0x258)
     r=raw[u32(raw,0x25c)+request*60:][:60];audio=raw[u32(r,0):][:u32(r,4)];source_name=r[16:].split(b'\0')[0].decode()
     rate,packed,decoded,flags,codec=struct.unpack_from('<HIIBB',audio);assert len(audio)==packed+12 and flags==2 and codec==99
     assert (request,source_name,digest(audio),len(audio))==(cue['request'],cue['bank_record'],cue['sha256'],cue['bytes']),'speaker-100 cue'
    plan.append((speaker,line,bias,request,source_name,audio,decoded))
 except (AssertionError,StopIteration,KeyError,ValueError,IndexError,AttributeError,struct.error) as error:
  p.error('Inputs do not match the published contracts: '+(str(error) or type(error).__name__))
 ROOT=a.output_root.resolve()
 out=ROOT/'assets/lol2/generated/hive_rune_speech';out.mkdir(parents=True);cache=ROOT/'tmp/hive_rune_speech';cache.mkdir(parents=True);media={}
 for speaker,line,bias,request,source_name,audio,decoded in plan:  # staging and record as main()
  rate=struct.unpack_from('<H',audio)[0]
  name=f'{speaker}_{line}';source=cache/(name+'.aud');source.write_bytes(audio);target=out/(name+'.wav')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ac','1','-c:a','pcm_s16le',str(target)],check=True)
  with wave.open(str(target)) as f: assert f.getframerate()==rate and f.getnframes()*2==decoded and f.getnchannels()==1;samples=f.getnframes()
  media[f'{speaker}:{line}']=dict(path='res://'+str(target.relative_to(ROOT)),duration=samples/rate,samples=samples,rate=rate,request=request,trailer_index=line+bias,source_name=source_name,audio_sha256=digest(audio),wav_sha256=digest(target.read_bytes()))
 manifest=dict(version=1,clips=media,response_lines=RESPONSE_LINES);(out/'speech.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('PASS explicit Hive rune speech:',len(media),'clips from the published trailer formula')

if __name__=='__main__':
 if EXPLICIT:cli()
 else:main()
