#!/usr/bin/env python3
"""Package reverified original EXEC frames for checkpoint-driven Godot rendering."""
import argparse,hashlib,json,runpy,struct,sys,tempfile
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]


def assemble(sequences,archive_sha256,out):
    """Pack [(selector,[frame PNG paths])] into per-selector RGBA atlases and sprites.json (unchanged packing)."""
    out.mkdir(parents=True,exist_ok=True)
    clips=[]
    for selector,files in sequences:
        with Image.open(files[0]) as first: width,height=first.size
        assert width==320 and height==(240 if selector in [19,20] else 200)
        columns=min(6,len(files));sheet=Image.new('RGBA',(width*columns,height*((len(files)+columns-1)//columns)))
        hashes=[]
        for i,path in enumerate(files):
            with Image.open(path) as image:
                image=image.convert('RGBA');assert image.size==(width,height)
                hashes.append(hashlib.sha256(image.tobytes()).hexdigest())
                sheet.paste(image,((i%columns)*width,(i//columns)*height))
        name=f'selector_{selector}.png';sheet.save(out/name)
        clips.append(dict(selector=selector,frames=len(files),columns=columns,width=width,height=height,file=name,rgba_sha256=hashes,png_sha256=hashlib.sha256((out/name).read_bytes()).hexdigest()))
    (out/'sprites.json').write_text(json.dumps(dict(version=1,width=320,height=200,clips=clips,archive_sha256=archive_sha256,scope='All32 source0/2 frames,35 attack frames and30 outcome frames. Per-clip source canvas sizes preserved. Source palette with index0 transparent; preview world anchoring remains authored. No clock or admission implied.'),indent=2)+'\n')


def legacy():
    # Historical path: the three exporters run their native audits and write the capture directories.
    runpy.run_path(str(ROOT/'tools/export_hive_attack_review.py'))
    runpy.run_path(str(ROOT/'tools/export_hive_executioner_selectors.py'))
    runpy.run_path(str(ROOT/'tools/export_hive_outcome_sprites.py'),run_name='__main__')
    attack=Path('~/lol2_out/hive_executioner_attacks_20260915')
    poses=Path('~/lol2_out/hive_executioner_selectors_20260915')
    outcomes=Path('~/lol2_out/hive_outcome_sprites_20260916')
    proof=json.loads((attack/'review.json').read_text())
    pose_proof=json.loads((poses/'review.json').read_text())
    outcome_proof=json.loads((outcomes/'review.json').read_text())
    assert outcome_proof['archive_sha256']==proof['archive_sha256']
    sequences=[(p['selector'],[poses/f['file'] for f in p['frames']]) for p in pose_proof['poses']]+[(c['selector'],[attack/f['file'] for f in c['frames']]) for c in proof['clips']]+[(p['selector'],[outcomes/f['file'] for f in p['frames']]) for p in outcome_proof['poses']]
    out=ROOT/'assets/lol2/generated/hive_executioner_sprites'
    assemble(sequences,proof['archive_sha256'],out)
    print('Prepared97 EXEC sprite frames:',out)


ARCHIVE_SHA256='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8'
TEXTURE_SHA256='c577f70d194cb25fa6b83818ae7e240486ac871b6915408eb2515ded5f1251ba'
# EXEC (L5_HC entry 3776335874, entity 1) first-view resources; equal to the former native audit records.
SELECTORS={0:688,2:433,11:704,12:771,17:474,18:742,19:336,20:334}

def cli():
    p=argparse.ArgumentParser(description='Prepare the 97 EXEC sprite frames from explicit original inputs (no native audits).')
    p.add_argument('--game',type=Path,required=True)
    p.add_argument('--texture',type=Path,required=True,help='fresh decoded L5_HC texture (sha256 pinned)')
    p.add_argument('--output-root',type=Path,required=True)
    args=p.parse_args()
    if args.output_root.exists():p.error('Use a fresh output root')
    sys.path.insert(0,str(ROOT/'tools'))
    from lol2_source_format import parse_mix
    from lol2_creature_sprite_format import parse_states
    archive=(args.game/'DAT/L5_HC.MIX').read_bytes()
    if hashlib.sha256(archive).hexdigest()!=ARCHIVE_SHA256:p.error('Original Hive archive does not match')
    blob=args.texture.read_bytes()
    if hashlib.sha256(blob).hexdigest()!=TEXTURE_SHA256:p.error('Original Hive texture does not match')
    entry=next(e for e in parse_mix(archive) if e['key']==3776335874)
    entity=parse_states(archive[entry['offset']:entry['offset']+entry['size']])['entities'][1]
    if entity['name']!='EXEC' or {s:entity['states'][s]['views'][0]['resource_reference'] for s in SELECTORS}!=SELECTORS:p.error('EXEC state table does not match the original')
    states=entity['states']
    import export_hive_executioner_selectors as pose_frames, export_hive_attack_review as attack_frames, export_hive_outcome_sprites as outcome_frames
    with tempfile.TemporaryDirectory(prefix='exec-frames-') as tmp:
        stage=Path(tmp)
        poses=pose_frames.write_frames(blob,states,stage/'poses')
        clips=attack_frames.write_frames(blob,states,stage/'attack')
        outcomes=outcome_frames.write_frames(blob,[dict(selector=s,resources=[SELECTORS[s]]) for s in (17,18,19,20)],stage/'outcomes')
        sequences=[(r['selector'],[stage/'poses'/f['file'] for f in r['frames']]) for r in poses]+[(c['selector'],[stage/'attack'/f['file'] for f in c['frames']]) for c in clips]+[(r['selector'],[stage/'outcomes'/f['file'] for f in r['frames']]) for r in outcomes]
        assemble(sequences,ARCHIVE_SHA256,args.output_root/'assets/lol2/generated/hive_executioner_sprites')
    print('Prepared',sum(len(f) for _,f in sequences),'EXEC sprite frames:',args.output_root)


if __name__=='__main__':
    cli() if len(sys.argv)>1 else legacy()
