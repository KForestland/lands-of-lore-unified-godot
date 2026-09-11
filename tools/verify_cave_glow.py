#!/usr/bin/env python3
"""Check world-prop glow leaves source indices intact and toggles reproducibly."""
import argparse,json
from pathlib import Path
from PIL import Image
from verify_index_buffer_capture import decoded

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--record',type=int,default=1108);a=p.parse_args();project=Path(__file__).resolve().parents[1];root=project/f'captures/glow_{a.record}'
 def read(name):return Image.open(root/f'{name}.png').convert('RGB')
 glow=read('glow');plain=read('plain');indices=read('indices_glow');size=glow.size;palette=list(Image.open(project/'assets/lol2/generated/wall_indices/palette.png').convert('RGB').getdata())
 assert read('restored').tobytes()==glow.tobytes()
 assert read('indices_plain').tobytes()==indices.tobytes()==read('indices_restored').tobytes()
 base=[]
 for index,(_,_,marker) in zip(decoded(indices),indices.getdata()):
  rgb=palette[index]
  if marker>191:rgb=tuple(int(c*.65+.5) for c in rgb)
  elif marker>63:rgb=(217,38,140)
  base.append(rgb)
 errors={}
 for name in ['glow','plain']:
  image=read(name);light=read('light_'+name);assert image.size==light.size==size
  worst=0
  for rgb,mult,actual in zip(base,light.getdata(),image.getdata()):
   expected=tuple(min(255,int(c*m*2/255+.5)) for c,m in zip(rgb,mult))
   worst=max(worst,max(abs(x-y) for x,y in zip(expected,actual)))
  assert worst<=1;errors[name]=worst
 changed=sum(a!=b for a,b in zip(glow.getdata(),plain.getdata()));brighter=sum(a[1]>b[1] for a,b in zip(glow.getdata(),plain.getdata()));assert changed>0 and brighter>0
 report=dict(record=a.record,pixels=size[0]*size[1],changed_pixels=changed,greener_pixels=brighter,indices_unchanged=True,toggle_exact=True,max_channel_rounding_errors=errors)
 (root/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
