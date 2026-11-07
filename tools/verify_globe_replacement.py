#!/usr/bin/env python3
"""Pin colored-globe dictionary entry and replay its definition mapping/lookup."""
import argparse, hashlib, json, struct
from pathlib import Path
import re_helper_root
re_helper_root.insert('draracle')
import capstone
from verify_creature_states import CreatureReplay
from verify_special_pixel_table_binding import fixups
from verify_actor_item_grants import parse_mix
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--game', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a=p.parse_args()
b=(a.game/'LOLG.DAT').read_bytes()
assert hashlib.sha256(b).hexdigest()=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
u32=lambda data, off:struct.unpack_from('<I',data,off)[0]
le=0x39024+u32(b,0x39060); objects=le+u32(b,le+0x40); first=u32(b,objects+108)
data_start=0x39024+u32(b,le+0x80)+(first-1)*4096
names=[];relocations=[]
def name_hash(raw):
    h=0
    for off in range(0,len(raw),4):
        h=(((h<<1)|(h>>31))+int.from_bytes(raw[off:off+4],'little'))&0xffffffff
    return h
for index in range(74):
    slot=0xc610+index*8
    fix=fixups(b,le,first-1+slot//4096)[slot%4096]
    assert fix['target_object']==5
    start=data_start+fix['target_offset']; raw=b[start:b.index(b'\0',start)]
    names.append(dict(index=index,name=raw.decode(),identity=name_hash(raw)))
    relocations.append(fix)
assert names[37]==dict(index=37,name='96-E Globe',identity=0xf38dcc87)
archive=(a.game/'DAT/GLOBAL.MIX').read_bytes()
entry=next(e for e in parse_mix(archive) if e['key']==3984507021)
global_data=archive[entry['offset']:entry['offset']+entry['size']]
assert hashlib.sha256(global_data).hexdigest()=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
base,count=u32(global_data,4),u32(global_data,0x34)
records=global_data[base:base+count*91]
assert u32(records,98*91+24)==names[37]['identity']
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_32);md.detail=True
spans=[]
def machine(start,end):
    raw=b[start+0x37000:end+0x37000]
    spans.append(dict(start=hex(start),end=hex(end),sha256=hashlib.sha256(raw).hexdigest()))
    return CreatureReplay({i.address:i for i in md.disasm(raw,start)},b'')
# Native item iterator callback: returns identity and advances the definition cursor.
fix=fixups(b,le,first-1+0x584c//4096)[0x584c%4096]
assert fix['target_object']==2 and fix['target_offset']+0x59024==0x62694
m=machine(0x62694,0x626b2); m.regs['esp']=0x700000
for addr,value in [(0x700008,0x300000),(0x70000c,0x300004),(0x300000,0x400000+98*91),(0x300004,98)]:m.writemem(addr,4,value)
m.mem[0x400000:0x400000+len(records)]=records
m.execute(0x62694,0x626b1)
assert m.regs['eax']==0xf38dcc87 and m.readmem(0x300004,4)==99
assert m.readmem(0x300000,4)==0x400000+99*91
# Replay constructor binary-search/store after hash sorting and iterator callback.
# The supplied sorted table models 154880/hash and sorting; those are not replayed.
sorted_names=sorted(names,key=lambda row:row['identity'])
m=machine(0x6255f,0x625ee); m.regs['esp']=0x700000;m.regs['eax']=0xf38dcc87
for addr,value in [(0x700010,37),(0x700018,0x310000),(0x70001c,73),(0x700034,0x320000),(0x700008,98),(0x700048,0),(0x320000,0x330000)]:m.writemem(addr,4,value)
for i,row in enumerate(sorted_names):
    m.writemem(0x310000+8*i,4,row['identity']);m.writemem(0x310004+8*i,4,row['index'])
m.execute(0x6255f,0x625ee)
assert m.readmem(0x330000+37*8+4,4)==98
# Full call-free definition lookup on actual original records, including a miss.
m=machine(0x9eb5c,0x9eb81)
for identity,expected in [(0xf38dcc87,0x400000+98*91),(0xffffffff,0)]:
    m.regs['esp']=0x700000
    for addr,value in [(0x700004,0x300000),(0x700008,identity),(0x30001c,0x400000),(0x300020,count)]:m.writemem(addr,4,value)
    m.mem[0x400000:0x400000+len(records)]=records
    m.execute(0x9eb5c,0x9eb80);assert m.regs['eax']==expected
result=dict(executable_sha256=hashlib.sha256(b).hexdigest(),global_sha256=hashlib.sha256(global_data).hexdigest(),entry=names[37],replacement_definition=98,entry_relocation=relocations[37],iterator_relocation=fix,code=spans,scope='74 static names hashed with a transcription of154880; native iterator, constructor search/store suffix and full9EB5C lookup replayed. Hash/sort/initializer prefix and77ACC UI effects not replayed. Establishes empty-definition replacement mapping; no campaign inventory mutation, effect damage or runtime hosting claim.')
a.out.write_text(json.dumps(result,indent=2)+'\n')
print('PASS globe dictionary37 -> empty definition98; native iterator/search-store/lookup, including miss')
