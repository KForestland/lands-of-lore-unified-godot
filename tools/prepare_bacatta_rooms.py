#!/usr/bin/env python3
"""Stage the village/Bacatta room media using the recovered room decoder.

Explicit inputs (fresh output root; every input and original is checked before anything is written):
  python3 tools/prepare_bacatta_rooms.py --game GAME --re-root RE --recipe scripts/lol2/bacatta_rooms_source.json \
      --output-root FRESH
The compact recipe carries the consumed records of the recorded room audit; every record and DLL binding is re-verified
against the original CAN/VILLAGE archives. Published helpers only (tools/monastery_media.py); the RE checkout supplies
only the pinned video converter. No audit runs and no docs are written. Without arguments the historical behaviour
(audit_bacatta_rooms first, docs/bacatta-room-source.json) is unchanged, and importing this module (stage_intro, as
prepare_liz_room_media does) keeps the historical imports.
"""
import json
import subprocess
import sys
import wave
import struct
from pathlib import Path
EXPLICIT=__name__=='__main__' and len(sys.argv)>1
if EXPLICIT:
    import argparse,shutil
    import monastery_media
    from monastery_media import extract,digest,movie,parse_vqa_chunks
    from PIL import Image
    ROOT=GAME=convert=None  # set by cli()

    def stage_patch(source,target,record):
        return monastery_media.stage_patch(source,target,record,ROOT)
else:
    from audit_bacatta_rooms import main as audit
    from audit_monastery_rooms import ROOT, GAME, extract, digest
    from prepare_monastery_rooms import stage_patch, convert, Image, parse_vqa_chunks


def stage_intro(source,target,record):
    width,height=record['width'],record['height']
    raw=source.with_suffix('.rgba')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-an','-pix_fmt','rgba','-f','rawvideo',str(raw)],check=True)
    assert raw.stat().st_size==width*height*4*record['frames']
    atlases=[]
    with raw.open('rb') as stream:
        for frame in range(record['frames']):
            if frame%16==0: sheet=Image.new('RGBA',(width*4,height*4))
            image=Image.frombytes('RGBA',(width,height),stream.read(width*height*4))
            sheet.paste(image,((frame%4)*width,((frame%16)//4)*height))
            if frame%16==15 or frame==record['frames']-1:
                png=target.with_name(target.stem+f'_{len(atlases):03d}.png');sheet.save(png)
                atlases.append('res://'+str(png.relative_to(ROOT)))
    audio=target.with_suffix('.wav')
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-vn','-ac','1','-c:a','pcm_s16le',str(audio)],check=True)
    expected=sum(len(d)*2 for t,d in parse_vqa_chunks(source.read_bytes()) if t==b'SND2')
    with wave.open(str(audio)) as w: assert w.getnframes()==expected
    raw.unlink()
    return dict(record,kind='movie',atlases=atlases,columns=4,rows=4,audio='res://'+str(audio.relative_to(ROOT)),audio_samples=expected,duration=max(record['frames']/15,expected/22050))


def stage_rooms(report):
    root=ROOT/'assets/lol2/generated/bacatta_rooms'
    cache=ROOT/'tmp/bacatta_source'
    cache.mkdir(parents=True,exist_ok=True)
    manifest=dict(version=1,canvas=[640,400],rooms={})
    for room,data in report['rooms'].items():
        archive=(GAME/'DAT'/f'{room}.MIX').read_bytes()
        assert digest(archive)==data['archive_sha256']
        staged=[]
        for record in [data['background']]+data.get('media',[])+data.get('exit_media',[]):
            name=record['name'].split('\\')[-1]
            payload,binding=extract(archive,record['name'])
            assert binding['sha256']==record['sha256']
            source=cache/name
            source.write_bytes(payload)
            target=root/room/(Path(name).stem+'.ogv')
            target.parent.mkdir(parents=True,exist_ok=True)
            if record is data['background']:
                convert(source,target)
                staged.append(dict(record,path='res://'+str(target.relative_to(ROOT))))
            elif record['kind']=='audio_only':
                audio=target.with_suffix('.wav')
                subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-ac','1','-c:a','pcm_s16le',str(audio)],check=True)
                rate,compressed,decoded,flags,codec=struct.unpack_from('<HIIBB',payload)
                with wave.open(str(audio)) as w:
                    assert w.getframerate()==rate and w.getnframes()*w.getsampwidth()==decoded
                    samples=w.getnframes()
                staged.append(dict(record,audio='res://'+str(audio.relative_to(ROOT)),audio_samples=samples,duration=samples/rate,frames=0,fps=15))
            else:
                staged.append(stage_patch(source,target,record))
        manifest['rooms'][room]=dict(background=staged[0],movies=staged[1:1+len(data.get('media',[]))],exit_movies=staged[1+len(data.get('media',[])):],calls=data.get('first_visit_calls',[]))
        if 'idle' in data:
            record=data['idle']
            payload,_=extract(archive,record['name'])
            source=cache/'1399906E.VQA';source.write_bytes(payload)
            manifest['rooms'][room]['idle']=stage_patch(source,root/room/'1399906E.ogv',record)
        if 'intro' in data:
            record=data['intro']
            payload,_=extract(archive,record['name'])
            source=cache/'TAVERN.VQA';source.write_bytes(payload)
            target=root/room/'TAVERN.ogv'
            convert(source,target)
            manifest['rooms'][room]['movies']=[stage_intro(source,target,record)]

    (root/'rooms.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS: 2 backgrounds, tavern intro, Bacatta idle,10 speech movies and6 audio-only lines staged')


def main():
    audit()
    report=json.loads((ROOT/'docs/bacatta-room-source.json').read_text())
    stage_rooms(report)


# ---- explicit inputs -------------------------------------------------------------------------------------------------
RECIPE_SHA256='1d8a4db9a4a86e4f8d7367962c2258b89097ad89b75b6e9e95311bdd90be39fe'  # scripts/lol2/bacatta_rooms_source.json
ORIGINALS={'CAN':'55395c6cfa2f846f4edb360877ab9c68002dce1367a5109624e1c3feba634675',
           'VILLAGE':'497fa122ad5c48dbbd6f651f826f57383436a3962cd67d4b175ffd636a25548b'}

def verify(game,recipe):
    """Every consumed record re-derived from the originals; no writes."""
    rooms=recipe['rooms'];assert list(rooms)==['CAN','VILLAGE'],'recipe rooms'
    for room,data in rooms.items():
        archive=(game/'DAT'/f'{room}.MIX').read_bytes()
        assert digest(archive)==data['archive_sha256'],f'{room}.MIX is not the recorded original'
        assert data['archive_sha256']==ORIGINALS[room],room
        assert extract(archive,f'WOMS\\{room}_.WOM')[1]==data['dll'],f'{room} DLL binding'
        for key in ['background','idle','intro']:
            if key in data: assert movie(archive,data[key]['name'])==data[key],data[key]['name']
        for calls,media in [('first_visit_calls','media'),('exit_calls','exit_media')]:
            if media not in data:continue
            names=[f"WOMS\\{room}\\{c['args'][0]:02d}{c['args'][1]:03d}{c['args'][2]:02d}E."+('AUD' if c['args'][0]==1 else 'VQA') for c in data[calls] if c['kind'].startswith('movie')]
            assert names==[m['name'] for m in data[media]],f'{room} {media} names differ from recorded calls'
            for record in data[media]:
                want=dict(movie(archive,record['name']),kind='movie') if record['kind']=='movie' else dict(extract(archive,record['name'])[1],kind='audio_only')
                assert want==record,record['name']

def cli():
    global ROOT,GAME,convert
    p=argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game','re-root','recipe','output-root']: p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for tool in ['ffmpeg','ffprobe']:
        if shutil.which(tool) is None: p.error(tool+' not found on PATH')
    codecs=subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
    for codec in ['libtheora','libvorbis','vqavideo','pcm_s16le','rawvideo','adpcm_ima_ws']:
        if codec not in codecs: p.error('ffmpeg lacks '+codec)
    try: converter=monastery_media.load_converter(a.re_root)
    except ValueError as error: p.error(str(error))
    if not a.recipe.is_file(): p.error('Missing input: '+str(a.recipe))
    if digest(a.recipe.read_bytes())!=RECIPE_SHA256: p.error(f'{a.recipe}: not the pinned bacatta rooms recipe ({RECIPE_SHA256})')
    recipe=json.loads(a.recipe.read_text())
    for room in ORIGINALS:
        if not (a.game/'DAT'/f'{room}.MIX').is_file(): p.error('Missing original '+str(a.game/'DAT'/f'{room}.MIX'))
    try: verify(a.game,recipe)
    except (AssertionError,StopIteration,KeyError,ValueError,IndexError,struct.error) as error:
        p.error('Originals do not match the recorded inputs: '+(str(error) or type(error).__name__))
    convert=converter;GAME=a.game.resolve();ROOT=a.output_root.resolve()
    stage_rooms(recipe)

if __name__=='__main__':
    if EXPLICIT: cli()
    else: main()
