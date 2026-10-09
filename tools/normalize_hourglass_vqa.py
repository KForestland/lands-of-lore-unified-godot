#!/usr/bin/env python3
"""Normalize hourglass checkpoints and native solid vectors for FFmpeg."""
import hashlib,json,struct,sys
from pathlib import Path
sys.path.insert(0,'/home/bob/lol2_re_publish_20260911/tools/draracle')
from extract_block_sprite_frames import lcw
SOURCE_SHA='f7d8ee9632870b9b8fd8e82f4ebb78868c531630908dc704d3ef947b5bd5738a'
def chunks(data,start=0):
 result=[];pos=start
 while pos<len(data):
  assert pos+8<=len(data)
  tag=data[pos:pos+4];size=struct.unpack_from('>I',data,pos+4)[0]
  end=pos+8+size
  assert end+(size&1)<=len(data)
  result.append([pos,tag,data[pos+8:end]])
  pos=end+(size&1)
 assert pos==len(data)
 return result
def pack(tag,payload):
 return tag+struct.pack('>I',len(payload))+payload+(b'\0' if len(payload)&1 else b'')
def literal_lcw(data):
 result=b''.join(bytes([0x80+len(data[i:i+63])])+data[i:i+63] for i in range(0,len(data),63))+b'\x80'
 assert lcw(result)==data
 return result
def normalize(source,target):
 raw=source.read_bytes();assert hashlib.sha256(raw).hexdigest()==SOURCE_SHA
 assert raw[:4]==b'FORM' and raw[8:12]==b'WVQA' and struct.unpack_from('>I',raw,4)[0]+8==len(raw)
 top=chunks(raw,12);frames=[];parts=[];checks=[];codebook=None
 header=next(payload for _,tag,payload in top if tag==b'VQHD');expected=struct.unpack_from('<H',header,4)[0]
 assert expected==300 and header[13]==8
 for ti,(_,tag,payload) in enumerate(top):
  if tag==b'VQFL':
   checkpoint=chunks(payload)
   assert lcw(checkpoint[0][2])==codebook
   assert [d for _,t,d in checkpoint[1:] if t==b'CBPZ']==parts
   continue
  if tag!=b'VQFR':continue
  sub=chunks(payload);rebuilt=[];next_codebook=None
  for _,tag,data in sub:
   if tag==b'CBFZ':codebook=lcw(data)
   elif tag==b'CBPZ':
    parts.append(data)
    if len(parts)==8:
     next_codebook=lcw(b''.join(parts));parts=[]
   elif tag==b'VPTZ':
    expanded=bytearray(lcw(data));assert len(expanded)==16000
    # Native17CF46/17CF74: FF high byte fills4x2 pixels with low byte.
    # FFmpeg initializes equivalent constant-color vectors at0F00..0FFF.
    for i in range(8000):
     if expanded[8000+i]==255:expanded[8000+i]=15
    expanded=bytes(expanded)
    rebuilt.append((b'VPTZ',literal_lcw(expanded)))
    checks.append(dict(frame=len(frames),tag='VPTZ',decoded_sha256=hashlib.sha256(expanded).hexdigest()))
   else:rebuilt.append((tag,data))
  assert codebook is not None and len(codebook)%8==0
  rebuilt.insert(0,(b'CBF0',codebook))
  checks.append(dict(frame=len(frames),tag='active_codebook',decoded_sha256=hashlib.sha256(codebook).hexdigest()))
  top[ti][2]=b''.join(pack(tag,data) for tag,data in rebuilt)
  frames.append(ti)
  if next_codebook is not None:codebook=next_codebook
 assert len(frames)==expected and not parts
 offsets={};pos=12
 for old,tag,payload in top:
  offsets[old]=pos
  if tag!=b'VQFL':pos+=8+len(payload)+(len(payload)&1)
 for _,tag,payload in top:
  if tag==b'FINF':
   assert len(payload)==4*expected
   rebuilt=[]
   for (index,) in struct.iter_unpack('<I',payload):
    old=(index&0x0fffffff)*2
    assert old in offsets and offsets[old]%2==0
    rebuilt.append((index&0xf0000000)|(offsets[old]//2))
   for record in top:
    if record[1]==b'FINF':record[2]=struct.pack('<%dI'%expected,*rebuilt)
 body=b'WVQA'+b''.join(pack(tag,payload) for _,tag,payload in top if tag!=b'VQFL')
 target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(b'FORM'+struct.pack('>I',len(body))+body)
 target.with_suffix('.json').write_text(json.dumps(dict(source_sha256=SOURCE_SHA,output_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),frames=expected,expansion_checks=checks,scope='LCW payloads expanded with strict local decoder; literal-only LCW equivalents and FINF offsets rebuilt. Audio/other payloads preserved except verified redundant VQFL checkpoints omitted. Native FF high-byte solid vectors mapped to FFmpeg constant vectors; sequential codebooks materialized per frame. Independent indexed pixel verification required. Export palette channels as masked6-bit values expanded to8bit; independent palette comparison required.'),indent=2)+'\n')
 print('Expanded',len(checks),'compressed payloads/codebooks across',expected,'frames')
if __name__=='__main__':normalize(Path(sys.argv[1]),Path(sys.argv[2]))
