#!/usr/bin/env python3
"""Prepare animated Cave floor index frames (lava, tar, water) from explicit fresh inputs."""
import argparse,hashlib,json,struct
from pathlib import Path
from PIL import Image
from lol2_material_format import sections,column_major_to_rows
HASH='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
# Base descriptor -> role. Lava is the user-confirmed lethal material135 (docs/cave-lava.md);
# 156/161 are the bubbling tar pools and 285 the water, already drawn from their first frame.
GROUPS={135:'lava',156:'tar',161:'tar_pool',285:'water'}
# Adapter playback rates: native floor phases advance through timed per-region records (0x67460 steps a
# group member, 0xB8AC4 draws its delay); the Cave records are not yet traced, so these rates are modern.
ADAPTER_FPS={'lava':8.0,'tar':5.0,'tar_pool':5.0,'water':8.0}
def sha(data):return hashlib.sha256(data).hexdigest()
def require(ok,message):
 if not ok:raise ValueError(message)
def prepare(texture,floor_root,surface_root,lava_root,review,output):
 require(not output.exists(),'Output must be fresh')
 for source in (texture,floor_root,surface_root,lava_root,review):require(output!=source and output not in source.parents and source not in output.parents,'Output overlaps input')
 blob=texture.read_bytes();require(sha(blob)==HASH,'Unsupported Cave texture');s=sections(blob)
 floors=json.loads((floor_root/'floors.json').read_text());lava=json.loads((lava_root/'regions.json').read_text())
 require(int(lava['material'])==135 and len(lava['regions'])==86,'Lava region selection differs')
 faces=json.loads(review.read_text())['faces']
 by_region={}
 for face in faces:
  if face['kind']=='floor':by_region.setdefault(face['region'],[]).append(face)
 # UV convention check: every textured floor in the runtime pack is the review UV with axes swapped.
 checked=0
 for face in floors['faces']:
  if face['material']=='unresolved':continue
  sources=by_region.get(face['region'],[]);require(bool(sources),f'Review lacks floor region {face["region"]}')
  require(any([[b,a] for a,b in source['uv']]==face['uv'] for source in sources),f'UV convention differs at region {face["region"]}');checked+=1
 lava_uv={}
 for region in lava['regions']:
  sources=[f for f in by_region.get(region['region'],[]) if f.get('visibility_original_material',f.get('material'))=='135'];require(len(sources)==1,'Lava region is not one material135 floor');source=sources[0]
  require(any(f['region']==region['region'] and f['material']=='unresolved' for f in floors['faces']),'Lava region is not an unresolved runtime floor')
  lava_uv[str(region['region'])]=[[b,a] for a,b in source['uv']]
 out=output/'assets/lol2/generated/cave_animated_floors';out.mkdir(parents=True);rows=[]
 layout=None
 for base in sorted(GROUPS,key=lambda k:(k==135,k)):
  head=struct.unpack_from('<6H11I',blob,s[2]+base*56);count=head[4]&255;require(head[4]>>8==0 and 2<=count<=16,f'Descriptor {base} is not a phase-0 group base')
  frames=[]
  for phase in range(count):
   k=base+phase;v=struct.unpack_from('<6H11I',blob,s[2]+k*56);w,h=v[1:3]
   require(v[4]==(phase<<8)|count,f'Descriptor {k} is not phase {phase} of group {base}')
   start=s[3]+v[7];payload=blob[start:start+v[12]]
   require(len(payload)==8+w*h and struct.unpack_from('<4H',payload)==(v[3],w,h,w*h&65535),f'Unsupported floor payload {k}')
   raw=payload[8:]
   if base!=135 and phase==0:
    # The runtime first frame selects the layout; it must reproduce the shipped index image exactly.
    ref=Image.open(surface_root/f'floor_{base}.png');require(ref.mode=='L' and ref.size==(w,h),f'Reference floor_{base} differs')
    hits=[name for name,buf in (('raw',raw),('columns',column_major_to_rows(raw,w,h))) if buf==ref.tobytes()]
    require(len(hits)>=1,f'No layout reproduces floor_{base}');require(layout in (None,hits[0]),'Layouts disagree between groups');layout=hits[0]
   require(layout is not None,'Layout must be fixed by a shipped floor first')
   indices=raw if layout=='raw' else column_major_to_rows(raw,w,h)
   name=f'floor_{base}_frame_{phase}.png';Image.frombytes('L',(w,h),indices).save(out/name);frames.append(dict(descriptor=k,path=name,width=w,height=h,indices_sha256=sha(indices)))
  rows.append(dict(material=str(base),role=GROUPS[base],frames=frames,fps=ADAPTER_FPS[GROUPS[base]]))
 manifest=dict(cache_sha256=HASH,layout=layout,uv_convention_checked_floors=checked,materials=rows,lava_uv=lava_uv,
  scope='Original phase-group members (word8 low byte count, high byte phase) decoded from their first mip; base frame layout reproduces the shipped floor index images. Lava UVs are the recovered material135 review UVs with the axis swap verified on every textured floor. Playback rate is a modern adapter; the native phase clock is unverified.')
 (out/'manifest.json').write_text(json.dumps(manifest,indent=1)+'\n')
 print('Exported',sum(len(r['frames']) for r in rows),'frames in',len(rows),'groups;',len(lava_uv),'lava UV sets; UV convention checked on',checked,'floors')
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('texture','floors','surface','lava','review','output-root'):p.add_argument('--'+name,type=Path,required=True)
 a=p.parse_args()
 try:prepare(a.texture.resolve(),a.floors.resolve(),a.surface.resolve(),a.lava.resolve(),a.review.resolve(),a.output_root.resolve())
 except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
if __name__=='__main__':main()
