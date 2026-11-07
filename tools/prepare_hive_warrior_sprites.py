#!/usr/bin/env python3
"""Stage verified HIVEW first-view animation frames locally; no live clock implied."""
import argparse,hashlib,json,struct,sys
from pathlib import Path
from lol2_creature_sprite_format import lcw,decode_blocks
from lol2_creature_sprite_format import decode_rows
from lol2_material_format import sections
from lol2_material_format import rgb_palette
from lol2_creature_sprite_format import group_frames
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

def prepare(proof,blob,root):
 TEXTURE_HASH=proof['texture_sha256']
 assert hashlib.sha256(blob).hexdigest()==TEXTURE_HASH
 sec=sections(blob);p=struct.unpack_from('<I',blob,4)[0];palette=rgb_palette(blob[p:p+768],6)
 descriptors={i:struct.unpack_from('<6H11I',blob,sec[2]+i*56) for i in range((sec[3]-sec[2])//56)}
 groups={g['base']:g for g in group_frames({i:d for i,d in descriptors.items() if d[3]==0x1246})}
 out=root/'assets/lol2/generated/hive_warrior_sprites';out.mkdir(parents=True,exist_ok=True);clips=[]
 for clip in proof['clips']:
  resource=clip['resource'];resources=groups[resource]['frames'] if resource in groups else [resource];assert len(resources)==clip['frames']
  frames=[];images=[]
  for ordinal in resources:
   d=descriptors[ordinal];payload=blob[sec[3]+d[7]:][:d[12]];assert len(payload)==d[12]
   if d[3]==0x1246:
    ci=struct.unpack_from('<I',payload,8)[0];offset,allocation,packed=struct.unpack_from('<III',blob,sec[9]+ci*12)
    assert sec[8]<=offset and offset+allocation<=sec[9] and 0<packed<=allocation
    book=lcw(blob[offset:offset+packed]);width,height,pixels,_,tail=decode_blocks(payload,book)
   else:
    assert d[3:5]==(0x28e,1);width,height,pixels,_=decode_rows(payload,allow_special=True)
   assert (width,height)==d[1:3]
   rgba=bytes(c for i in pixels for c in (*palette[i*3:i*3+3],255 if i else 0))
   indexed=Image.frombytes('P',(width,height),pixels);indexed.putpalette(palette);indexed_name=f'indexed_{ordinal}.png';indexed.save(out/indexed_name,transparency=0)
   assert Image.open(out/indexed_name).tobytes()==pixels
   images.append(Image.frombytes('RGBA',(width,height),rgba));frames.append(dict(resource=ordinal,indexed_file=indexed_name,indexed_sha256=hashlib.sha256(pixels).hexdigest(),special_pixels=pixels.count(1),payload_sha256=hashlib.sha256(payload).hexdigest(),rgba_sha256=hashlib.sha256(rgba).hexdigest()))
  assert all(im.size==images[0].size for im in images);width,height=images[0].size;columns=min(6,len(images));sheet=Image.new('RGBA',(width*columns,height*((len(images)+columns-1)//columns)))
  for i,im in enumerate(images):sheet.paste(im,((i%columns)*width,(i//columns)*height))
  filename=f"selector_{clip['selector']}.png";sheet.save(out/filename)
  with Image.open(out/filename) as decoded:
   for i,f in enumerate(frames):
    x=(i%columns)*width;y=(i//columns)*height
    assert hashlib.sha256(decoded.crop((x,y,x+width,y+height)).tobytes()).hexdigest()==f['rgba_sha256']
  clips.append(dict(selector=clip['selector'],frames=len(images),columns=columns,width=width,height=height,file=filename,source_frames=frames,png_sha256=hashlib.sha256((out/filename).read_bytes()).hexdigest()))
 manifest=dict(version=1,clips=clips,archive_sha256=proof['archive_sha256'],texture_sha256=TEXTURE_HASH,scope='Pinned first-view source frames and atlas round trips. Selector14 has other directional views not staged here. Indexed PNGs preserve source indices including special index1. RGBA preview does not composite index1 destination-remapping semantics; index0 transparency and world anchoring remain presentation adapters. No AI choice, death-to-corpse transition or live clock implied.')
 (out/'sprites.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (root/'docs').mkdir(parents=True,exist_ok=True)
 (root/'docs/hive-warrior-sprites-checks.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('PASS',sum(c['frames'] for c in clips),'source warrior frames and atlas round trips')


def main():
 from verify_hive_warrior_animation import main as verify
 from verify_hive_attack_runtime import OUT
 prepare(verify(),(OUT/'texture.bin').read_bytes(),ROOT)

def cli():
 from lol2_source_format import parse_mix
 from lol2_creature_sprite_format import parse_states
 p=argparse.ArgumentParser(description='Prepare existing Hive warrior sprite atlases from original media and published animation evidence.')
 p.add_argument('--game',type=Path,required=True)
 p.add_argument('--texture',type=Path,required=True)
 p.add_argument('--proof',type=Path,required=True)
 p.add_argument('--output-root',type=Path,required=True)
 args=p.parse_args()
 if args.output_root.exists():p.error('Use a fresh output root')
 proof=json.loads(args.proof.read_text())
 if [(c['selector'],c['resource'],c['frames']) for c in proof['clips']]!=[(11, 1549, 18), (12, 1053, 16), (13, 1531, 18), (14, 1203, 16), (19, 1003, 16), (20, 1591, 13), (21, 335, 1)]:p.error('Animation proof does not contain the complete expected clip set')
 archive=(args.game/'DAT/L5_HC.MIX').read_bytes()
 if hashlib.sha256(archive).hexdigest()!='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8':p.error('Original Hive archive does not match')
 if proof['archive_sha256']!=hashlib.sha256(archive).hexdigest() or proof['definition']!=0:p.error('Animation proof does not match Hive warrior')
 blob=args.texture.read_bytes()
 if hashlib.sha256(blob).hexdigest()!='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba' or proof['texture_sha256']!=hashlib.sha256(blob).hexdigest():p.error('Original Hive texture does not match')
 entry=next(e for e in parse_mix(archive) if e['key']==3776335874)
 entity=parse_states(archive[entry['offset']:entry['offset']+entry['size']])['entities'][0]
 for clip in proof['clips']:
  if entity['states'][clip['selector']]['views'][0]['resource_reference']!=clip['resource']:p.error('Animation proof resource does not match original state')
 prepare(proof,blob,args.output_root)

if __name__=='__main__':
 if len(sys.argv)>1:cli()
 else:main()
