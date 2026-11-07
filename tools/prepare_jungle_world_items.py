#!/usr/bin/env python3
"""Stage Huline Jungle world-item rows 0, 50, 52-57 and 63-67 (row 51 stays with prepare_jungle_source_pickups.py).

Same pinned archive/geometry/GLOBAL/LOCAL contract and decode as the row51 dagger. Each row: native placement, flags 2
with dormant bit 0x1000 clear, region, identity -> GLOBAL definition (name, handler, inventory resource) and the
original inventory image. Physical admission evidence (open ground, no ceiling, human-clearance nav path from the
Jungle start, line of sight) comes from tmp/opus_jungle_pickup_probe.gd and is pinned as probe.json. Native pickup
admission and item handlers are not replayed; item uses are not enabled here.
"""
import json, struct
from PIL import Image
from pathlib import Path
ROWS=[0,50,52,53,54,55,56,57,63,64,65,66,67]

def main():
    source=json.loads(SOURCE.read_text())
    area=next(row for row in source['areas'] if row['id']=='L4_HJ')
    blob=(GAME/area['source']['file']).read_bytes();assert digest(blob)==area['source']['sha256']
    geometry=next(row for row in parse_mix(blob) if row['key']==area['source']['geometry_key'])
    level=blob[geometry['offset']:geometry['offset']+geometry['size']];assert digest(level)==area['source']['geometry_sha256']
    assert u32(level,0x6c)==88
    definitions=entry('GLOBAL.MIX',3984507021);assert digest(definitions)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    base,count=u32(definitions,4),u32(definitions,0x34)
    state=base+count*91+4;view=state+u32(definitions,state-4)*16+4;names=view+u32(definitions,view-4)*12
    # First view resource of each definition's first selector (inventory image), same walk as row51.
    first={};state_index=view_index=0
    for index in range(count):
        record=definitions[base+index*91:][:91]
        for sel in range(record[46]+record[47]):
            views=max(1,struct.unpack_from('<b',definitions,state+state_index*16+13)[0])
            if sel==0:first[index]=struct.unpack_from('<h',definitions,view+view_index*12)[0]
            state_index+=1;view_index+=views
    by_identity={u32(definitions[base+i*91:][:91],24):i for i in range(count)}
    graphics=entry('LOCAL.MIX',4018716831);assert digest(graphics)=='36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
    sec=sections(graphics);palette=rgb_palette(graphics[u32(graphics,4):][:768],6)
    probe={int(p['row']):p for p in PROBE}
    OUT.mkdir(parents=True,exist_ok=True);items=[]
    for r in ROWS:
        row=level[u32(level,0x20)+37*r:][:37]
        x,y,_,z=struct.unpack_from('<hhHh',row);flags,region=struct.unpack_from('<HH',row,8);identity=u32(row,32)
        assert flags==2 and not flags&0x1000,(r,flags)
        d=by_identity[identity];name=definitions[names+d*30:names+d*30+24].split(b'\0')[0].decode()
        record=definitions[base+d*91:][:91];resource=first[d]
        desc=struct.unpack_from('<6H11I',graphics,sec[2]+resource*56)
        width,height,pixels,_=decode_rows(graphics[sec[3]+desc[7]:][:desc[12]],allow_special=True);assert (width,height)==desc[1:3]
        rgba=bytes(c for p in pixels for c in (*palette[p*3:p*3+3],0 if p in (0,1) else 255))
        stem=name.split('-',1)[1].replace(' ','_')
        icon=f'item{r}_{stem.lower()}.png';Image.frombytes('RGBA',(width,height),rgba).save(OUT/icon)
        p=probe[r];assert p['nav_reachable'] and p['line_of_sight'] and p['ceiling_dy'] is None and abs(p['support_y'])<1
        items.append(dict(row=r,id=f'jungle:item{r}:{stem}',name=name,label=name.split('-',1)[1],position=[x,z,-y],native_position=[x,y,z],
            flags=flags,region=region,identity=identity,definition=d,handler=record[0x42],resource=resource,size=[width,height],
            icon='res://assets/lol2/generated/jungle_world_items/'+icon,pixels_sha256=digest(pixels),placement_hex=row.hex(),
            probe=dict(support_y=p['support_y'],nav_reachable=True,line_of_sight=True,ceiling=None)))
    catalog=dict(version=1,rows=ROWS,items=items,level_sha256=digest(level),definitions_sha256=digest(definitions),graphics_sha256=digest(graphics),
        scope='Physically admitted open-ground world items (probe). Native pickup admission/handlers not replayed; uses not enabled. Row51 is the separate dagger module.')
    (OUT/'items.json').write_text(json.dumps(catalog,indent=1)+'\n')
    (ROOT/'docs'/'jungle-world-items-source.json').write_text(json.dumps(catalog,indent=1)+'\n')
    print('PASS',[(i['row'],i['id'],i['definition'],i['size']) for i in items])
def explicit_main():
    import argparse, hashlib
    global ROOT, GAME, SOURCE, OUT, PROBE, entry, sections, rgb_palette, decode_rows, digest, u32, parse_mix
    from lol2_source_format import parse_mix, u32
    from lol2_material_format import sections, rgb_palette
    from lol2_creature_sprite_format import decode_rows
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'source', 'recipe', 'output-root']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    GAME, SOURCE, ROOT = args.game.resolve(), args.source.resolve(), args.output_root.resolve()
    if ROOT.exists(): parser.error('Output must be a fresh directory')
    for path in [GAME, SOURCE, args.recipe.resolve()]:
        if ROOT == path or ROOT in path.parents or path in ROOT.parents:
            parser.error('Output overlaps input')
    digest = lambda raw: hashlib.sha256(raw).hexdigest()
    archives = {}
    try:
        for name, wanted in [
            ('DAT/L4_HJ.MIX', '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'),
            ('GLOBAL.MIX', '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
            ('LOCAL.MIX', 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
            archives[name] = (GAME / name).read_bytes()
            if digest(archives[name]) != wanted: raise ValueError('Unsupported original ' + name)
        source = json.loads(SOURCE.read_text())
        area = next(row for row in source['areas'] if row['id'] == 'L4_HJ')
        if area['source'] != dict(file='DAT/L4_HJ.MIX',
                sha256=digest(archives['DAT/L4_HJ.MIX']), geometry_key=3710797084,
                geometry_sha256='445d9b270d3e62574d719851305e3e30867715993f073a2dcd0e888295172aba'):
            raise ValueError('Unsupported Jungle source profile')
        def entry(filename, key):
            raw = archives[filename]
            matches = [e for e in parse_mix(raw) if e['key'] == key]
            if len(matches) != 1: raise ValueError('Expected one source entry')
            e = matches[0]
            return raw[e['offset']:e['offset'] + e['size']]
        recipe_raw = args.recipe.read_bytes()
        if digest(recipe_raw) != '35b6a3a609ff55ccade4f61357a7e90f0c595e8a6cf1ca87cbec10bce717e789': raise ValueError('Unsupported recorded pickup probe recipe')
        PROBE = json.loads(recipe_raw)['rows']
        if [q['row'] for q in PROBE] != ROWS: raise ValueError('Recorded pickup rows differ')
        OUT = ROOT / 'assets/lol2/generated/jungle_world_items'
        (ROOT / 'docs').mkdir(parents=True)
        main()
    except (OSError, ValueError, AssertionError, KeyError, StopIteration) as error:
        parser.error(str(error) or type(error).__name__)


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        explicit_main()
    else:
        from prepare_hive_wax import entry, sections, rgb_palette, decode_rows, ROOT, digest, u32
        from build_game_atlas import parse_mix
        from audit_monastery_rooms import GAME
        SOURCE = ROOT / 'docs/game-source-inventory.json'
        PROBE = json.loads((ROOT / 'tmp/opus_jungle_pickup_probe.json').read_text())
        OUT = ROOT / 'assets/lol2/generated/jungle_world_items'
        main()

