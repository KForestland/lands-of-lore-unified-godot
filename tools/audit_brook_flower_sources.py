#!/usr/bin/env python3
"""Locate Brook flower sources without treating unowned scripts as earned items.
Uses the existing pinned structural item census; original game data stays local.
"""
import collections,hashlib,json
from pathlib import Path
import audit_act_one_item_producers as census
ROOT=Path(__file__).resolve().parents[1]
def main():
    name='113-Brook flou';identity=census.identity(name);assert identity==0x2408d7
    prior=census.TARGETS
    try:
        census.TARGETS=[name]
        rows=census.scan_areas({name:identity})
    finally:census.TARGETS=prior
    grouped={}
    for row in rows:
        key=(row['area'],row['kind'],row.get('stream'),row.get('group',row.get('row')))
        if key not in grouped:
            grouped[key]={k:v for k,v in row.items() if k not in ['hex','commands','count']}
            grouped[key]['occurrences']=0
            if 'commands' in row:grouped[key]['group_commands_sha256']=hashlib.sha256(bytes.fromhex(''.join(row['commands']))).hexdigest()
        grouped[key]['occurrences']+=1
    rooms=[];dlls=0
    for p in sorted((census.GAME/'DAT').glob('*.MIX')):
        arc=p.read_bytes()
        for e in census.parse_mix(arc):
            blob=arc[e['offset']:e['offset']+e['size']]
            if blob.startswith(b'This is a linear executable dll'):
                dlls+=1
                if name.encode() in blob:rooms.append(dict(archive=p.name,sha256=hashlib.sha256(blob).hexdigest()))
    source=json.loads((ROOT/'docs/game-source-inventory.json').read_text())
    act1=['L1_DC','L3_DH','L4_HJ','L5_HC'];core=[r for r in grouped.values() if r['area'] in act1]
    assert len(core)==1 and core[0]['group']==13038 and core[0]['owners']==[] and core[0]['occurrences']==9
    report=dict(passed=True,identity=identity,item=name,areas=len(source['areas']),source_inventory_sha256=hashlib.sha256((ROOT/'docs/game-source-inventory.json').read_bytes()).hexdigest(),room_dlls_scanned=dlls,room_string_hits=rooms,rows=list(grouped.values()),core_act1=core,scope='Pinned15-map world-item/opcode3/held-item census and room DLL strings. No direct owner for cave group13038 is not proof it cannot be invoked indirectly. Creature loot, computed room grants, native pickup reachability and full-game availability are not proved by this scan. L8 darker-jungle sources are recorded separately from core Act1 maps.')
    (ROOT/'docs/brook-flower-source-checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS:',len(grouped),'source groups/placements;',dlls,'room DLLs;',len(core),'core Act1 group (no direct event owner); no core placed pickup.')
if __name__=='__main__':main()
