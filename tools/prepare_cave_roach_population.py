#!/usr/bin/env python3
"""Build numeric cave population data from pinned source audit and geometry."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    source=json.loads((ROOT/'docs/cave-roach-population-source.json').read_text())
    ai=json.loads((ROOT/'tests/fixtures/cave_roach_ai_choice_native.json').read_text())
    geometry=json.loads(Path('/home/bob/lol2_out/all_maps_20260922/L1_DC/geometry/geometry.json').read_text())
    assert geometry['source']['sha256']==source['source']['sha256']
    assert geometry['source']['geometry_sha256']==source['source']['geometry_sha256']
    assert len(source['placements'])==23 and len(ai['base_stats'])==30
    regions=[]
    for index in [1140,1358]:
        r=geometry['regions'][index];assert r['id']==index
        regions.append(dict(region=index,polygon=[[geometry['vertices_fixed'][v][0]/65536,-geometry['vertices_fixed'][v][1]/65536] for v in r['vertex_indices']],floor_min=min(r['floor_corners']),floor_max=max(r['floor_corners'])))
    inventory=json.loads((ROOT/'docs/game-actors.json').read_text())
    area=next(a for a in inventory['areas'] if a['id']=='L1_DC')
    definition=next(d for d in area['definitions'] if d['definition']==4)
    archive=(Path('/home/bob/lol2_out/museum_capture_20260913/game')/area['source']['file']).read_bytes()
    assert hashlib.sha256(archive).hexdigest()==source['source']['sha256']
    scale=archive[definition['archive_offset']+0x83];assert scale==1
    result=dict(source=source['source'],reward_scale=scale,stats=ai['base_stats'],actors=[dict(actor=r['actor'],position=r['position'],heading=r['heading'],health=r['health']) for r in source['placements']],regions=regions)
    (ROOT/'scripts/lol2/cave_roach_population_source.json').write_text(json.dumps(result,indent=2)+'\n')
    print('PASS:23 source Roach identities and two pinned first-contact polygons')
if __name__=='__main__':main()
