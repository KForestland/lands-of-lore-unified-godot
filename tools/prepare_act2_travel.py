#!/usr/bin/env python3
"""Pin Act 2/3 exits and arrival rows to original archives; no predicate is bypassed.
Native data framing is PROVEN as bytes. Arrival/routing semantics stay LIKELY (Grok backlog5 items1/2).
"""
import argparse, hashlib, json, struct
from pathlib import Path
from verify_native_scripts import area_index, link_status
ROOT=Path(__file__).resolve().parents[1]
AREAS=['L8_SJ','L9_DR','L10_DC','L12_CM','L13_RC','L14_HT','L16_CA','L17_HC','L19_BC','L20_BB']
LEVELS={int(a.split('_')[0][1:]):a for a in AREAS+['L4_HJ']}
def build(game, project):
    maps={}; edges=[]
    for area in AREAS+['L4_HJ']:
        d=json.loads((project/'scripts/lol2/native_scripts'/f'{area}.json').read_text())
        source=d['source']; archive=(game/source['file']).read_bytes()
        assert hashlib.sha256(archive).hexdigest()==source['sha256']
        base=source['geometry_entry_offset']; offset=struct.unpack_from('<I',archive,base+0x48)[0]; count=struct.unpack_from('<I',archive,base+0x90)[0]
        nav=json.loads((project/'assets/lol2/generated/creature_nav'/f'{area}.json').read_text())
        arrivals=[]
        for i in range(count):
            at=base+offset+i*12; raw=archive[at:at+12];x,y,heading,region,selector=struct.unpack_from('<hhHHB',raw)
            floor=nav['regions'][region][1] if region<len(nav['regions']) and nav['regions'][region][0] else None
            arrivals.append(dict(selector=selector,x=x,y=y,heading_units=heading,region=region,floor_min=floor,grade='LIKELY',file_offset=at,raw_hex=raw.hex(),witness='Grok backlog5 item2: row fields and binding LIKELY; file bytes pinned.'))
        maps[area]=dict(source=source,arrivals=arrivals)
        if area not in AREAS:continue
        index=area_index(d);groups={(g['stream'],g['group']):g for g in d['groups']}
        for obj in d['objects']:
            for event in obj['events']:
                if 'group' not in event:continue
                group=groups[event['stream'],event['group']]
                for c in group['commands']:
                    raw=bytes.fromhex(c['raw_hex'])
                    if raw[:5]!=bytes.fromhex('020100001c'):continue
                    status,reason=link_status(obj['ref'],event,group,index)
                    e=dict(id=f"{area}:{obj['ref']}:{event['file_offset']}:{c['file_offset']}",area=area,owner=obj['ref'],event=event,stream=group['stream'],group=group['group'],command_offset=c['file_offset'],raw_hex=c['raw_hex'],destination=LEVELS[raw[5]&31],level=raw[5]&31,selector=raw[5]>>5,static_grade={'P':'PROVEN','A':'ADAPTER'}.get(status,'BLOCKED'),blocked_reason=reason)
                    if 'placement_hex' in obj:
                        p=bytes.fromhex(obj['placement_hex']);x,y,h,z=struct.unpack_from('<hhHh',p);e['position']=[x,z,-y]
                    edges.append(e)
    for e in edges:assert sum(a['selector']==e['selector'] for a in maps[e['destination']]['arrivals'])==1,e
    return dict(version=1,scope='Original exit records and arrival bytes. Scene mapping/input/camera adapters; no claim every gate is open.',areas=maps,edges=edges)
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--project',type=Path,default=ROOT);a=p.parse_args();data=build(a.game,a.project)
    (a.project/'scripts/lol2/act2_travel.json').write_text(json.dumps(data,indent=2)+'\n')
    path=a.project/'scripts/lol2/act2_maps.json';registry=json.loads(path.read_text());by_area={m['area']:m for m in registry['maps']}
    for area in AREAS:
        if area not in by_area:
            row=dict(area=area,scene='res://scenes/lol2/'+('darker_jungle' if area=='L8_SJ' else 'dragon_level')+'.tscn',label=area,label_witness='Archive identifier',travel_only=True);registry['maps'].append(row);by_area[area]=row
        by_area[area]['arrivals']=data['areas'][area]['arrivals']
    path.write_text(json.dumps(registry,indent=2)+'\n');print('PASS',len(data['edges']),'exit links;',sum(len(v['arrivals']) for v in data['areas'].values()),'arrival rows pinned')
if __name__=='__main__':main()
