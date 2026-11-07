#!/usr/bin/env python3
"""Reproduce Museum urn189/195 -> placed Ivory Chip17/18, original art and bounded native hit filter.
No later-area use or departure requirement is inferred. Requires locally extracted L3_DH texture data.
"""
import argparse, hashlib, json, shutil, sys
from pathlib import Path
from lol2_source_format import parse_mix, u32
from lol2 import map_props as props
ROOT = Path(__file__).resolve().parents[1]

def replay(rows):
    from verify_hive_executioner import GAME, EXE_HASH, CreatureReplay, capstone
    from verify_special_pixel_table_binding import fixups
    exe=(GAME/'LOLG.DAT').read_bytes(); assert hashlib.sha256(exe).hexdigest()==EXE_HASH
    md=capstone.Cs(3,4); md.detail=True
    raw=exe[0xae2c8+0x37000:0xae50f+0x37000]
    ins={i.address:i for i in md.disasm(raw,0xae2c8)}
    le=0x39024+u32(exe,0x39060); first=u32(exe,le+u32(exe,le+0x40)+36); slot=0x55290+3*4
    rel=fixups(exe,le,first-1+slot//4096)[slot%4096]
    assert rel['target_object']==2 and rel['target_offset']+0x59024==0xae3a6
    m=CreatureReplay(ins,b''); m.writemem(slot,4,0xae3a6)
    record,context,stack,groups=0x500000,0x510000,0x520000,0x530000
    m.writemem(0x2b514,4,groups); cases=accepted=0
    for row in rows:
        pred=row['hit']['predicate']; payload=bytes.fromhex(row['hit']['raw'])+(bytes.fromhex('04130e00') if pred is not None else b'')+bytes.fromhex('0200')
        for mask in [0,1,4,17,65535]:
            for before in [-1,0,1,2,30]:
                for after in [-1,0,1,2,30]:
                    for result in [0,1]:
                        m.mem[record:record+len(payload)]=payload; m.regs.update(ebx=record,ebp=context,esp=stack)
                        for off,val in [(4,0),(0x10,mask),(0x14,mask)]:m.writemem(stack+off,4,val)
                        m.writemem(context+0x22,4,before);m.writemem(context+0x26,4,after)
                        stop=m.execute(0xae2f5,{0xae4e3,0xae49d,0xae4bf})
                        crossed=before>1 and after<=1
                        assert (stop!=0xae4e3)==crossed
                        if stop==0xae49d:
                            assert pred==14 and m.readmem(m.regs['esp'],4)==14
                            m.regs['eax']=result;stop=m.execute(0xae4a2,{0xae4e3,0xae4bf})
                        wanted=crossed and (pred is None or bool(result))
                        assert (stop==0xae4bf)==wanted
                        if wanted:
                            assert m.readmem(m.regs['esp'],4)==groups+row['hit']['group']
                            m.execute(0xae4c4,0xae4e3)
                            assert m.readmem(record+8,1)==1 and m.readmem(record+9,1)==3
                            accepted+=1
                        cases+=1
    return dict(passed=True,cases=cases,accepted=accepted,executable_sha256=EXE_HASH,code_sha256=hashlib.sha256(raw).hexdigest(),condition='wildcard masks; supplied before>1 and after<=1; prop195 predicate14 result required',limits='Damage contexts and predicate return supplied; native attack damage calculation not replayed.')

def main():
    from verify_actor_item_grants import source_area
    from build_game_atlas import section
    from prepare_jungle_harvest import records
    from prepare_museum_key_locks import MAP, definitions, icon
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--asset-dir',type=Path,required=True);a=p.parse_args()
    area,arc,entry,geo,owners,streams=source_area('L3_DH');_,_,table=section(geo,0xbc,0xb8,5)
    _,_,placements=section(geo,0x14,0x60,37)
    # Pin placed-item bytes directly against the original archive.
    # Locate pinned bytes directly in the pinned geometry rather than depending on an old extraction report.
    itemraw=['2000d40200000a0002103700000000000000000014747f00d97b5a0014000000090c2e0400','e8006e060000000002109500000000000000000014747f00d97b5a0014000000090c2e0400']
    exported={q['record']:q for q in json.loads((MAP/'props/props.json').read_text())['props']}
    rows=[]
    commands=[['0903bd000800','0903bd001200','1403bd002a0180050a14','0503bd000000','090411000300'],['0903c3001200','0503c3000000','090412000300','0903c3000800','1003c3000100','1403c300dd00fa851900']]
    for k,(n,item,pos) in enumerate([(189,17,[32,10,-724]),(195,18,[232,0,-1646])]):
        r=records(owners,streams,arc,table,n);assert len(r)==1
        r=r[0];assert r['kind']==9 and r['group']==[3502,3662][k] and r['commands']==commands[k]
        assert r['predicate_raw']==[None,'0005000000'][k] and bytes.fromhex(r['raw'])[4:]==bytes.fromhex('000000000103')
        q=exported[n];b=placements[n*37:(n+1)*37];assert b.hex()==q['placement_hex'] and b[30]==2 and q['template']==30 and q['selector']==1
        ib=bytes.fromhex(itemraw[k]);assert geo.count(ib)==1 and geo[u32(geo,0x20)+item*37:u32(geo,0x20)+(item+1)*37]==ib
        rows.append(dict(prop=n,item=item,id='museum:item%d:Ivory_Chip'%item,position=q['position'],region=q['region'],durability=2,placement_hex=b.hex(),hit=r,item_position=pos,item_raw=ib.hex(),item_archive_offset=entry['offset']+geo.index(ib)))
    meta=next(e for e in parse_mix(arc) if e['key']==3105896470)
    template=props.load_templates(arc[meta['offset']:meta['offset']+meta['size']])['templates'][30]
    tex=(MAP/'materials/texture.bin').read_bytes();report=json.loads((MAP/'materials/materials.json').read_text());assert hashlib.sha256(tex).hexdigest()==report['source_hash']['decoded_texture_sha256']
    sec=props.mm.sections(tex);rgb=props.mm.rgb_palette(tex[props.u32(tex,4):][:768],6)
    a.asset_dir.mkdir(parents=True,exist_ok=True);tmp=a.asset_dir/'_build';(tmp/'sprites').mkdir(parents=True,exist_ok=True);art=[]
    for s in template['selectors']:
        assert len(s['frames'])==1;f=s['frames'][0];im=props.build_image(f['descriptor'],tex,sec,rgb,tmp/'sprites',tmp,{})
        name='urn_%d.png'%s['selector'];shutil.copyfile(tmp/im.get('frames',[im['image']])[0],a.asset_dir/name)
        art.append(dict(selector=s['selector'],file=name,left=f['left'],right=f['right'],bottom=f['bottom'],top=s['state_height']-f['top_trim'],sha256=hashlib.sha256((a.asset_dir/name).read_bytes()).hexdigest()))
    shutil.rmtree(tmp)
    blob,base,count,names=definitions();assert names[107]=='105-Ivory chip' and u32(blob,base+107*91+24)==70126601
    icon(107,a.asset_dir/'ivory.png')
    result=dict(version=1,source=area['source'],containers=rows,art=art,icon_sha256=hashlib.sha256((a.asset_dir/'ivory.png').read_bytes()).hexdigest(),native_filter=replay(rows),adapters=['Modern melee/Spark container damage; native attack calculation not replicated.','Source selects0 on hit; both decoded images identical. Runtime hides the spent urn for feedback; independent item pickup. Original sound commands not yet hosted.'],limits=['No later-area Ivory Chip use or Museum departure prerequisite inferred.'])
    a.output.write_text(json.dumps(result,indent=1)+'\n');print('PASS Museum ivory source, 2 urns, 2 placed items, original selector art; native filter',result['native_filter'])
def media_cli():
    """Rebuild only the original art using the already published source contract."""
    from prepare_museum_key_locks import definitions, icon
    p=argparse.ArgumentParser(description=media_cli.__doc__)
    p.add_argument('--media-only',action='store_true',required=True)
    for name in ['game','texture','source','output-root']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    if a.output_root.exists():p.error('--output-root must be fresh')
    for path in [a.texture,a.source,a.game/'DAT/L3_DH.MIX',a.game/'GLOBAL.MIX',a.game/'LOCAL.MIX']:
        if not path.is_file():p.error('Missing input: '+str(path))
    contract=json.loads(a.source.read_text())
    expected_archive='bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac'
    if contract['source']['file']!='DAT/L3_DH.MIX' or contract['source']['sha256']!=expected_archive:p.error('Unsupported Museum source contract')
    arc=(a.game/'DAT/L3_DH.MIX').read_bytes()
    if hashlib.sha256(arc).hexdigest()!=expected_archive:p.error('Unsupported Museum archive')
    tex=a.texture.read_bytes()
    if hashlib.sha256(tex).hexdigest()!='7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07':p.error('Unsupported Museum texture')
    meta=next(e for e in parse_mix(arc) if e['key']==3105896470)
    template=props.load_templates(arc[meta['offset']:meta['offset']+meta['size']])['templates'][30]
    if [(row['selector'],row['file']) for row in contract['art']] != [(0,'urn_0.png'),(1,'urn_1.png')]:p.error('Unsupported urn art contract')
    blob,base,count,names=definitions(game=a.game)
    if names[107]!='105-Ivory chip' or u32(blob,base+107*91+24)!=70126601:p.error('Unsupported Ivory Chip definition')
    sec=props.mm.sections(tex);rgb=props.mm.rgb_palette(tex[props.u32(tex,4):][:768],6)
    out=a.output_root/'assets/lol2/generated/museum_ivory';tmp=a.output_root/'tmp/ivory';(tmp/'sprites').mkdir(parents=True)
    out.mkdir(parents=True);art=[]
    for selector in template['selectors']:
        assert len(selector['frames'])==1
        frame=selector['frames'][0];image=props.build_image(frame['descriptor'],tex,sec,rgb,tmp/'sprites',tmp,{})
        name='urn_%d.png'%selector['selector'];shutil.copyfile(tmp/image.get('frames',[image['image']])[0],out/name)
        art.append(dict(selector=selector['selector'],file=name,left=frame['left'],right=frame['right'],bottom=frame['bottom'],top=selector['state_height']-frame['top_trim'],sha256=hashlib.sha256((out/name).read_bytes()).hexdigest()))
    assert art==contract['art'],'Urn pixels/bounds differ from source contract'
    icon(107,out/'ivory.png',game=a.game)
    assert hashlib.sha256((out/'ivory.png').read_bytes()).hexdigest()==contract['icon_sha256']
    shutil.rmtree(tmp)
    print('PASS Museum Ivory media: two urn selectors and one icon; published contract unchanged; native replay not run')

if __name__=='__main__':
    if '--media-only' in sys.argv:media_cli()
    else:main()
