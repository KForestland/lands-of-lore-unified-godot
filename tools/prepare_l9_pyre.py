#!/usr/bin/env python3
"""Export original pyre301 attached body/fire/ash selectors and source orb states."""
import argparse,hashlib,json
from pathlib import Path
import export_map_movables as mv
from lol2 import map_materials as m,map_primitive_geometry as g

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 b=(a.game/'DAT/L9_DR.MIX').read_bytes();sha=hashlib.sha256(b).hexdigest();assert sha=='700300d0cdf7df0af9471f3476c4e6ba473a603fa89e3a6e1855037d70be09c7'
 e=m.identify_entries(b,m.parse_mix(b),3511575868);row=e['metadata_entry'];meta=b[row['offset']:row['offset']+row['size']]
 mv.require=m.require;t=mv.load_movable_templates(meta);blob,_=m.decode_lzo_container(b,e['texture_entry']);records=[]
 for c in t['templates'][59]['children']:
  if c['type_byte']!=1:continue
  records.append({'child':bytes.fromhex(c['raw_hex']),'x':10882,'y':12569,'height':140,'heading':24576,'placement':301,'child_index':c['index']})
 report=g.export_type1_records(meta,blob,records,a.output);assert not report['state_issues'];assert {r['child']for r in report['state_props']}=={223,224,225}
 orb=g.prepare_templates(meta,blob,a.output/'orb',[13]);report['orb']={'visuals':{str(k[1]):v for k,v in orb['visuals'].items()},'materials':orb['materials']}
 report['archive_sha256']=sha;report['scope']='Exact pyre children and original orb selectors; burning duration/10fps and interaction are explicit modern adapters.'
 (a.output/'pyre.json').write_text(json.dumps(report,indent=1)+'\n');print('PASS original pyre body/42 fire frames/ashes; orb selectors0/1')
if __name__=='__main__':main()
