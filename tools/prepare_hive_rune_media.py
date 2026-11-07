#!/usr/bin/env python3
"""Stage original Hive rune-room video assets for the shared compositor.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_hive_rune_media.py --game GAME --re-root RE --recipe scripts/lol2/hive_rune_rooms_source.json \
      --output-root FRESH
The compact recipe carries the consumed records of the recorded rune-room audit (archive/DLL bindings, hotspots); every
binding and clip entry is re-verified against the original RUNES/RUNECL archives. Published helpers only
(tools/monastery_media.py); the RE checkout supplies only the pinned video converter. No docs are written. Without
arguments the historical behaviour (docs/hive-rune-room-source.json in, docs/hive-rune-media-checks.json out) is unchanged.
"""
import json,subprocess,sys
from pathlib import Path
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
    import argparse,shutil
    import monastery_media
    from monastery_media import extract,digest,movie
    ROOT=GAME=convert=None  # set by cli()

    def stage_patch(source,target,record):
        return monastery_media.stage_patch(source,target,record,ROOT)
else:
    from audit_monastery_rooms import ROOT,GAME,extract,digest,movie
    from prepare_monastery_rooms import convert,stage_patch

CLIPS=[('RUNES',['RUNES_','RUNES1_','RUNES2_','RUNES3_','RUNES4_']),('RUNECL',['RUNECL_'])]

def stage_rooms(audit):
    out=ROOT/'assets/lol2/generated/hive_rune_rooms';cache=ROOT/'tmp/hive_rune_source'
    cache.mkdir(parents=True,exist_ok=True)
    manifest=dict(version=1,canvas=[640,400],rooms={});sources=[]
    for room,names in CLIPS:
        archive=(GAME/'DAT'/f'{room}.MIX').read_bytes()
        assert digest(archive)==audit['rooms'][room]['archive_sha256']
        clips={}
        for name in names:
            source_name=f'WOMS\\{room}\\{name}.VQA'
            record=movie(archive,source_name);payload,binding=extract(archive,source_name)
            assert digest(payload)==record['sha256']
            source=cache/(name+'.VQA');source.write_bytes(payload)
            target=out/room/(name+'.ogv');target.parent.mkdir(parents=True,exist_ok=True)
            if name=='RUNES2_':
                staged=stage_patch(source,target,record)
            else:
                convert(source,target)
                # Decode the converted stream and count actual frames, not container estimates.
                probe=subprocess.run(['ffprobe','-v','error','-count_frames','-select_streams','v:0','-show_entries','stream=width,height,nb_read_frames','-of','json',str(target)],check=True,capture_output=True,text=True)
                stream=json.loads(probe.stdout)['streams'][0]
                assert [stream['width'],stream['height'],int(stream['nb_read_frames'])]==[record['width'],record['height'],record['frames']]
                still=target.with_suffix('.png')
                subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-frames:v','1',str(still)],check=True)
                staged=dict(record,path='res://'+str(target.relative_to(ROOT)),still='res://'+str(still.relative_to(ROOT)),duration=record['frames']/record['fps'])
            clips[name]=staged;sources.append(dict(room=room,**record))
        manifest['rooms'][room]=dict(background=clips[room+'_'],movies=[],clips=clips,hotspots=audit['rooms'][room]['hotspots'])
    (out/'rooms.json').write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest,sources

def main():
    audit=json.loads((ROOT/'docs/hive-rune-room-source.json').read_text())
    manifest,sources=stage_rooms(audit)
    report=dict(archives={r:audit['rooms'][r]['archive_sha256'] for r in manifest['rooms']},media=sources,total_frames=sum(c['frames'] for c in sources),scope=__doc__.split('\n\n')[0],limits='Assets staged, not live room admission or effect execution. RUNES1_/RUNES4_ state selection still needs setup/host callback binding. Numeric speech requests are not present under tested room-local VQA/AUD names and remain unstaged. Full-frame VQA conversion follows existing room converter; transparent RUNES2_ uses recovered vector decoder.')
    (ROOT/'docs/hive-rune-media-checks.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS',len(sources),'source rune-room clips;',report['total_frames'],'decoded frames verified')

# ---- explicit inputs -------------------------------------------------------------------------------------------------
RECIPE_SHA256='4f2f3c75fc68d3afe0400f04d7944d9e161c0fb4912951c252333ed94c3749e8'  # scripts/lol2/hive_rune_rooms_source.json
ORIGINALS={'RUNES':'095a7e016786edb83ca9b83ad15f174d3ff7a1848f444281fd471b52f435c4dd',
           'RUNECL':'a2b8b1c5dfd9b43c9e105f29c12761df02ad579fa76b2f386a97ac7678001067'}

def verify(game,recipe):
    assert list(recipe['rooms'])==[room for room,_ in CLIPS],'recipe rooms'
    for room,names in CLIPS:
        data=recipe['rooms'][room];archive=(game/'DAT'/f'{room}.MIX').read_bytes()
        assert digest(archive)==data['archive_sha256']==ORIGINALS[room],f'{room}.MIX is not the recorded original'
        assert extract(archive,f'WOMS\\{room}_.WOM')[1]==data['dll'],f'{room} DLL binding'
        assert data['hotspots'] and all(h['kind']=='hotspot' and len(h['args'])==5 for h in data['hotspots']),f'{room} hotspots'
        for name in names: movie(archive,f'WOMS\\{room}\\{name}.VQA')

def cli():
    global ROOT,GAME,convert
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game','re-root','recipe','output-root']: p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for tool in ['ffmpeg','ffprobe']:
        if shutil.which(tool) is None: p.error(tool+' not found on PATH')
    codecs=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
    for codec in ['libtheora','libvorbis','vqavideo','pcm_s16le',' png ']:
        if codec not in codecs: p.error('ffmpeg lacks '+codec.strip())
    try: converter=monastery_media.load_converter(a.re_root)
    except ValueError as error: p.error(str(error))
    if not a.recipe.is_file(): p.error('Missing input: '+str(a.recipe))
    if digest(a.recipe.read_bytes())!=RECIPE_SHA256: p.error(f'{a.recipe}: not the pinned Hive rune-rooms recipe ({RECIPE_SHA256})')
    recipe=json.loads(a.recipe.read_text())
    for room in ORIGINALS:
        if not (a.game/'DAT'/f'{room}.MIX').is_file(): p.error('Missing original '+str(a.game/'DAT'/f'{room}.MIX'))
    try: verify(a.game,recipe)
    except (AssertionError,StopIteration,KeyError,ValueError,IndexError,TypeError) as error:
        p.error('Originals do not match the recorded inputs: '+(str(error) or type(error).__name__))
    convert=converter;GAME=a.game.resolve();ROOT=a.output_root.resolve()
    manifest,sources=stage_rooms(recipe)
    print('PASS explicit Hive rune rooms:',len(sources),'clips,',sum(c['frames'] for c in sources),'frames')

if __name__=='__main__':
    if EXPLICIT: cli()
    else: main()
