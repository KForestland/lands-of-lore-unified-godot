#!/usr/bin/env python3
"""Stage Rashar hotspot/offer/pickup media named by the native callback replay.

Inputs are the pinned MAGIC.MIX clips requested by MAGIC_.WOM, the two Luther lines
routed to the localized sound bank (speaker2/format24, bias141 as verified for the Hive
rune room), and MAGSHAPE.SHP frames drawn with the room background palette. Existing
magic_shop/ and hive_rune_speech/ assets are only read.

stage_offers() takes its helpers explicitly, so prepare_magic_shop.py --game ... can stage this pack with published
helpers; run without arguments, main() uses the historical imports and checks as before.
"""
import json,struct,subprocess,types,wave
from pathlib import Path
from PIL import Image

BANK_SHA='e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6'

def wav(source,target,expected=None):
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ac','1','-c:a','pcm_s16le',str(target)],check=True)
 with wave.open(str(target)) as f:
  assert f.getnchannels()==1 and (expected is None or f.getnframes()==expected);return f.getnframes(),f.getframerate()

def bank_audio(bank,line,u32):
 request=struct.unpack_from('<H',bank,len(bank)-808+(line+141)*2)[0];assert request<u32(bank,0x258)
 row=bank[u32(bank,0x25c)+request*60:][:60];audio=bank[u32(row,0):][:u32(row,4)]
 rate,packed,decoded,flags,codec=struct.unpack_from('<HIIBB',audio);assert len(audio)==packed+12 and flags==2 and codec==99
 return request,row[16:].split(b'\0')[0].decode(),audio,decoded

def stage_offers(checks,arc,existing,bank,out,cache,root,h):
 """h: digest, extract, movie, stage_patch, parse_vqa_chunks, lcw, shape, u32. Returns the manifest written to out/offers.json."""
 clips={};missing=[]
 for row in checks['media_requests']:
  a,b,c=row['request'];key=f'{a}:{b}:{c}'
  if a==30 and str(b) in existing:continue # Already staged by prepare_magic_shop.py.
  if row['vqa']:
   name=f'WOMS\\MAGIC\\{a:02d}{b:03d}{c:02d}E.VQA';record=h.movie(arc,name);payload,_=h.extract(arc,name)
   path=cache/name.split('\\')[-1];path.write_bytes(payload)
   clips[key]=h.stage_patch(path,out/(path.stem+'.ogv'),record)
  elif row['aud']:
   name=f'WOMS\\MAGIC\\{a:02d}{b:03d}{c:02d}E.AUD';payload,binding=h.extract(arc,name)
   rate,packed,decoded,flags,codec=struct.unpack_from('<HIIBB',payload);assert len(payload)==packed+12
   path=cache/name.split('\\')[-1];path.write_bytes(payload);target=out/(path.stem+'.wav')
   samples,rate2=wav(path,target,decoded//2);assert rate2==rate
   clips[key]=dict(binding,frames=0,audio='res://'+str(target.relative_to(root)),audio_samples=samples,rate=rate,duration=samples/rate)
  elif row['sound_bank']:
   request,source_name,audio,decoded=bank_audio(bank,b,h.u32);path=cache/f'2_{b}.aud';path.write_bytes(audio);target=out/f'2_{b}.wav'
   samples,rate=wav(path,target,decoded//2)
   clips[key]=dict(frames=0,audio='res://'+str(target.relative_to(root)),audio_samples=samples,rate=rate,duration=samples/rate,
    request=request,trailer_index=b+141,source_name=source_name,audio_sha256=h.digest(audio))
  else:missing.append(key)
 # MAGSHAPE frames, room palette from the background's first CPL0.
 shp,shape_binding=h.extract(arc,'WOMS\\MAGIC\\MAGSHAPE.SHP');assert struct.unpack_from('<H',shp)[0]==6
 background,_=h.extract(arc,'WOMS\\MAGIC\\MAGIC_.VQA');palette=None
 for tag,payload in h.parse_vqa_chunks(background):
  if tag==b'VQFR':
   parts=dict(h.parse_vqa_chunks(b'FORM'+bytes(4)+b'WVQA'+payload));palette=parts.get(b'CPL0') or (h.lcw(parts[b'CPLZ']) if b'CPLZ' in parts else None)
   if palette:break
 assert palette and len(palette)==768
 rgb=bytes((v&63)*4 for v in palette);sprites={}
 for i in range(6):
  w,hh,pixels=h.shape(shp,i);img=Image.frombytes('P',(w,hh),pixels);img.putpalette(rgb);img.info['transparency']=0
  target=out/f'magshape_{i}.png';img.convert('RGBA').save(target)
  sprites[str(i)]=dict(path='res://'+str(target.relative_to(root)),width=w,height=hh,indices_sha256=h.digest(pixels))
 manifest=dict(version=1,clips=clips,sprites=sprites,missing=missing,shape=shape_binding)
 (out/'offers.json').write_text(json.dumps(manifest,indent=1)+'\n')
 return manifest

def main():
 from audit_monastery_rooms import ROOT,GAME,digest,extract,movie
 from audit_hive_rune_rooms import u32
 from prepare_monastery_rooms import stage_patch,parse_vqa_chunks,lcw
 from prepare_museum_interface import shape
 from prepare_hive_wax import entry
 OUT=ROOT/'assets/lol2/generated/magic_shop_offers'
 checks=json.loads((ROOT/'docs/magic-shop-callbacks-checks.json').read_text())
 arc=(GAME/'DAT/MAGIC.MIX').read_bytes()
 assert digest(arc)==json.loads((ROOT/'docs/act-one-shops-source.json').read_text())['rooms']['MAGIC']['archive_sha256']
 existing=json.loads((ROOT/'assets/lol2/generated/magic_shop/room.json').read_text())['lines']
 OUT.mkdir(parents=True,exist_ok=True);cache=ROOT/'tmp/magic_shop_offers_source';cache.mkdir(parents=True,exist_ok=True)
 bank=entry('LOCALLNG.MIX',1570429112);assert digest(bank)==BANK_SHA
 hive=json.loads((ROOT/'assets/lol2/generated/hive_rune_speech/speech.json').read_text())['clips']
 # Cross-check the trailer formula against the eight already-verified response clips.
 for line in [56,21,27,58,26,33,57,20]:
  request,name,audio,_=bank_audio(bank,line,u32);assert hive[f'2:{line}']['request']==request and hive[f'2:{line}']['audio_sha256']==digest(audio)
 h=types.SimpleNamespace(digest=digest,extract=extract,movie=movie,stage_patch=stage_patch,parse_vqa_chunks=parse_vqa_chunks,lcw=lcw,shape=shape,u32=u32)
 manifest=stage_offers(checks,arc,existing,bank,OUT,cache,ROOT,h);clips,sprites,missing=manifest['clips'],manifest['sprites'],manifest['missing']
 report=dict(passed=True,manifest='assets/lol2/generated/magic_shop_offers/offers.json',manifest_sha256=digest((OUT/'offers.json').read_bytes()),
  clips={k:dict(duration=v['duration'],frames=v['frames'],samples=v['audio_samples']) for k,v in clips.items()},sprites=sprites,missing=missing,
  scope='Every non-intro movie request from the native handler replay decoded: Rashar VQA patches (exact frame/PCM counts), Luther AUD clips from MAGIC.MIX and two sound-bank lines (trailer formula cross-checked against eight verified Hive clips). MAGSHAPE six frames use background CPL palette, index0 transparent. Presentation flags and appearance are not verified here.')
 (ROOT/'docs/magic-shop-offers-media-checks.json').write_text(json.dumps(report,indent=1)+'\n')
 print('PASS',len(clips),'clips;',len(sprites),'MAGSHAPE frames; missing',missing)
if __name__=='__main__':main()
