#!/usr/bin/env python3
"""Check indexed dummy visibility toggles are visible and reversible."""
import argparse,json
from pathlib import Path
from PIL import Image

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--checkpoint',type=int,default=14);a=p.parse_args();project=Path(__file__).resolve().parents[1];root=project/f'captures/dummies_{a.checkpoint}'
 def read(name):return Image.open(root/f'{name}.png').convert('RGB')
 shown,hidden,restored=[read(name) for name in ['shown','hidden','restored']];assert shown.size==hidden.size==restored.size
 assert shown.tobytes()==restored.tobytes()
 indices,hidden_indices,restored_indices=[read('indices_'+name) for name in ['shown','hidden','restored']];assert indices.tobytes()==restored_indices.tobytes()
 changed=sum(a!=b for a,b in zip(shown.getdata(),hidden.getdata()));changed_indices=sum(a!=b for a,b in zip(indices.getdata(),hidden_indices.getdata()));assert changed>0 and changed_indices>0
 report=dict(checkpoint=a.checkpoint,pixels=shown.width*shown.height,changed_rgb_pixels=changed,changed_index_pixels=changed_indices,restored_rgb_exact=True,restored_indices_exact=True)
 (root/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if __name__=='__main__':main()
