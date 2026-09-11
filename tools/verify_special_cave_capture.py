#!/usr/bin/env python3
"""Verify two sequential special-pixel composites over captured cave indices."""
import json,math
from pathlib import Path
from PIL import Image
from verify_index_buffer_capture import decoded


def main():
 p=Path(__file__).resolve().parents[1];root=p/'captures/special_cave';assets=p/'assets/lol2/generated'
 def read(name):return Image.open(root/(name+'.png')).convert('RGB')
 background=read('background');size=background.size;indices=decoded(background);markers=[v[2] for v in background.getdata()];remap=list(Image.open(assets/'special_cave_review/remap.png').convert('L').getdata());pal=list(Image.open(assets/'wall_indices/palette.png').convert('RGB').getdata());report={};sources=[]
 for layer in range(2):
  source=read(f'source{layer}');actual=read(f'composite{layer}');assert source.size==actual.size==size
  src=decoded(source);sources.append(src)
  for i,s in enumerate(src):
   if s>1:indices[i]=s;markers[i]=0
   elif s==1 and not 63<markers[i]<192:indices[i]=remap[indices[i]]
  report[f'layer{layer}_index_mismatches']=sum(a!=b for a,b in zip(decoded(actual),indices))
  report[f'layer{layer}_marker_mismatches']=sum(a[2]!=b for a,b in zip(actual.getdata(),markers))
  report[f'layer{layer}_special_pixels']=src.count(1)
 report['double_remap_pixels']=sum(a==b==1 for a,b in zip(*sources))
 # Analytical perspective projection for the fixed diagnostic camera (75deg
 # vertical FOV), with a one-pixel inset to exclude raster edge conventions.
 focal=size[1]/(2*math.tan(math.radians(75)/2))
 depth_checks=0;depth_errors=0;hidden_nonzero=0
 raw_sources=[decoded(read(f'raw{i}')) for i in range(2)]
 for distance,width,height,xcenter,layers in [(18,4,8,-5,[0,1]),(30,4,10,5,[0])]:
  x0=math.ceil(size[0]/2+(xcenter-width/2)*focal/distance)+1
  x1=math.floor(size[0]/2+(xcenter+width/2)*focal/distance)-1
  y0=math.ceil(size[1]/2-height/2*focal/distance)+1
  y1=math.floor(size[1]/2+height/2*focal/distance)-1
  for y in range(y0,y1):
   for x in range(x0,x1):
    pos=y*size[0]+x
    for layer in layers:
     depth_checks+=1;depth_errors+=sources[layer][pos]!=0;hidden_nonzero+=raw_sources[layer][pos]!=0
    if distance==30:
     depth_checks+=1;depth_errors+=sources[1][pos]!=raw_sources[1][pos]
 report['depth_samples']=depth_checks;report['depth_mismatches']=depth_errors;report['occluded_nonzero_samples']=hidden_nonzero
 assert hidden_nonzero>0
 report['ordinary_overlap_pixels']=sum(a>1 and b>1 for a,b in zip(*sources))
 expected=[]
 for i,m in zip(indices,markers):
  rgb=pal[i]
  if m>191:rgb=tuple(int(c*.65+.5) for c in rgb)
  elif m>63:rgb=(217,38,140)
  expected.append(rgb)
 actual=read('resolved');assert actual.size==size
 report['resolved_rgb_mismatches']=sum(a!=b for a,b in zip(actual.getdata(),expected));report['pixels_per_buffer']=len(indices)
 print(json.dumps(report));(root/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
 assert not any(v for k,v in report.items() if 'mismatches' in k)
 assert report['double_remap_pixels']>0 and report['ordinary_overlap_pixels']>0
if __name__=='__main__':main()
