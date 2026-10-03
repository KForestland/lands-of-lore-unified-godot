#!/usr/bin/env python3
"""Stage the live L4_HJ DINO population source: placements, bite damage, clip timing.

Placements/health/reward come from the pinned jungle-dino-bindings.json. Bite damage
executes native A1D28/A1F2C/A22FB on global\\ai\\DINO\\stat.csv (fresh A3=0) and applies
the verified Hive event rule base*byte2/100 to selector4's kind1 event. No mitigation.
"""
import hashlib,json
from pathlib import Path
from verify_cave_roach_attack import native_bases
ROOT=Path(__file__).resolve().parents[1]
def main():
    bindings=json.loads((ROOT/'docs/jungle-dino-bindings.json').read_text())
    sprites=json.loads((ROOT/'assets/lol2/generated/jungle_dino_sprites/sprites.json').read_text())
    states={s['selector']:s for s in sprites['states']}
    bite=states[4];hits=[e for e in bite['frame_events'] if e['kind']==1]
    assert len(hits)==1 and hits[0]['frame']==9 and hits[0]['value_word']==100
    assert len(bite['views'][0]['frames'])==14 and bite['views'][0]['resource']==952
    b=native_bases('DINO')
    fresh=[k for k,v in b['constructors'].items() if 0 in v]
    assert len(fresh)==1
    base=fresh[0][0];percent=hits[0]['value_word']&255
    damage=base*percent//100
    clips={'idle':dict(selector=0,frames=12),'walk':dict(selector=1,frames=14),'bite':dict(selector=4,frames=14,hit_frame=9),
        'death':dict(selector=8,frames=12),'corpse':dict(selector=9,frames=1)}
    for name,c in clips.items(): assert len(states[c['selector']]['views'][0]['frames'])==c['frames'],name
    actors=[dict(actor=p['actor'],position=p['position'],heading=p['heading'],health=p['health']) for p in bindings['placements']]
    assert len(actors)==15 and all(a['health']==150 for a in actors) and bindings['reward_scale']==4
    source=dict(version=1,source=bindings['source'],reward_scale=4,max_health=150,damage=damage,clips=clips,actors=actors)
    (ROOT/'scripts/lol2/jungle_dino_population_source.json').write_text(json.dumps(source,indent=1)+'\n')
    report=dict(version=1,stat_source=dict(name=b['name'],entry=b['entry'],sha256=b['raw_sha256']),stats=list(b['stats'][:30]),total81=b['total'],minimum82=b['minimum'],
        constructor_bases={f'{x}/{y}':dict(count=len(v),a3_zero=0 in v) for (x,y),v in sorted(b['constructors'].items())},fresh_base=base,event=dict(selector=4,resource=952,frame=9,percent=percent),
        damage_request=damage,code_spans=b['spans'],source_json_sha256=hashlib.sha256((ROOT/'scripts/lol2/jungle_dino_population_source.json').read_bytes()).hexdigest(),
        boundaries=['Native loader/constructor executed on the original DINO bank; fresh actors use A3=0 (adapter, as Hive fresh pass).',
            'Damage request precedes heading/difficulty and player mitigation; playable health remains the provisional30 pool.',
            'Perception, pursuit speed, reach and the8fps clip clock are modern adapters.'])
    (ROOT/'docs/jungle-dino-attack.json').write_text(json.dumps(report,indent=1)+'\n')
    print(json.dumps(dict(base=base,percent=percent,damage=damage,actors=len(actors))))
if __name__=='__main__':main()
