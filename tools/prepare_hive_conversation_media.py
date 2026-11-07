#!/usr/bin/env python3
"""Prepare the complete existing Hive conversation presentation from original files."""
import argparse,hashlib,json,struct,subprocess,tempfile
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_museum_hourglass_media import chunks
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections as texture_sections
from lol2_movie_format import ww_hash_v1


def sha(b):return hashlib.sha256(b).hexdigest()
def require(value,message):
    if not value:raise ValueError(message)

def prepare(game,texture,output):
    require(not output.exists(),'Output must be fresh')
    for source in (game,texture):require(output!=source and output not in source.parents and source not in output.parents,'Output overlaps an input')
    archive=(game/'DAT/L5_HC.MIX').read_bytes();blob=texture.read_bytes()
    require(sha(archive)=='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8','Unsupported Hive archive')
    require(sha(blob)=='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba','Unsupported Hive texture')
    es={e['key']:e for e in parse_mix(archive)}
    geo,meta=[archive[es[k]['offset']:es[k]['offset']+es[k]['size']] for k in (3776990464,3776335874)]
    control=geo[u32(geo,0x18)+75*33:][:33];require(control[32]==6,'Conversation control differs')
    template=meta[u32(meta,12)+6*60:][:60];require(struct.unpack_from('<h',template,36)[0]==182,'Conversation resource differs')
    sec=texture_sections(blob);d=struct.unpack_from('<6H11I',blob,sec[2]+182*56);payload=blob[sec[3]+d[7]:][:d[12]]
    require(payload==bytes.fromhex('4301800290011600')+b'e070e.vqa'+bytes(5),'Movie reference differs')
    movies=(game/'DAT/L5_HCI.MIX').read_bytes()
    entries=[e for e in parse_mix(movies) if e['key']==ww_hash_v1('SPHERE1\\L5_HC\\E070E.VQA')]
    require(len(entries)==1,'Expected one conversation movie')
    entry=entries[0];b=movies[entry['offset']:entry['offset']+entry['size']]
    require(sha(b)=='9c1a1fa1bcaa6e305b7fbc69ad651dbff5611ddc3062665fe4a45421cc6408ee','Unsupported conversation movie')
    linf=next(data for _,tag,data in chunks(b,12) if tag==b'LINF')
    ranges=list(struct.iter_unpack('<HH',next(data for _,tag,data in chunks(linf) if tag==b'LIND')))
    require(ranges==[(0,241),(242,271),(272,629),(630,837),(838,912),(913,961)],'Movie section ranges differ')
    proof=dict(movie_sha256=sha(b),ranges=ranges)
    source=output/'tmp/hive_conversation/e070e.vqa';source.parent.mkdir(parents=True);source.write_bytes(b)
    top={t:d for _,t,d in chunks(b,12) if t in [b'VQHD',b'LINF',b'LNIN']}
    count,w,h=struct.unpack_from('<HHH',top[b'VQHD'],4);fps=top[b'VQHD'][12];assert (count,w,h,fps)==(962,376,448,15)
    names={t:d for _,t,d in chunks(top[b'LNIN'])};labels=[names['LNID'.encode()][o:].split(b'\0')[0].decode() for (o,) in struct.iter_unpack('<I',names[b'LNIO'])]
    out=output/'assets/lol2/generated/hive_conversation';out.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix='lol2_hive_frames_') as temporary:
     raw=Path(temporary)/'frames.rgba'
     subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-an','-vf','transpose=1,format=rgba','-f','rawvideo',str(raw)],check=True)
     assert raw.stat().st_size==count*w*h*4
     frames=np.memmap(raw,dtype=np.uint8,mode='r',shape=(count,w,h,4))
     bounds=[h,w,0,0]
     def keyed(i):
      a=np.array(frames[i]);mask=(a[:,:,0]>220)&(a[:,:,1]<35)&(a[:,:,2]>220);a[:,:,3]=np.where(mask,0,255)
      return Image.fromarray(a)
     for i in range(913): # Death section is not part of this conversation display.
      box=keyed(i).getbbox()
      if box:bounds=[min(bounds[0],box[0]),min(bounds[1],box[1]),max(bounds[2],box[2]),max(bounds[3],box[3])]
     assert bounds[2]>bounds[0] and bounds[3]>bounds[1]
     anchor=keyed(242).getbbox();anchor_x=(anchor[0]+anchor[2])/2
     tile_h=256;tile_w=round(tile_h*(bounds[2]-bounds[0])/(bounds[3]-bounds[1]))
     for page in range((count+99)//100):
      sheet=Image.new('RGBA',(tile_w*10,tile_h*10))
      for i in range(page*100,min(page*100+100,count)):
       im=keyed(i).crop(bounds).resize((tile_w,tile_h),Image.Resampling.NEAREST)
       sheet.paste(im,((i%10)*tile_w,((i%100)//10)*tile_h))
      sheet.save(out/f'page_{page}.png')
    sections=[]
    for i,((first,last),name) in enumerate(zip(proof['ranges'],labels)):
     audio=f'section_{i}.wav'
     subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vn','-af',f'atrim=start={first/fps}:end={(last+1)/fps},asetpts=PTS-STARTPTS','-ac','1','-c:a','pcm_s16le',str(out/audio)],check=True)
     sections.append(dict(first=first,last=last,name=name,audio=audio))
    report=dict(source_sha256=proof['movie_sha256'],frames=count,fps=fps,sections=sections,order=[0,2,3,4],position=[-1133,-235,-8885],size=[128*tile_w/tile_h,128],tile=[tile_w,tile_h],crop=bounds,center_offset_x=128*((bounds[0]+bounds[2])/2-anchor_x)/(bounds[3]-bounds[1]),pages=(count+99)//100,shared_flag=38,scope='Original named sections and source audio. Authored clockwise orientation correction, magenta key, shared crop,128-unit height, billboard and sequential section completion. Native rendering/full event dispatch not reproduced. Review only, no normal quest admission.')
    (out/'conversation.json').write_text(json.dumps(report,indent=2)+'\n');print('Staged',count,'frames;',labels,'crop',bounds)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['game','texture','output-root']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))

if __name__=='__main__':main()
