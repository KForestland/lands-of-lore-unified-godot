import sys,json,struct,hashlib,argparse,tempfile,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
from lol2_creature_sprite_format import sections,group_frames,lcw,decode_blocks,rgb_palette
from lol2 import map_materials
from prepare_creature_audio_clips import stage_clips
parser=argparse.ArgumentParser(description="Rebuild original Museum Belial animation atlases")
parser.add_argument('--game',required=True,type=Path);parser.add_argument('--out',required=True,type=Path)
args=parser.parse_args();game=args.game.resolve();destination=args.out.resolve()
if destination.exists() or destination==game or destination in game.parents or game in destination.parents:raise ValueError('Output must be fresh and outside input')
contract=json.loads((ROOT/'scripts/lol2/museum_belial_source.json').read_text())
arc=(game/'DAT/L3_DH.MIX').read_bytes()
if hashlib.sha256(arc).hexdigest()!=contract['source']['sha256']:raise ValueError('Museum archive changed')
for offset,raw in [(contract['sound_control']['placement_offset'],contract['sound_control']['placement_hex']),(contract['prop']['placement_offset'],contract['prop']['placement_hex'])]+[(c['archive_offset'],c['raw_hex']) for g in contract['owners'] for c in g['commands']]:
 data=bytes.fromhex(raw)
 if arc[offset:offset+len(data)]!=data:raise ValueError('Source record changed')
temporary=tempfile.TemporaryDirectory(prefix='museum-belial-');h=Path(temporary.name)
map_materials.export_materials(game,'L3_DH',h/'materials')
b=(h/'materials/texture.bin').read_bytes()
if hashlib.sha256(b).hexdigest()!='7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07':raise ValueError('Museum texture changed')
s=sections(b);paloff=struct.unpack_from('<I',b,4)[0];pal=rgb_palette(b[paloff:paloff+768],6)
sha=lambda x:hashlib.sha256(x).hexdigest()
groups=group_frames({k:struct.unpack_from('<6H11I',b,s[2]+k*56) for k in range(970,1070)})
assert [(g['base'],g['count']) for g in groups]==[(970,39),(1009,61)]
out=h/'sequences';out.mkdir(exist_ok=False);rows=[];books={};sheet=Image.new('RGB',(960,400),'#555555')
for gi,g in enumerate(groups):
 atlas=Image.new('RGBA',(640*8,400*((g['count']+7)//8)))
 for fi,k in enumerate(g['frames']):
  v=struct.unpack_from('<6H11I',b,s[2]+k*56);payload=b[s[3]+v[7]:s[3]+v[7]+v[12]];ci=struct.unpack_from('<I',payload,8)[0]
  if ci not in books:
   off,allocation,packed=struct.unpack_from('<3I',b,s[9]+ci*12);assert s[8]<=off and off+allocation<=s[9] and packed<=allocation;books[ci]=lcw(b[off:off+packed])
  w,ht,pixels,used,tail=decode_blocks(payload,books[ci]);assert (w,ht)==(640,400)
  im=Image.frombytes('P',(w,ht),pixels);im.putpalette(pal);im=im.convert('RGBA');im.putalpha(Image.frombytes('L',(w,ht),bytes(255 if i else 0 for i in pixels)))
  atlas.paste(im,((fi%8)*640,(fi//8)*400));im.save(out/f'{k}.png')
  if fi in (0,g['count']//2,g['count']-1):
   col=(0,g['count']//2,g['count']-1).index(fi);small=im.resize((320,200));sheet.paste(small,(col*320,gi*200),small)
  rows.append(dict(descriptor=k,base=g['base'],frame=fi,payload_sha256=sha(payload),indices_sha256=sha(pixels),codebook=ci,codebook_sha256=sha(books[ci]),unread_tail=tail))
 atlas.save(out/f'atlas_{g["base"]}.png')
sheet.save(out/'contact_sheet.png');r=dict(status='decoded',texture_sha256=sha(b),groups=groups,frames=rows,alpha='Modern adapter: index0 transparent; index1 retained as palette colour for block family.',limits=['Native cadence and event completion not yet replayed.','Portable original-archive producer not yet supplied.']);(h/'decoded_sequences.json').write_text(json.dumps(r,indent=2)+'\n');print('Decoded',len(rows),'frames')

staged=h/'staged';staged.mkdir()
for base in (970,1009):shutil.copyfile(out/f'atlas_{base}.png',staged/f'atlas_{base}.png')
for name,wanted in contract['atlas_hashes'].items():
 if sha((staged/name).read_bytes())!=wanted:raise ValueError('Atlas changed: '+name)
clips=stage_clips(h,"museum_belial",[1175,1176],game=game)
for request,row in clips.items():
 if row["wav_sha256"]!=contract["audio"][request]["wav_sha256"]:raise ValueError("Sound changed")
 shutil.copyfile(h/"assets/lol2/generated/museum_belial"/(request+".wav"),staged/(request+".wav"))
shutil.copytree(staged,destination)
temporary.cleanup()
print('PASS portable Belial two atlases from original archive')
