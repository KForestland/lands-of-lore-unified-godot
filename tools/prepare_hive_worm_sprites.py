#!/usr/bin/env python3
"""Stage source WORM row-span sequences with all mip boundaries checked."""
import argparse,hashlib,json,struct,sys
from pathlib import Path
from lol2_creature_sprite_format import decode_rows
from lol2_material_format import sections
from lol2_material_format import rgb_palette
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

def prepare(proof,blob,root):
 TEXTURE_HASH=proof['texture_sha256']
 assert hashlib.sha256(blob).hexdigest()==TEXTURE_HASH
 sec=sections(blob);p=struct.unpack_from('<I',blob,4)[0];palette=rgb_palette(blob[p:p+768],6)
 out=root/'assets/lol2/generated/hive_worm_sprites';out.mkdir(parents=True,exist_ok=True);clips=[]
 for clip in proof['clips']:
  resource=clip['resource'];d=struct.unpack_from('<6H11I',blob,sec[2]+resource*56)
  assert d[3] in [0x28e,0x2c6] and d[4]==clip['frames']
  images=[];frames=[];mips=[]
  for mip in range(d[5]&255):
   pos=sec[3]+d[7+mip]
   for frame in range(clip['frames']):
    size=8+struct.unpack_from('<H',blob,pos+6)[0];assert frame!=0 or size==d[12+mip]
    payload=blob[pos:pos+size];assert len(payload)==size
    width,height,pixels,_=decode_rows(payload,d[3],allow_special=True)
    assert (width,height)==(max(1,d[1]>>mip),max(1,d[2]>>mip))
    mips.append(dict(mip=mip,frame=frame,source_offset=pos,size=size,indexed_sha256=hashlib.sha256(pixels).hexdigest()))
    if mip==0:
     rgba=bytes(c for i in pixels for c in (*palette[i*3:i*3+3],255 if i else 0))
     indexed=Image.frombytes('P',(width,height),pixels);indexed.putpalette(palette);name=f'indexed_{resource}_{frame}.png';indexed.save(out/name,transparency=0)
     assert Image.open(out/name).tobytes()==pixels
     images.append(Image.frombytes('RGBA',(width,height),rgba));frames.append(dict(resource=resource,frame=frame,indexed_file=name,indexed_sha256=hashlib.sha256(pixels).hexdigest(),special_pixels=pixels.count(1),payload_sha256=hashlib.sha256(payload).hexdigest(),rgba_sha256=hashlib.sha256(rgba).hexdigest()))
    pos+=size
   if mip+1<(d[5]&255):assert pos==sec[3]+d[8+mip]
  width,height=images[0].size;columns=min(6,len(images));sheet=Image.new('RGBA',(width*columns,height*((len(images)+columns-1)//columns)))
  for i,im in enumerate(images):sheet.paste(im,((i%columns)*width,(i//columns)*height))
  filename=f"selector_{clip['selector']}.png";sheet.save(out/filename)
  with Image.open(out/filename) as decoded:
   for i,f in enumerate(frames):
    x=(i%columns)*width;y=(i//columns)*height
    assert hashlib.sha256(decoded.crop((x,y,x+width,y+height)).tobytes()).hexdigest()==f['rgba_sha256']
  clips.append(dict(selector=clip['selector'],frames=len(images),columns=columns,width=width,height=height,file=filename,source_frames=frames,mip_checks=mips,png_sha256=hashlib.sha256((out/filename).read_bytes()).hexdigest()))
 manifest=dict(version=1,clips=clips,archive_sha256=proof['archive_sha256'],texture_sha256=TEXTURE_HASH,scope='Pinned WORM definition2 first views: row-span static284 and ten internal frames237. Every mip decoded and intermediate mip boundary checked, indexed PNGs and atlas crops roundtrip. Index0 alpha/index1 preview mapping and world size/anchoring are adapters. Native frame counts/events/ticks independently checked; scripted behavior/action admission and live integration remain open.')
 (out/'sprites.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (root/'docs').mkdir(parents=True,exist_ok=True)
 (root/'docs/hive-worm-sprites-checks.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('PASS',sum(c['frames'] for c in clips),'worm frames;',sum(len(c['mip_checks']) for c in clips),'decoded mip frames and atlas round trips')


def main():
 from verify_hive_worm_animation import main as verify
 from verify_hive_attack_runtime import OUT
 prepare(verify(),(OUT/'texture.bin').read_bytes(),ROOT)

def cli():
 from lol2_source_format import parse_mix
 from lol2_creature_sprite_format import parse_states
 p=argparse.ArgumentParser(description='Prepare existing Hive worm sprite atlases from original media and published animation evidence.')
 p.add_argument('--game',type=Path,required=True)
 p.add_argument('--texture',type=Path,required=True)
 p.add_argument('--proof',type=Path,required=True)
 p.add_argument('--output-root',type=Path,required=True)
 args=p.parse_args()
 if args.output_root.exists():p.error('Use a fresh output root')
 proof=json.loads(args.proof.read_text())
 if [(c['selector'],c['resource'],c['frames']) for c in proof['clips']]!=[(0, 284, 1), (1, 237, 10)]:p.error('Animation proof does not contain the complete expected clip set')
 archive=(args.game/'DAT/L5_HC.MIX').read_bytes()
 if hashlib.sha256(archive).hexdigest()!='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8':p.error('Original Hive archive does not match')
 if proof['archive_sha256']!=hashlib.sha256(archive).hexdigest() or proof['definition']!=2:p.error('Animation proof does not match Hive worm')
 blob=args.texture.read_bytes()
 if hashlib.sha256(blob).hexdigest()!='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba' or proof['texture_sha256']!=hashlib.sha256(blob).hexdigest():p.error('Original Hive texture does not match')
 entry=next(e for e in parse_mix(archive) if e['key']==3776335874)
 entity=parse_states(archive[entry['offset']:entry['offset']+entry['size']])['entities'][2]
 for clip in proof['clips']:
  if entity['states'][clip['selector']]['views'][0]['resource_reference']!=clip['resource']:p.error('Animation proof resource does not match original state')
 prepare(proof,blob,args.output_root)

if __name__=='__main__':
 if len(sys.argv)>1:cli()
 else:main()
