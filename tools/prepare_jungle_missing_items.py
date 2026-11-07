#!/usr/bin/env python3
"""Decode missing Jungle pickup candidates into a fresh output directory.

Positions use independently replayed original item settling, pinned by receipt hash.
This stages candidates, not proof of reachability or original populated-support physics.
Existing pickup owners and elevated rows51..67 are deliberately preserved.
"""
import argparse, hashlib, json, struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix, u32
from lol2_material_format import sections, rgb_palette
from lol2_creature_sprite_format import decode_rows

SETTLING_SHA256 = "45020d8a5e48fe4068a544b20f528b1d2ed1dbf1a27cd790ece157bdff53bf7b"

EXISTING = {0, 41, 42, 50, 51, *range(52, 58), *range(63, 73)}
HELD = set(range(51, 68)) - EXISTING

def digest(raw): return hashlib.sha256(raw).hexdigest()
def entry(raw, key, expected):
    matches = [r for r in parse_mix(raw) if r['key'] == key]
    if len(matches) != 1: raise ValueError('Expected unique archive entry')
    r = matches[0]; data = raw[r['offset']:r['offset'] + r['size']]
    if digest(data) != expected: raise ValueError('Unsupported original entry')
    return data

def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ['game', 'settling', 'output']: p.add_argument('--'+key, type=Path, required=True)
    p.add_argument('--settling-sha256', default=SETTLING_SHA256)
    a = p.parse_args()
    if a.output.exists(): p.error('Output must be a fresh directory')
    raw = a.settling.read_bytes()
    if a.settling_sha256 != SETTLING_SHA256 or digest(raw) != SETTLING_SHA256:
        p.error('Unsupported settling receipt; source review required before changing the pinned contract')
    settled = {int(r['row']): r for r in json.loads(raw)['rows']}
    if set(settled) != set(range(88)): p.error('Expected all88 settling rows')
    level = entry((a.game/'DAT/L4_HJ.MIX').read_bytes(),3710797084,'445d9b270d3e62574d719851305e3e30867715993f073a2dcd0e888295172aba')
    defs = entry((a.game/'GLOBAL.MIX').read_bytes(),3984507021,'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891')
    graphics = entry((a.game/'LOCAL.MIX').read_bytes(),4018716831,'36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93')
    assert u32(level,0x6c)==88
    base,count=u32(defs,4),u32(defs,0x34)
    state=base+count*91+4; view=state+u32(defs,state-4)*16+4; names=view+u32(defs,view-4)*12
    first={}; si=vi=0; identities={}
    for index in range(count):
        record=defs[base+index*91:][:91];identities[u32(record,24)]=index
        for selector in range(record[46]+record[47]):
            if selector==0:first[index]=struct.unpack_from('<h',defs,view+vi*12)[0]
            vi+=max(1,struct.unpack_from('<b',defs,state+si*16+13)[0]);si+=1
    sec=sections(graphics);palette=rgb_palette(graphics[u32(graphics,4):][:768],6)
    out=a.output/'assets/lol2/generated/jungle_missing_items';out.mkdir(parents=True)
    items=[]
    for r in sorted(set(range(88))-EXISTING-HELD):
        row=level[u32(level,0x20)+r*37:][:37]
        x,y,_,z=struct.unpack_from('<hhHh',row);flags,region=struct.unpack_from('<HH',row,8);identity=u32(row,32)
        receipt=settled[r];pos=receipt['port_settled_position']
        assert receipt['exit_code']==0 and receipt['last16_heights_stable'] and receipt['identity']==identity and receipt['region']==region
        assert receipt['raw_height']==z and pos[0]==x and pos[2]==-y and flags in (2,1026), (r, flags, receipt["raw_height"], z)
        index=identities[identity];name=defs[names+index*30:names+index*30+24].split(b'\0')[0].decode().strip()
        resource=first[index];desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
        width,height,pixels,_=decode_rows(graphics[sec[3]+desc[7]:][:desc[12]],allow_special=True)
        assert (width,height)==desc[1:3]
        rgba=bytes(c for px in pixels for c in (*palette[px*3:px*3+3],0 if px in (0,1) else 255))
        stem=name.split('-',1)[-1].replace(' ','_');filename=f'item{r}_{stem.lower()}.png'
        Image.frombytes('RGBA',(width,height),rgba).save(out/filename)
        items.append(dict(row=r,id=f'jungle:item{r}:{stem}',name=name,label=name.split('-',1)[-1],position=pos,native_position=[x,y,z],flags=flags,region=region,identity=identity,definition=index,resource=resource,size=[width,height],icon='res://assets/lol2/generated/jungle_missing_items/'+filename,placement_hex=row.hex(),pixels_sha256=digest(pixels)))
    manifest=dict(version=1,items=items,held_missing_rows=sorted(HELD),existing_rows=sorted(EXISTING),settling_sha256=digest(raw),scope='Private candidates; original isolated settling and port support agree. Earned reach, renderer, populated native supports and item effects are separate gates.')
    (out/'items.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS staged',len(items),'missing Jungle candidates; held',sorted(HELD))

if __name__=='__main__':main()
