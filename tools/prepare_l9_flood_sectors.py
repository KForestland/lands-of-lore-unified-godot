#!/usr/bin/env python3
"""Pin the original descriptor spans used by opcode208's later flood stages."""
import argparse,hashlib,json,struct
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
from verify_actor_item_grants import parse_mix
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--output',type=Path,default=Path('tmp/l9_flood_sectors.json'));a=p.parse_args()
root=Path(__file__).resolve().parents[1];blob=(a.game/'DAT/L9_DR.MIX').read_bytes();assert hashlib.sha256(blob).hexdigest()=='700300d0cdf7df0af9471f3476c4e6ba473a603fa89e3a6e1855037d70be09c7'
entries=parse_mix(blob);entry=next(e for e in entries if e['key']==3511575868);raw=blob[entry['offset']:entry['offset']+entry['size']]
u=lambda k:struct.unpack_from('<I',raw,k)[0]
nav=json.loads((root/'assets/lol2/generated/creature_nav/L9_DR.json').read_text());assert nav['source_sha256']==hashlib.sha256(blob).hexdigest()
spans=[]
for anchor in [5958,6014]:
 region=raw[u(12)+anchor*44:u(12)+(anchor+1)*44];descriptor=int.from_bytes(region[24:26],'little');off=u(0xa4)+descriptor*26;d=raw[off:off+26];first=int.from_bytes(d[:2],'little');count=d[23]
 rows=[]
 for index in range(first,first+count):
  ro=u(12)+index*44;r=raw[ro:ro+44];v=nav['regions'][index]
  rows.append(dict(region=index,file_offset=entry['offset']+ro,raw_hex=r.hex(),polygon=v[0],floor=v[1:3],floor_base=int.from_bytes(r[20:22],'little',signed=True),ceiling_base=int.from_bytes(r[22:24],'little',signed=True)))
 spans.append(dict(anchor=anchor,descriptor=descriptor,file_offset=entry['offset']+off,raw_hex=d.hex(),first=first,count=count,regions=rows))
assert [(s['descriptor'],s['first'],s['count']) for s in spans]==[(501,5954,59),(502,6013,22)]
meta_entry=entries[0];meta=blob[meta_entry['offset']:meta_entry['offset']+meta_entry['size']];start=struct.unpack_from('<I',meta,4)[0];count=struct.unpack_from('<I',meta,60)[0];presets=[]
for index in [59,61]:
 off=start+index*24;name=meta[start+count*24+index*22:start+count*24+(index+1)*22].split(b'\0')[0].decode();presets.append(dict(index=index,name=name,file_offset=meta_entry['offset']+off,raw_hex=meta[off:off+24].hex()))
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(dict(version=1,source_sha256=hashlib.sha256(blob).hexdigest(),spans=spans,presets=presets,scope='Original descriptor first-word/count-byte23 allocation spans, selected by native opcode208 arm1. Source polygons and floor bounds from pinned navigation export. Not a clock, water physics, table motion or earned escape implementation.'),indent=1)+'\n')
print('PASS descriptor501 regions5954..6012, descriptor502 regions6013..6034;81 source regions, presets59/61')
