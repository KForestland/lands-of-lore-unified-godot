#!/usr/bin/env python3
"""Stage the exact original opcode21 movie54, WRM_STAT; no inferred worm actor."""
import argparse,json,sys,tempfile
from pathlib import Path
import monastery_media
from lol2.map_video_inventory import lookup_movie
import re_helper_root
re_helper_root.insert('tools')

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 from convert_cave_video_review import convert
 row=lookup_movie(a.game,'L9_DR','WRM_STAT.VQA')
 assert row['status']=='exact' and row['sha256']=='ea4c309d35ff22c1b0569b5392e53d1efea0c52777d0cad39559b9e6a214e30c'
 payload=row.pop('blob');assert row['vqhd']['count']==2224
 a.output.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='lol2-wrm-stat-')as temp:
  source=Path(temp)/'wrm_stat.vqa';source.write_bytes(payload);convert(source,a.output/'fight.ogv')
 row['scope']='Source opcode21 index54, exact original movie; modern encounter trigger/timing, no live native callback replay.'
 (a.output/'source.json').write_text(json.dumps(row,indent=1)+'\n')
if __name__=='__main__':main()
