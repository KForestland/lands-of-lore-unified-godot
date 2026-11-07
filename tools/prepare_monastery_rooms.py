#!/usr/bin/env python3
"""Stage source-bound monastery backgrounds and speech patches for Godot.

Explicit inputs (fresh output root; every input and recorded source is checked before anything is written):
  python3 tools/prepare_monastery_rooms.py --game GAME --re-root RE --recipe scripts/lol2/monastery_rooms_source.json \
      --offer-source docs/monastery-offer-responses-source.json --attack-source docs/mlib-dawn-attack-checks.json \
      --dawn-runes-source docs/monastery-dawn-runes-source.json --output-root FRESH
The explicit path stages the complete assets/lol2/generated/monastery_rooms pack (first visits plus the MOFF rune/refusal/
orb and MLIB attack/exit-runes clips of the dependent preparers) from the pinned original MIX archives, the compact
recipe (consumed fields of the recorded room/rune audits, with their limits) and the published offer/attack/dawn-runes
results, through tools/monastery_media.py (published decoders only). The RE checkout supplies only the pinned video
converter. It runs no native audit and writes no docs. Without arguments, or when imported, the historical
repository-root behaviour (native audits first, legacy decoders) is unchanged.
"""
import json
import subprocess
import sys
from pathlib import Path
import monastery_media
EXPLICIT = __name__ == '__main__' and len(sys.argv) > 1
if EXPLICIT:
    import argparse, shutil
    from monastery_media import digest, extract, movie, parse_vqa_chunks, lcw
    ROOT = GAME = convert = None  # set by cli()
    PINNED = {'MENT': '82e11faf2a4922922048fe446d5b665c70612d709ad689a85fd59c91525478e4', 'MLIB': '507f68e917665df64430a1bac2ec5267af1597ace5aabf9218c86d9861044f94', 'MOFF': '642956adf4ee24c7bf3230ef7521ebcc419a9a076e4674692c8ba3bf63fc2a45'}
else:
    from audit_monastery_rooms import ROOT, GAME, PINNED, digest, extract, main as audit
    sys.path.insert(0, '~/lol2_re_publish_20260911/tools')
    from convert_cave_video_review import convert
    from lol2_vqa_decode import parse_vqa_chunks
    sys.path.insert(0, "~/lol2_re_publish_20260911/tools/draracle")
    from extract_block_sprite_frames import lcw
from decode_monastery_vectors import decode_vectors
from PIL import Image
import struct
import wave


def stage_patch(source, target, record):
    # Body lives in monastery_media; this module's decoders and ROOT are passed at call time (legacy: the RE decoders).
    return monastery_media.stage_patch(source, target, record, ROOT, chunks=parse_vqa_chunks, decompress=lcw)


def main(report=None, dependents=None):
    if report is None:
        audit()
        report = json.loads((ROOT/'docs/monastery-room-source.json').read_text())
    out = ROOT/'assets/lol2/generated/monastery_rooms'
    cache = ROOT/'tmp/monastery_source'
    cache.mkdir(parents=True, exist_ok=True)
    manifest = dict(version=1, canvas=[640,400], rooms={})
    for room, data in report['rooms'].items():
        archive = (GAME/'DAT'/f'{room}.MIX').read_bytes()
        assert digest(archive) == PINNED[room]
        staged = []
        for record in [data['background']]+data['first_visit_movies']:
            name = record['name'].split('\\')[-1]
            source = cache/name
            payload, binding = extract(archive, record['name'])
            assert binding['sha256'] == record['sha256']
            source.write_bytes(payload)
            target = out/room/(Path(name).stem+'.ogv')
            if record is data['background']:
                convert(source,target)
                staged.append(dict(record, path='res://'+str(target.relative_to(ROOT)), duration=record['frames']/record['fps']))
            else:
                staged.append(stage_patch(source,target,record))
        png = out/room/'background.png'
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(cache/(room+'_.VQA')),'-frames:v','1',str(png)],check=True)
        manifest['rooms'][room] = dict(background=staged[0], background_still='res://'+str(png.relative_to(ROOT)),
            movies=staged[1:], calls=data['first_visit_calls'])
    (out/'rooms.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS: staged 38 speech atlases/audio tracks and 3 animated room backgrounds; original assets stay local.')
    if dependents is not None:
        return dependents()
    from prepare_monastery_rune_offer import main as stage_rune_offer
    stage_rune_offer()


# ---- explicit inputs -------------------------------------------------------------------------------------------------
VECTORS_SHA256 = '20c771b1d1a5afdabb5f38cf276abaa3019484929db7e551a15baa565b8c1f8e'  # tools/decode_monastery_vectors.py
RECIPE_SHA256 = '6a8d0f25594a2c603f6605c34fcd1d4bc45e0788e9fed3add1be25a266d9a320'  # scripts/lol2/monastery_rooms_source.json
# Published recorded native results (d6bff86 docs/*.json).
CONTRACTS = {'offer_source': '885fac1a1fec16e17956c2f7a44daedd42884ab0a4466bd0d95b03ceca0530a6',
             'attack_source': 'f512d2a80df2f23a95a0ac8d266a6bd5635df115671a131f29a78fd6d93fcc90',
             'dawn_runes_source': 'df02ac146cc831d784933ee78a06e6437b2f675535594a2bb24cf5de9700ce7f'}
OFFER_LINES = [('refusal_movies', [378, 379]), ('orb_movies', [375, 376, 377])]  # prepare_monastery_offers.py
DAWN_LINES = [663, 664, 665, 666, 667, 668]  # prepare_monastery_dawn_runes.MOVIES


def plan(game, recipe, contracts):
    """Every clip of the pack as (field, room, entry name, record), checked against the originals; no writes."""
    archives = {room: (game/'DAT'/f'{room}.MIX').read_bytes() for room in PINNED}
    for room, archive in archives.items():
        assert digest(archive) == PINNED[room], f'{room}.MIX is not the pinned original'
    rooms = recipe['rooms']
    assert list(rooms) == ['MENT', 'MLIB', 'MOFF'], 'Recipe rooms differ'
    for room, data in rooms.items():
        assert data['archive_sha256'] == PINNED[room] and extract(archives[room], f'WOMS\\{room}_.WOM')[1] == data['dll'], room
        names = [f"WOMS\\{room}\\{c['args'][0]:02d}{c['args'][1]:03d}{c['args'][2]:02d}E.VQA" for c in data['first_visit_calls'] if c['kind'].startswith('movie')]
        assert names == [m['name'] for m in data['first_visit_movies']], f'{room} first-visit movies differ from recorded calls'
        for record in [data['background']]+data['first_visit_movies']:
            assert movie(archives[room], record['name']) == record, record['name']
    rune, offer, attack, dawn = recipe['rune_offer'], contracts['offer_source'], contracts['attack_source'], contracts['dawn_runes_source']
    moff_dll, mlib_dll = (extract(archives[r], f'WOMS\\{r}_.WOM')[1] for r in ['MOFF', 'MLIB'])
    assert rune['archive_sha256'] == offer['archive_sha256'] == PINNED['MOFF'] and rune['dll'] == offer['dll'] == moff_dll, 'MOFF records differ'
    assert attack['passed'] and attack['dll_sha256'] == dawn['dll']['sha256'] == mlib_dll['sha256'] and dawn['dll'] == mlib_dll, 'MLIB records differ'
    clips = []
    for record in rune['translation_movies']:
        assert movie(archives['MOFF'], record['name']) == record, record['name']
        clips.append(('rune_movies', 'MOFF', record['name'], record))
    for field, lines in OFFER_LINES:
        assert [m['name'] for m in offer['media'][field]] == [f'WOMS\\MOFF\\22{line:03d}07E.VQA' for line in lines], field
        clips += [(field, 'MOFF', f'WOMS\\MOFF\\22{line:03d}07E.VQA', movie(archives['MOFF'], f'WOMS\\MOFF\\22{line:03d}07E.VQA')) for line in lines]
    first = next(c for c in attack['cases'] if c['message']==7 and c['present'] and not c['guard'] and c['flags']=={'190':0,'191':0})
    movies = [e for e in first['effects'] if e[0]=='movie']
    assert movies == [['movie',3,773,7]], movies
    clips.append(('MLIB_ATTACK', 'MLIB', 'WOMS\\MLIB\\0377307E.VQA', movie(archives['MLIB'], 'WOMS\\MLIB\\0377307E.VQA')))
    assert [m['line'] for m in dawn['movies']] == DAWN_LINES, 'Dawn-runes movie lines differ'
    clips += [('MLIB_EXIT_RUNES', 'MLIB', 'WOMS\\MLIB\\03%03d07E.VQA' % line, movie(archives['MLIB'], 'WOMS\\MLIB\\03%03d07E.VQA' % line)) for line in DAWN_LINES]
    for field, room, name, record in clips:
        assert extract(archives[room], name)[1]['sha256'] == record['sha256'], name
    return archives, clips


def stage_dependents(archives, clips, contracts):
    """The media steps of prepare_monastery_rune_offer/offers/library_attack/dawn_runes, in that (manifest key) order,
    from recorded native results instead of their native replays. Dampen icon and docs reports are not part of this pack."""
    out = ROOT/'assets/lol2/generated/monastery_rooms'
    cache = ROOT/'tmp/monastery_source'
    path = out/'rooms.json'
    manifest = json.loads(path.read_text())
    moff, mlib = manifest['rooms']['MOFF'], manifest['rooms']['MLIB']
    for field, room, name, record in clips:
        payload, binding = extract(archives[room], name)
        assert binding['sha256'] == record['sha256']
        source = cache/name.split('\\')[-1]
        source.write_bytes(payload)
        clip = stage_patch(source, out/room/(source.stem+'.ogv'), record)
        if field == 'MLIB_EXIT_RUNES':
            clip['line'] = int(source.stem[2:5])
        if field.startswith('MLIB_'):
            mlib.setdefault('sequences', {}).setdefault(field, []).append(clip)
        else:
            moff.setdefault(field, []).append(clip)
    assert {field: moff[field] for field, _ in OFFER_LINES} == contracts['offer_source']['media'], 'Offer clips differ from the published record'
    assert [dict(line=c['line'], frames=c['frames'], samples=c['audio_samples']) for c in mlib['sequences']['MLIB_EXIT_RUNES']] == contracts['dawn_runes_source']['movies'], 'Dawn-runes clips differ from the published record'
    path.write_text(json.dumps(manifest,indent=2)+'\n')
    print('PASS dependents', {k: len(v) for k, v in [('rune_movies', moff['rune_movies'])]+[(f, moff[f]) for f, _ in OFFER_LINES]+list(mlib['sequences'].items())})


def cli():
    global ROOT, GAME, convert
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 're-root', 'recipe', 'offer-source', 'attack-source', 'dawn-runes-source', 'output-root']:
        p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    for tool in ['ffmpeg', 'ffprobe']:
        if shutil.which(tool) is None: p.error(tool + ' not found on PATH')
    codecs = subprocess.run(['ffmpeg','-hide_banner','-encoders'],capture_output=True,text=True).stdout+subprocess.run(['ffmpeg','-hide_banner','-decoders'],capture_output=True,text=True).stdout
    for codec in ['libtheora', 'libvorbis', 'vqavideo', 'pcm_s16le', ' png ']:
        if codec not in codecs: p.error('ffmpeg lacks ' + codec.strip())
    try:
        converter = monastery_media.load_converter(a.re_root)
    except ValueError as error:
        p.error(str(error))
    vectors = Path(sys.modules['decode_monastery_vectors'].__file__)
    if digest(vectors.read_bytes()) != VECTORS_SHA256: p.error(f'{vectors}: not the pinned vector decoder')
    if not a.recipe.is_file(): p.error('Missing input: ' + str(a.recipe))
    if digest(a.recipe.read_bytes()) != RECIPE_SHA256: p.error(f'{a.recipe}: not the pinned monastery rooms recipe ({RECIPE_SHA256})')
    recipe = json.loads(a.recipe.read_text())
    contracts = {}
    for key, want in CONTRACTS.items():
        path = getattr(a, key)
        if not path.is_file(): p.error('Missing input: ' + str(path))
        if digest(path.read_bytes()) != want: p.error(f'{path}: not the pinned recorded {key.replace("_", "-")} ({want})')
        contracts[key] = json.loads(path.read_text())
    for room in PINNED:
        if not (a.game/'DAT'/f'{room}.MIX').is_file(): p.error('Missing original ' + str(a.game/'DAT'/f'{room}.MIX'))
    try:
        archives, clips = plan(a.game, recipe, contracts)
    except AssertionError as error:
        p.error('Original archives do not match the recorded sources: ' + str(error))
    convert = converter
    GAME = a.game.resolve(); ROOT = a.output_root.resolve()
    main(recipe, lambda: stage_dependents(archives, clips, contracts))

if __name__ == '__main__':
    if EXPLICIT: cli()
    else: main()
