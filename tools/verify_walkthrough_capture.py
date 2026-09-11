#!/usr/bin/env python3
"""Verify live camera order, resize and toggles across four walkthrough captures."""
import json
from pathlib import Path
from PIL import Image
from verify_index_buffer_capture import decoded


def main():
 p=Path(__file__).resolve().parents[1];assets=p/'assets/lol2/generated';root=p/'captures/walkthrough';remap=list(Image.open(assets/'special_prop_review/remap.png').convert('L').getdata());pal=list(Image.open(assets/'wall_indices/palette.png').convert('RGB').getdata());reports=[];orders=set();sizes=set()
 for pose in range(4):
  folder=root/f'pose{pose}'
  def read(name):return Image.open(folder/(name+'.png')).convert('RGB')
  meta=json.loads((folder/'view.json').read_text());assert meta['cameras_synchronized'];orders.add(tuple(meta['order']));background=read('background');size=background.size;sizes.add(size);indices=decoded(background);markers=[v[2] for v in background.getdata()];errors=0;visible=0;special=0
  for layer in range(3):
   source=read(f'source{layer}');actual=read(f'composite{layer}');assert source.size==actual.size==size;src=decoded(source);visible+=sum(v>0 for v in src);special+=src.count(1)
   for i,s in enumerate(src):
    if s>1:indices[i]=s;markers[i]=0
    elif s==1 and not 63<markers[i]<192:indices[i]=remap[indices[i]]
   errors+=sum(a!=b for a,b in zip(decoded(actual),indices))+sum(a[2]!=b for a,b in zip(actual.getdata(),markers))
  expected=[]
  for i,m in zip(indices,markers):
   rgb=pal[i]
   if m>191:rgb=tuple(int(c*.65+.5) for c in rgb)
   elif m>63:rgb=(217,38,140)
   expected.append(rgb)
  actual=read('resolved');assert actual.size==size;errors+=sum(a!=b for a,b in zip(actual.getdata(),expected))
  assert errors==0
  if not meta['props_visible']:assert visible==0
  if not meta['roof_visible']:assert all(v[2]<192 for v in background.getdata())
  if pose==0:assert special>0
  reports.append(dict(pose=pose,size=size,pixels=len(indices),special_pixels=special,mismatches=errors,**meta))
 assert len(orders)>1 and sizes=={(960,540),(800,450)}
 (root/'verification.json').write_text(json.dumps(reports,indent=2)+'\n');print(json.dumps([{'pose':r['pose'],'size':r['size'],'mismatches':r['mismatches'],'special_pixels':r['special_pixels']} for r in reports]))
if __name__=='__main__':main()
