#!/usr/bin/env python3
"""Verify each recovered-placement compositor layer and final RGB capture."""
import argparse,json
from pathlib import Path
from PIL import Image
from verify_index_buffer_capture import decoded

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--record',type=int,choices=[1051,1057,1058],required=True);a=p.parse_args();project=Path(__file__).resolve().parents[1];root=project/f'captures/special_placed_{a.record}';assets=project/'assets/lol2/generated'
 def read(name):return Image.open(root/(name+'.png')).convert('RGB')
 metadata=json.loads((root/'placement_view.json').read_text());order=metadata['far_to_near_records'];assert set(order)=={1051,1057,1058}
 background=read('background');size=background.size;indices=decoded(background);markers=[v[2] for v in background.getdata()];remap=list(Image.open(assets/'special_prop_review/remap.png').convert('L').getdata());pal=list(Image.open(assets/'wall_indices/palette.png').convert('RGB').getdata());report=dict(record=a.record,layers=[],pixels_per_buffer=len(indices));total=0;selected_special=0
 for layer,record in enumerate(order):
  source=read(f'source{layer}');actual=read(f'composite{layer}');assert source.size==actual.size==size;src=decoded(source)
  for i,s in enumerate(src):
   if s>1:indices[i]=s;markers[i]=0
   elif s==1 and not 63<markers[i]<192:indices[i]=remap[indices[i]]
  errors=sum(x!=y for x,y in zip(decoded(actual),indices));marker_errors=sum(x[2]!=y for x,y in zip(actual.getdata(),markers));total+=errors+marker_errors
  report['layers'].append(dict(record=record,visible_pixels=sum(x!=0 for x in src),special_pixels=src.count(1),index_mismatches=errors,marker_mismatches=marker_errors))
  if record==a.record:selected_special=src.count(1)
 expected=[]
 for i,m in zip(indices,markers):
  rgb=pal[i]
  if m>191:rgb=tuple(int(c*.65+.5) for c in rgb)
  elif m>63:rgb=(217,38,140)
  expected.append(rgb)
 actual=read('resolved');assert actual.size==size;errors=sum(x!=y for x,y in zip(actual.getdata(),expected));report['rgb_mismatches']=errors;total+=errors
 (root/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));assert total==0 and selected_special>0
if __name__=='__main__':main()
