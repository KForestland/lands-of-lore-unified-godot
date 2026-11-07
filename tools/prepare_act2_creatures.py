#!/usr/bin/env python3
"""Source-pinned Act2/3 actors and original indexed sprites; behavior/size adapters are explicit."""
import argparse, contextlib, hashlib, json, struct
from pathlib import Path
from PIL import Image
from build_game_atlas import parse_mix, section
from lol2.map_materials import identify_entries, decode_lzo_container
import prepare_dark_halls_creature_sprites as guarded
Museum = guarded.Museum
ROOT=Path(__file__).resolve().parents[1]
AREAS=['L8_SJ','L9_DR','L10_DC','L12_CM','L13_RC','L14_HT','L16_CA','L17_HC','L19_BC','L20_BB']
# Named story characters remain peaceful pending their actual dialogue/AI owners.
NPC_PREFIX=('DAWN','BAC','DANIEL','SHAMAN','DRAR','SCOTIA')
def stage(area, game):
    archive=(game/area['source']['file']).read_bytes()
    assert hashlib.sha256(archive).hexdigest()==area['source']['sha256']
    entries=parse_mix(archive); ge=next(e for e in entries if e['key']==area['source']['geometry_key'])
    geo=archive[ge['offset']:ge['offset']+ge['size']]
    offset,count,placements=section(geo,0x1c,0x68,56)
    indices=sorted({r['definition'] for r in area['actors'] if not r['name'].upper().startswith('B_HUMAN')})
    output=ROOT/'assets/lol2/generated/act2_creatures'/area['id']
    if not (output/'sprites.json').exists():
        texture,_=decode_lzo_container(archive,identify_entries(archive,entries,ge['key'])['texture_entry'])
        Museum.stage(area['source']['file'],texture,indices,output,game=game,tolerate_unsupported=True)
    manifest=json.loads((output/'sprites.json').read_text()); frames={r['resource']:r for r in manifest['frames']}
    definitions={}; looks={}; exclusions=[]; adapters=[]
    for key,d in manifest['definitions'].items():
        valid=[i for i,s in enumerate(d['states']) if s['views'] and all(v['frames'] and all(f in frames for f in v['frames']) for v in s['views'])]
        if not valid: exclusions.append({'definition':int(key),'reason':'no completely decoded sprite state'});continue
        sel={}
        for i,row in enumerate(d['action_rows']):
            if i in valid: sel.setdefault(row[0],[]).append(i)
        def clip(action):
            s=sel.get(action,[valid[0]])[0]
            if action not in sel: adapters.append({'definition':int(key),'missing_action':action,'fallback_selector':s})
            return dict(selector=s,frames=len(d['states'][s]['views'][0]['frames']))
        clips={name:clip(a) for name,a in [('idle',0),('walk',1),('rise',9),('death',14),('corpse',15)]}
        attacks=[]
        peaceful=d['name'].upper().startswith(NPC_PREFIX)
        if not peaceful:
            for s in sel.get(5,[]):
                hits=[(e['frame'],e['value_word']&255) for e in d['states'][s]['frame_events'] if e['kind']==1]
                if hits: attacks.append(dict(selector=s,frames=len(d['states'][s]['views'][0]['frames']),hits=hits,damage=[15*p//100 for _,p in hits]))
        clips['attacks']=attacks
        definitions[key]=dict(name=d['name'],clips=clips,peaceful_adapter=peaceful,damage_base_adapter=15)
        frame=frames[d['states'][clips['idle']['selector']]['views'][0]['frames'][0]]
        with Image.open(output/frame['file']) as image: bounds=image.getbbox() or (0,0,image.width,image.height)
        # Uniform 48-unit actor height until native sprite world scale is pinned.
        scale=48/max(1,bounds[3]-bounds[1]); radius=min(24,max(6,(bounds[2]-bounds[0])*scale/2))
        looks[key]=dict(canvas=[frame['width'],frame['height']],scale=scale,floor_row=bounds[3],radius=radius,height=max(48,2*radius))
    actors=[]; skipped=[]; dormant=[]
    native=json.loads((ROOT/'scripts/lol2/native_scripts'/f"{area['id']}.json").read_text())
    wake_targets=set()
    for group in native['groups']:
        for c in group['commands']:
            raw=bytes.fromhex(c['raw_hex'])
            if c['opcode']==13 and c['kind']==0x02 and raw[4] in (6,7,10,13): wake_targets.add(c['target'])
    defs={d['definition']:d for d in area['definitions']}
    for row in area['actors']:
        i=row['actor'];d=row['definition'];r=placements[i*56:(i+1)*56]
        if str(d) not in definitions:
            skipped.append(dict(actor=i,definition=d,name=row['name'],reason='invisible B_HUMAN emitter' if row['name'].upper().startswith('B_HUMAN') else 'unsupported sprite'));continue
        x,z,h,y=struct.unpack_from('<hhHh',r);flags=struct.unpack_from('<H',r,8)[0];word30=struct.unpack_from('<H',r,30)[0]
        placement_cap=struct.unpack_from('<H',r,0x2b)[0];definition_cap=struct.unpack_from('<H',archive,defs[d]['archive_offset']+0x63)[0]
        health=min(placement_cap,definition_cap)
        assert health>0, (area['id'],i,placement_cap,definition_cap)
        if i in wake_targets or definitions[str(d)]['peaceful_adapter']: dormant.append(i)
        actors.append(dict(actor=i,definition=d,position=[x,y,-z],heading=h,health=health,placement_word30=word30,constructor_cap_operands=[placement_cap,definition_cap],constructor_cap_grade="LIKELY",health_mapping="port adapter; original English stat unnamed",behavior=r[37],flags=flags,present=not bool(flags&0x1000),loot=struct.unpack_from('<I',r,52)[0] or None,reward_scale=archive[defs[d]['archive_offset']+0x83],placement_hex=r.hex(),placement_offset=ge['offset']+offset+i*56))
    result=dict(version=1,source=area['source'],actors=actors,definitions=definitions,look=looks,regions=[],neighbour_wake={},counted=[],counter_target=0,scripted_dormant=dormant,controls=[],dormant_pose='idle',source_actor_count=count,excluded=skipped,unsupported_definitions=exclusions,clip_adapters=adapters,wake_targets=sorted(wake_targets),grade='LIKELY',adapters=['generic AI/48-unit height','15 attack base; LIKELY constructor min(placement+0x2B,definition+0x63) mapped to port health','story NPC peaceful until native owner','native field wake bridge; initial dormant when targeted by wake commands'])
    out=ROOT/'scripts/lol2/act2_populations'/f"{area['id']}.json";out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(result,indent=1)+'\n')
    print('CENSUS',area['id'],count,len(actors),len(skipped),'unsupported',exclusions,flush=True)
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game',type=Path,required=True);p.add_argument('--area',action='append');p.add_argument('--actors',type=Path,default=Path('~/lol2_github_source_20260911/docs/game-actors.json'));a=p.parse_args()
    for area in json.loads(a.actors.read_text())['areas']:
        if area['id'] in (a.area or AREAS): stage(area,a.game)
if __name__=='__main__':main()
