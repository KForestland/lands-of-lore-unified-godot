#!/usr/bin/env python3
"""Prepare original Jungle dialogue media with explicit input and output paths."""
import argparse,hashlib,json,struct,subprocess,tempfile,wave
from pathlib import Path
import numpy as np
from PIL import Image
from prepare_museum_hourglass_media import chunks
from lol2_source_format import parse_mix,u32
from lol2_material_format import sections as texture_sections
from lol2_movie_format import ww_hash_v1

def prepare(game,texture,output):
    if output.exists():raise ValueError('Output must be fresh')
    for source in (game,texture):
        if output==source or output in source.parents or source in output.parents:
            raise ValueError('Output overlaps an input')
    level=(game/'DAT/L4_HJ.MIX').read_bytes()
    assert hashlib.sha256(level).hexdigest()=='517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'
    entries=parse_mix(level)
    geo,meta=[level[e['offset']:][:e['size']] for e in [next(e for e in entries if e['key']==key) for key in [3710797084,3710142494]]]
    control=geo[u32(geo,0x18)+85*33:][:33]
    assert struct.unpack_from('<hhHh',control)==(-1883,4501,49152,0) and control[32]==70
    template=meta[u32(meta,12)+70*60:][:60]
    assert struct.unpack_from('<h',template,36)[0]==493
    blob=texture.read_bytes()
    assert hashlib.sha256(blob).hexdigest()=='98c97fabb6fa8db7ca78a7c3626106ec850a6d5e37952292e15f32cb966a227b'
    sec=texture_sections(blob);descriptor=struct.unpack_from('<6H11I',blob,sec[2]+493*56)
    payload=blob[sec[3]+descriptor[7]:][:descriptor[12]]
    assert payload==bytes.fromhex('430180029001160065303737652e7671610000000000')
    archive=(game/'DAT/L4_HJI.MIX').read_bytes()
    entry=next(e for e in parse_mix(archive) if e['key']==ww_hash_v1('SPHERE1\\L4_HJ\\E077E.VQA'))
    b=archive[entry['offset']:][:entry['size']]
    assert hashlib.sha256(b).hexdigest()=='e30b930514ba55d35ded192c54d450b9e9e68d281bf1009d8daa5027af6823d8'
    source=output/'tmp/village_followup.vqa'
    source.parent.mkdir(parents=True,exist_ok=True);source.write_bytes(b)
    proof={'movie_sha256':hashlib.sha256(b).hexdigest(),'ranges':[(0,500),(501,540),(541,605)]}
    top={t:d for _,t,d in chunks(b,12) if t in [b'VQHD',b'LINF',b'LNIN']}
    count,w,h=struct.unpack_from('<HHH',top[b'VQHD'],4);fps=top[b'VQHD'][12];assert (count,w,h,fps)==(606,400,544,15)
    ranges=list(struct.iter_unpack('<HH',next(d for _,t,d in chunks(top[b'LINF']) if t==b'LIND')))
    assert ranges==proof['ranges']
    names={t:d for _,t,d in chunks(top[b'LNIN'])};labels=[names['LNID'.encode()][o:].split(b'\0')[0].decode() for (o,) in struct.iter_unpack('<I',names[b'LNIO'])]
    out=output/'assets/lol2/generated/jungle_followup_dialogue';out.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='lol2_village_frames_') as temporary:
     raw=Path(temporary)/'frames.rgba'
     # Partial-codebook VQA v2 uses the Python decoder (FFmpeg mis-decodes some codebook groups; see tools/vqa_v2_decode.py).
     from vqa_v2_decode import rgba_raw
     if not rgba_raw(source,raw,transpose_cw=True): subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-an','-vf','transpose=1,format=rgba','-f','rawvideo',str(raw)],check=True)
     assert raw.stat().st_size==count*w*h*4
     frames=np.memmap(raw,dtype=np.uint8,mode='r',shape=(count,w,h,4))
     bounds=[h,w,0,0]
     def keyed(i):
      a=np.array(frames[i]);mask=(a[:,:,0]<35)&(a[:,:,1]>220)&(a[:,:,2]>220);a[:,:,3]=np.where(mask,0,255)
      return Image.fromarray(a)
     for i in range(541): # Death section is not part of this conversation display.
      box=keyed(i).getbbox()
      if box:bounds=[min(bounds[0],box[0]),min(bounds[1],box[1]),max(bounds[2],box[2]),max(bounds[3],box[3])]
     assert bounds[2]>bounds[0] and bounds[3]>bounds[1]
     anchor=keyed(501).getbbox();anchor_x=(anchor[0]+anchor[2])/2
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
     with wave.open(str(out/audio)) as wav:
      assert abs(wav.getnframes()/wav.getframerate()-(last-first+1)/fps)<0.01
     sections.append(dict(first=first,last=last,name=name,audio=audio))
    report=dict(source_sha256=proof['movie_sha256'],frames=count,fps=fps,sections=sections,order=[0],position=[-1883,0,-4501],size=[64*tile_w/tile_h,64],tile=[tile_w,tile_h],crop=bounds,center_offset_x=64*((bounds[0]+bounds[2])/2-anchor_x)/(bounds[3]-bounds[1]),pages=(count+99)//100,completion_local=None,scope='Control85 E077E original speech, loiter and death sections. Modern clockwise orientation correction, cyan key, shared crop,64-unit height and billboard. Group6380 section0; completion group19638 closes movable70. Native rendering not reproduced.')
    assert labels==['HTalk000HU125-133','HLoit000HUVillager','HDdie000HUVillager']
    report['control_hex']=control.hex()
    report['resource_hex']=payload.hex()
    (out/'conversation.json').write_text(json.dumps(report,indent=2)+'\n');print('Staged',count,'frames;',labels,'crop',bounds)
    
    (output/'docs').mkdir(exist_ok=True)
    (output/"docs/jungle-followup-dialogue-source.json").write_text(json.dumps(report,indent=2)+"\n")

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('game','texture','output-root'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    try:prepare(a.game.resolve(),a.texture.resolve(),a.output_root.resolve())
    except (ValueError,OSError,AssertionError,KeyError,IndexError,struct.error) as error:p.error(str(error) or 'Source validation failed')
if __name__=='__main__':main()
