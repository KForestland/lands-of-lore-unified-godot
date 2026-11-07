#!/usr/bin/env python3
"""Stage source flute/elevator commands, floor surfaces and control assemblies.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_hive_elevator.py --game GAME --re-root RE --recipe scripts/lol2/hive_elevator_source.json \
      --output-root FRESH
The explicit path stages assets/lol2/generated/hive_elevator from the original L5_HC/GLOBAL/LOLG data. In a temporary
directory it runs the published exporters on the originals: lol2/map_geometry.export_geometry (trigger regions),
lol2/map_materials.export_materials + lol2/map_surfaces.bind_surfaces (floors 772..774) and tools/export_map_movables.py
(static assemblies 125..132 and their material images; --re-root is that exporter's documented RE draracle closure).
The compact recipe carries only the recorded flute-handler relocation and disassembly text, checked against the pinned
executable bytes. No docs are written. Without arguments the historical behaviour is unchanged.
"""
import json,struct,shutil,sys
from pathlib import Path
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
    import argparse,hashlib,subprocess,tempfile
    from build_game_atlas import parse_mix,section,u32
    from audit_game_transition_owners import collect_owners,events
    from audit_game_actor_scripts import groups
    def digest(b):return hashlib.sha256(b).hexdigest()
    ROOT=GAME=None  # set by cli()
else:
    from audit_monastery_rooms import ROOT,GAME,digest,capstone
    from build_game_atlas import parse_mix,section,u32
    from audit_game_transition_owners import collect_owners,events
    from audit_game_actor_scripts import groups
    from verify_special_pixel_table_binding import fixups

def stage(arc,floors,source,assemblies,materials_root,exe,relocation,disassembly):
    """Everything after the inputs: controls/material images, triggers, groups, stops, flute checks, elevator.json."""
    e=next(e for e in parse_mix(arc) if e['key']==3776990464);raw=arc[e['offset']:][:e['size']]
    owners,_=collect_owners(raw,e['offset'],u32(raw,0x58))
    streams=[dict(groups(section(raw,of,cf,1)[2])) for of,cf in [(0x3c,0x84),(0x44,0x8c)]]
    _,_,placements=section(raw,0x18,0x64,33);_,_,event_blob=section(raw,0x40,0x88,1)
    assert assemblies['source']['sha256']==digest(arc)
    out=ROOT/'assets/lol2/generated/hive_elevator';out.mkdir(parents=True,exist_ok=True)
    assert len(floors)==3 and all(p[1]==-235 for f in floors for p in f['points'])
    triggers={}
    for n in [282,283]:
        r=source['regions'][n]
        triggers[str(n)]=dict(polygon=[[source['vertices_fixed'][v][0]/65536,-source['vertices_fixed'][v][1]/65536] for v in r['vertex_indices']],floor=r['floor_base'])
    controls=[]
    for n in range(125,133):
        row=placements[n*33:(n+1)*33];x,y,heading,z=struct.unpack_from('<hhHh',row)
        faces=[f.copy() for f in assemblies['faces']+assemblies['state_faces'] if f['source_index']==n]
        for face in faces:
            original=face['material'];name='m%04d.png'%face['resource_id'];shutil.copyfile(materials_root/original,out/name);face['material']=name
        controls.append(dict(index=n,position=[x,z,-y],heading=heading,placement_hex=row.hex(),faces=faces,
            events=[dict(kind=k,raw=b.hex(),predicate=p) for _,k,b,p in events(event_blob,struct.unpack_from('<H',row,12)[0])]))
    source_groups=[]
    for sid,numbers in [(0,[122,142]),(1,[4498,4650]+list(range(7364,8212,106))+list(range(8234,8520,22)))]:
        for number in numbers:
            if number not in streams[sid]:continue
            source_groups.append(dict(stream=sid,group=number,owners=[o for o in owners if o['stream']==sid and o['group']==number],commands=[b.hex() for _,b in streams[sid][number]]))
    stops=[]
    for number in range(7364,8212,106):
        commands=streams[1][number];moves=[b for _,b in commands if b[0]==196]
        assert sorted(struct.unpack_from('<H',b,2)[0] for b in moves)==[772,773,774]
        heights=[struct.unpack_from('<h',b,4)[0] for b in moves];assert len(set(heights))==1
        stops.append(heights[0])
    assert stops==[-235,-427,-619,-811,-1003,-1195,-1387,-1579]
    global_arc=(GAME/'GLOBAL.MIX').read_bytes();ge=next(e for e in parse_mix(global_arc) if e['key']==3984507021);global_data=global_arc[ge['offset']:][:ge['size']]
    assert digest(global_data)=='b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    definition=global_data[u32(global_data,4)+96*91:][:91];assert definition[0x42]==16 and u32(definition,24)==3020830916
    name_offset=u32(global_data,0x64)+u32(global_data,0x60)+36*41
    assert global_data[name_offset:].split(b'\0')[0]==b'GV_IRON_FLUTE'
    assert digest(exe)=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
    assert relocation['target_object']==2 and relocation['target_offset']+0x59024==0x971f0
    code=exe[0x971f0+0x37000:0x97277+0x37000]
    report=dict(archive_sha256=digest(arc),geometry_sha256=digest(raw),executable_sha256=digest(exe),floors=floors,triggers=triggers,controls=controls,stops=stops,source_groups=source_groups,
        flute=dict(definition=96,identity=3020830916,raw_definition=definition.hex(),handler_index=16,relocation=relocation,handler=0x971f0,code_sha256=digest(code),
            disassembly=disassembly,shared36_name='GV_IRON_FLUTE'),
        limits=['Source floor targets and control assembly meshes; E input/cycle, move speed and timer polling are modern adaptations.',
                'Flute handler sound request retained but original audio resource binding is not yet staged.',
                'Group4498 lava/other timer/light effects are retained in source report, not all implemented. Do not infer that the lift itself requires flute activation.'])
    (out/'elevator.json').write_text(json.dumps(report,indent=2)+'\n')
    return report,controls

def main():
    arc=(GAME/'DAT/L5_HC.MIX').read_bytes();assert digest(arc)=='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
    source=json.loads(Path('~/lol2_out/hive_geometry_20260914/geometry.json').read_text())
    staged=json.loads((ROOT/'assets/lol2/generated/hive_review/hive.json').read_text())
    allmap=Path('~/lol2_out/all_maps_20260922/L5_HC')
    assemblies=json.loads((allmap/'static_assemblies/movables.json').read_text())
    floors=[f for f in staged['faces'] if f['kind']=='floor' and f['region'] in [772,773,774]]
    exe=(GAME/'LOLG.DAT').read_bytes();assert digest(exe)=='b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
    le=0x39024+u32(exe,0x39060);first=u32(exe,le+u32(exe,le+0x40)+108);slot=0xc860+16*4
    relocation=fixups(exe,le,first-1+slot//4096)[slot%4096]
    code=exe[0x971f0+0x37000:0x97277+0x37000]
    disassembly=[f'{i.address:x} {i.mnemonic} {i.op_str}' for i in capstone.Cs(3,4).disasm(code,0x971f0)]
    report,controls=stage(arc,floors,source,assemblies,allmap,exe,relocation,disassembly)
    summary={k:v for k,v in report.items() if k not in ['floors','controls']};summary['controls']=[{k:v for k,v in c.items() if k!='faces'} for c in controls]
    (ROOT/'docs/hive-elevator-source.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('PASS: eight source lift stops, three floor patches, eight original control assemblies and flute handler16')

# ---- explicit inputs -------------------------------------------------------------------------------------------------
RECIPE_SHA256='ca2ba5aaa1caf2712603ef3c504ecc0248e135f1e0978ea16c373358fd8908e3'  # scripts/lol2/hive_elevator_source.json
ORIGINALS={'DAT/L5_HC.MIX':'a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8',
           'LOLG.DAT':'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'}
GLOBAL_ENTRY=(3984507021,'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891')

def check_recipe(exe,recipe):
    rel,h=recipe['relocation'],recipe['handler']
    at=rel['record_file_offset'];assert exe[at:at+len(rel['record_hex'])//2].hex()==rel['record_hex'],'fixup record bytes'
    assert rel['target_object']==2 and rel['target_offset']+0x59024==h['start']==0x971f0 and h['end']==0x97277,'handler16 target'
    assert digest(exe[h['start']+0x37000:h['end']+0x37000])==h['code_sha256'],'handler bytes'
    lines=recipe['disassembly'];assert lines and all(isinstance(l,str) for l in lines),'disassembly'
    assert int(lines[0].split()[0],16)==h['start'] and all(h['start']<=int(l.split()[0],16)<h['end'] for l in lines),'disassembly addresses'

def cli():
    global ROOT,GAME
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game','re-root','recipe','output-root']: p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    tools=Path(__file__).resolve().parent
    exporter=tools/'export_map_movables.py'
    if not exporter.is_file(): p.error('Missing published exporter '+str(exporter))
    if not (a.re_root/'tools/draracle').is_dir(): p.error(f'{a.re_root}: no tools/draracle closure for export_map_movables.py')
    if not a.recipe.is_file(): p.error('Missing input: '+str(a.recipe))
    if digest(a.recipe.read_bytes())!=RECIPE_SHA256: p.error(f'{a.recipe}: not the pinned Hive elevator recipe ({RECIPE_SHA256})')
    recipe=json.loads(a.recipe.read_text())
    for rel,want in ORIGINALS.items():
        if not (a.game/rel).is_file(): p.error('Missing original '+str(a.game/rel))
        if digest((a.game/rel).read_bytes())!=want: p.error(f'{a.game/rel}: not the pinned original')
    if not (a.game/'GLOBAL.MIX').is_file(): p.error('Missing original '+str(a.game/'GLOBAL.MIX'))
    GAME=a.game.resolve();arc=(GAME/'DAT/L5_HC.MIX').read_bytes();exe=(GAME/'LOLG.DAT').read_bytes()
    try:
        check_recipe(exe,recipe)
        g=(GAME/'GLOBAL.MIX').read_bytes();ge=next(e for e in parse_mix(g) if e['key']==GLOBAL_ENTRY[0]);assert digest(g[ge['offset']:][:ge['size']])==GLOBAL_ENTRY[1],'GLOBAL definitions'
    except (AssertionError,StopIteration,KeyError,ValueError,IndexError,TypeError) as error:
        p.error('Originals do not match the recorded inputs: '+(str(error) or type(error).__name__))
    with tempfile.TemporaryDirectory(prefix='hive-elevator-') as tmp:
        tmp=Path(tmp)
        sys.path.insert(0,str(tools/'lol2'))
        import map_geometry,map_materials,map_surfaces
        try:
            map_geometry.export_geometry(GAME,'L5_HC',tmp/'geometry')
            map_materials.export_materials(GAME,'L5_HC',tmp/'materials/L5_HC/materials')
            map_surfaces.bind_surfaces(GAME,'L5_HC',tmp/'geometry',tmp/'materials/L5_HC/materials',tmp/'surfaces')
        except (AssertionError,ValueError,KeyError,OSError) as error:
            p.error('Published exporters refused the originals: '+str(error))
        run=subprocess.run([sys.executable,'-B',str(exporter),'--game-root',str(GAME),'--material-root',str(tmp/'materials'),'--re-root',str(a.re_root.resolve()),
                            '--tools-root',str(tools),'--area','L5_HC','--placement-kind','static_assembly','--out',str(tmp/'movables')],capture_output=True,text=True)
        if run.returncode!=0: p.error('export_map_movables.py failed: '+run.stderr.strip()[-400:])
        source=json.loads((tmp/'geometry/geometry.json').read_text())
        review=json.loads((tmp/'surfaces/review.json').read_text())
        floors=[dict(region=f['region'],kind=f['kind'],material=f['material'],uv=f['uv'],points=f['points']) for f in review['faces'] if f.get('kind')=='floor' and f.get('region') in [772,773,774]]
        assemblies=json.loads((tmp/'movables/movables.json').read_text())
        if assemblies['source']['sha256']!=digest(arc): p.error('movables export belongs to a different archive')
        ROOT=a.output_root.resolve()
        report,controls=stage(arc,floors,source,assemblies,Path(assemblies['materials_root']),exe,recipe['relocation'],recipe['disassembly'])
    print('PASS explicit Hive elevator:',len(report['stops']),'stops,',len(report['floors']),'floors,',len(controls),'controls')

if __name__=='__main__':
    if EXPLICIT: cli()
    else: main()
