#!/usr/bin/env python3
"""Verify lighting toggles preserve indices and the reference palette resolve."""
import argparse,json
from pathlib import Path
from PIL import Image
from verify_index_buffer_capture import decoded

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--checkpoint',type=int,default=14);a=p.parse_args();project=Path(__file__).resolve().parents[1];root=project/f'captures/lighting_{a.checkpoint}'
 def read(name):return Image.open(root/f'{name}.png').convert('RGB')
 reference=read('reference');enhanced=read('enhanced');restored=read('restored');light=read('light');packed=read('final_indices_reference');size=reference.size
 assert all(im.size==size for im in [enhanced,restored,light,packed])
 for prefix in ['indices_', 'final_indices_']:
  original=read(prefix+'reference').tobytes()
  assert read(prefix+'enhanced').tobytes()==original==read(prefix+'restored').tobytes()
 assert restored.tobytes()==enhanced.tobytes()
 palette=list(Image.open(project/'assets/lol2/generated/wall_indices/palette.png').convert('RGB').getdata());expected=[]
 for index,(_,_,marker) in zip(decoded(packed),packed.getdata()):
  rgb=palette[index]
  if marker>191:rgb=tuple(int(c*.65+.5) for c in rgb)
  elif marker>63:rgb=(217,38,140)
  expected.append(rgb)
 reference_errors=sum(x!=y for x,y in zip(reference.getdata(),expected));assert reference_errors==0
 changed=0;max_error=0;rounding_pixels=0
 for original,factor,actual in zip(reference.getdata(),light.getdata(),enhanced.getdata()):
  cpu=tuple(min(255,int(c*m*2/255+.5)) for c,m in zip(original,factor));error=max(abs(x-y) for x,y in zip(cpu,actual));max_error=max(max_error,error);rounding_pixels+=error>0;changed+=original!=actual
 assert changed>0 and max_error<=1
 report=dict(checkpoint=a.checkpoint,pixels=size[0]*size[1],changed_pixels=changed,reference_rgb_mismatches=reference_errors,index_buffers_unchanged=True,toggle_restoration_exact=True,enhanced_max_channel_rounding_error=max_error,enhanced_rounding_pixels=rounding_pixels)
 (root/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
