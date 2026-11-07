#!/usr/bin/env python3
"""Stage source-pinned Rashar room media without rebuilding other rooms.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_magic_shop.py --game GAME --re-root RE --callbacks docs/magic-shop-callbacks-checks.json \
      --output-root FRESH
The explicit path stages BOTH assets/lol2/generated/magic_shop (room.json, background, idle, 30 Rashar lines) and
assets/lol2/generated/magic_shop_offers (prepare_magic_shop_offers.stage_offers). Every selection comes from the
published native callback contract: idle = setup start_loop; room lines = entry-case movies plus the 12-Tho Broken
knowledge case; offers = the remaining media requests. Published helpers only (tools/monastery_media.py and published
readers); the RE checkout supplies only the pinned video converter. No docs are written. Without arguments the
historical native path (audit_act_one_shops first, docs/act-one-shops-source.json records, docs report) is unchanged.
"""
import json,subprocess,sys
from pathlib import Path
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
 import argparse,hashlib,shutil,struct,types
 import monastery_media
 from monastery_media import digest,extract,movie
 ROOT=GAME=convert=None  # set by cli()

 def stage_patch(source,target,record):
  return monastery_media.stage_patch(source,target,record,ROOT)
else:
 from audit_monastery_rooms import ROOT,GAME,digest,extract
 from audit_act_one_shops import main as audit
 from prepare_monastery_rooms import stage_patch,convert

def stage_room(source,archive,out,cache):
 staged={}
 for record in [source['background'],source['idle']]+source['movies']:
  name=record['name'].split('\\')[-1];payload,binding=extract(archive,record['name']);assert digest(payload)==record['sha256']
  path=cache/name;path.write_bytes(payload);target=out/(Path(name).stem+'.ogv')
  if record is source['background']:
   convert(path,target)
   png=out/'background.png';subprocess.run(['ffmpeg','-v','error','-y','-i',str(path),'-frames:v','1',str(png)],check=True)
   staged['background']=dict(record,path='res://'+str(target.relative_to(ROOT)),duration=record['frames']/record['fps'])
   staged['background_still']='res://'+str(png.relative_to(ROOT))
  else:
   clip=stage_patch(path,target,record)
   if record is source['idle']:staged['idle']=clip
   else:staged.setdefault('lines',{})[str(int(Path(name).stem[2:5]))]=clip
 staged['canvas']=[640,400]
 (out/'room.json').write_text(json.dumps(staged,indent=2)+'\n')
 return staged

def main():
 audit()
 source=json.loads((ROOT/'docs/act-one-shops-source.json').read_text())['rooms']['MAGIC']
 archive=(GAME/'DAT/MAGIC.MIX').read_bytes();assert digest(archive)==source['archive_sha256']
 out=ROOT/'assets/lol2/generated/magic_shop';out.mkdir(parents=True,exist_ok=True)
 cache=ROOT/'tmp/magic_shop_source';cache.mkdir(parents=True,exist_ok=True)
 staged=stage_room(source,archive,out,cache)
 report=dict(passed=True,manifest='assets/lol2/generated/magic_shop/room.json',manifest_sha256=digest((out/'room.json').read_bytes()),lines=len(staged['lines']),frames=sum(x['frames'] for x in staged['lines'].values()),samples=sum(x['audio_samples'] for x in staged['lines'].values()),scope='Original Rashar background and idle plus30 source-audited dialogue patches decoded. Exact per-patch frame and PCM sample counts checked. Live integration, appearance review, entry effects and original timing remain separate.')
 (ROOT/'docs/magic-shop-media-checks.json').write_text(json.dumps(report,indent=2)+'\n');print(report)

# ---- explicit inputs -------------------------------------------------------------------------------------------------
CALLBACKS_SHA256='ce85a0c06b9404495cedd1094e7e7c1d5337a04ed09b9ba24acc3f0db7e3cc33'  # docs/magic-shop-callbacks-checks.json (published)
ORIGINALS={'DAT/MAGIC.MIX':'6c0b44382172d08c986508ff16da4d3af98a602f38bd6ecd61e8121894effc80',
           'LOCALLNG.MIX':'113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8'}
SOUND_BANK_KEY=1570429112  # LOCALLNG.MIX entry; sha256 = prepare_magic_shop_offers.BANK_SHA

def selections(contract):
 """Room records' names from the published callback contract (no recorded audit doc)."""
 cases=contract['cases']
 def movies(effects):return [tuple(e[1:4]) for e in effects or [] if e and str(e[0]).startswith('movie')]
 loops={tuple(e[1:4]) for r in cases['setup'] for e in r.get('effects') or [] if e and e[0]=='start_loop'}
 assert len(loops)==1,'setup idle loop'
 entry={m for r in cases['entry'] for m in movies(r.get('effects'))}
 knowledge={tuple(movies(r.get('effects'))) for r in cases['offer'] if r['held']=='12-Tho Broken' and any(e[:2]==['set_global','GV_KNOWLEDGE_OF_POWER_ORB'] for e in r.get('effects') or [])}
 assert len(knowledge)==1,'knowledge branch'
 lines=sorted(entry|set(next(iter(knowledge))))
 assert all(m[0]==30 and m[2]==6 for m in lines) and {tuple(r['request']) for r in contract['media_requests']}>=set(lines),'room lines'
 name=lambda m:'WOMS\\MAGIC\\%02d%03d%02dE.VQA'%m
 return 'WOMS\\MAGIC\\MAGIC_.VQA',name(next(iter(loops))),[name(m) for m in lines]

def shape(shp,i):  # as prepare_museum_interface.shape, with the published LCW decoder and the same length checks
 from lol2_creature_sprite_format import lcw
 offset=struct.unpack_from('<I',shp,2+4*i)[0]+2
 flags,h,w,h2,size,unc=struct.unpack_from('<HBHBHH',shp,offset)
 assert flags in (0,2) and h==h2 and offset+size<=len(shp)
 raw=shp[offset+10:offset+size]
 raw=raw if flags&2 else lcw(raw)
 assert len(raw)==unc
 pixels=bytearray();pos=0
 while pos<len(raw):
  value=raw[pos];pos+=1
  if value:pixels.append(value)
  else:
   assert pos<len(raw);pixels.extend(bytes(raw[pos]));pos+=1
 assert len(pixels)==w*h
 return w,h,bytes(pixels)

def cli():
 global ROOT,GAME,convert
 import prepare_magic_shop_offers as offers
 from lol2_source_format import parse_mix,u32
 from lol2_movie_format import parse_vqa_chunks
 from lol2_creature_sprite_format import lcw
 p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
 for name in ['game','re-root','callbacks','output-root']:p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 if a.output_root.exists():p.error('--output-root must be a fresh directory')
 for tool in ['ffmpeg','ffprobe']:
  if shutil.which(tool) is None:p.error(tool+' not found on PATH')
 codecs=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
 for codec in ['libtheora','libvorbis','vqavideo','pcm_s16le','adpcm_ima_ws',' png ']:
  if codec not in codecs:p.error('ffmpeg lacks '+codec.strip())
 try:converter=monastery_media.load_converter(a.re_root)
 except ValueError as error:p.error(str(error))
 if not a.callbacks.is_file():p.error('Missing input: '+str(a.callbacks))
 if digest(a.callbacks.read_bytes())!=CALLBACKS_SHA256:p.error(f'{a.callbacks}: not the pinned magic shop callback contract ({CALLBACKS_SHA256})')
 contract=json.loads(a.callbacks.read_text())
 blobs={}
 for rel,want in ORIGINALS.items():
  if not (a.game/rel).is_file():p.error('Missing original '+str(a.game/rel))
  blobs[rel]=(a.game/rel).read_bytes()
  if digest(blobs[rel])!=want:p.error(f'{a.game/rel}: not the pinned original')
 try:
  archive=blobs['DAT/MAGIC.MIX'];assert extract(archive,'WOMS\\MAGIC_.WOM')[1]==contract['dll'],'MAGIC DLL binding'
  background,idle,lines=selections(contract)
  source=dict(background=movie(archive,background),idle=movie(archive,idle),movies=[movie(archive,n) for n in lines])
  existing={str(int(n.split('\\')[-1][2:5])) for n in lines}
  for row in contract['media_requests']:
   x,y,z=row['request']
   if x==30 and str(y) in existing:continue
   if row['vqa']:movie(archive,'WOMS\\MAGIC\\%02d%03d%02dE.VQA'%(x,y,z))
   elif row['aud']:extract(archive,'WOMS\\MAGIC\\%02d%03d%02dE.AUD'%(x,y,z))
  row=next(e for e in parse_mix(blobs['LOCALLNG.MIX']) if e['key']==SOUND_BANK_KEY);bank=blobs['LOCALLNG.MIX'][row['offset']:][:row['size']]
  assert digest(bank)==offers.BANK_SHA,'sound bank'
  for r in contract['media_requests']:
   if r['sound_bank'] and not (r['vqa'] or r['aud']):offers.bank_audio(bank,r['request'][1],u32)
  extract(archive,'WOMS\\MAGIC\\MAGSHAPE.SHP')
 except (AssertionError,StopIteration,KeyError,ValueError,IndexError,struct.error) as error:
  p.error('Originals do not match the callback contract: '+(str(error) or type(error).__name__))
 convert=converter;GAME=a.game.resolve();ROOT=a.output_root.resolve()
 out=ROOT/'assets/lol2/generated/magic_shop';out.mkdir(parents=True);cache=ROOT/'tmp/magic_shop_source';cache.mkdir(parents=True)
 staged=stage_room(source,archive,out,cache)
 assert set(staged['lines'])==existing
 out2=ROOT/'assets/lol2/generated/magic_shop_offers';out2.mkdir(parents=True);cache2=ROOT/'tmp/magic_shop_offers_source';cache2.mkdir(parents=True)
 h=types.SimpleNamespace(digest=digest,extract=extract,movie=movie,stage_patch=stage_patch,parse_vqa_chunks=parse_vqa_chunks,lcw=lcw,shape=shape,u32=u32)
 manifest=offers.stage_offers(contract,archive,staged['lines'],bank,out2,cache2,ROOT,h)
 print('PASS explicit magic shop:',len(staged['lines']),'room lines;',len(manifest['clips']),'offer clips;',len(manifest['sprites']),'MAGSHAPE frames; missing',manifest['missing'])

if __name__=='__main__':
 if EXPLICIT:cli()
 else:main()
