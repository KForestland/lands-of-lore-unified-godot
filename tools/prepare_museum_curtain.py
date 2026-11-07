#!/usr/bin/env python3
"""Pin the Museum curtain (static assembly / control81) as a source contract and stage its media.

Owner witness 2026-10-20 (original game): a fire/dragon tapestry hangs across the doorway at x -3820.
Source (L3_DH): static placement81, template60, (-3820, height 1, native y 1084), heading 16384. Template60 has three
type0 children on face2 selected by the assembly mode byte [obj+0x3d] (renderer test 0x5E156 `mask & (1 << mode)`):
child149 mask1 = descriptor181 (closed), child150 mask2 = descriptor61 (8-phase group 61-68, the drawing animation),
child148 mask4 = descriptor180 (gathered). The constructor sets mode 0 (0x5B66A). Control81 is this assembly; opcode5
on kind16 reaches vtable+0xB0 = 0x5D510, which stores the new mode byte.
Control81 records (stream1): kind4 value0 (empty-hand use) and kind6 value2, each under predicate14 (owner state 0) and
predicate15 (owner state 1). Groups and predicates are asserted byte for byte.
Usage: prepare_museum_curtain.py --game GAME --re-root RE [--project PROJECT]
Writes PROJECT/scripts/lol2/museum_curtain_source.json and PROJECT/assets/lol2/generated/museum_curtain/.
"""
import argparse, hashlib, json, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = {'file': 'DAT/L3_DH.MIX', 'sha256': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac', 'geometry_key': 3106551060,
          'geometry_sha256': 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'}
CONTROL = 81
PLACEMENT_OFFSET = 5870978
PLACEMENT_HEX = '14f13c040040010082049804c60d7f00000000000100000000000000140034003c'
GROUPS = {
    'open_use': (7036, 4, 0, 14, 5851034, ['091051000e00', '051051000100', '071051000000', '141051005b0180000a14', '091051000800']),
    'open_end': (7076, 6, 2, 14, 5851048, ['051051000200', '101051000100', '091051000d00']),
    'close_use': (7100, 4, 0, 15, 5851058, ['091051000e00', '051051000100', '071051000300', '071051000800', '071051000000', '141051005a0180000a14', '091051000700']),
    'close_end': (7152, 6, 2, 15, 5851072, ['091051000d00', '071051000700', '051051000000', '101051000000']),
}
PREDICATES = {14: '0005000000', 15: '0005000001'}
SOUNDS = {347: 'open', 346: 'close'}
# Descriptor images from the L3_DH material export (mip0 palette images; descriptor61 variants are the group frames).
IMAGES = {
    'material_0181/mip_0_palette.png': 'closed.png',
    'material_0180/mip_0_palette.png': 'gathered.png',
    **{f'material_0061/variant_{i}.png': f'drawing_{i}.png' for i in range(8)},
}
FOLDER = 'museum_curtain'

def sha(raw): return hashlib.sha256(raw).hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--re-root', type=Path, required=True)
    p.add_argument('--project', type=Path, default=ROOT)
    p.add_argument('--print-hashes', action='store_true', help='Print image/audio hashes instead of checking pins')
    a = p.parse_args()
    game = a.game.resolve()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from build_game_atlas import parse_mix, section
    from audit_game_transition_owners import collect_owners
    from audit_game_actor_scripts import groups
    from prepare_jungle_exit_encounter import predicate
    from prepare_creature_audio_clips import stage_clips
    from lol2 import map_materials
    archive = (game / SOURCE['file']).read_bytes()
    if sha(archive) != SOURCE['sha256']: raise SystemExit('Wrong L3_DH archive')
    entry = next(e for e in parse_mix(archive) if e['key'] == SOURCE['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    if sha(raw) != SOURCE['geometry_sha256']: raise SystemExit('Wrong L3_DH geometry')
    if archive[PLACEMENT_OFFSET:PLACEMENT_OFFSET + len(PLACEMENT_HEX) // 2].hex() != PLACEMENT_HEX: raise SystemExit('Curtain placement changed')
    _, region_count, _ = section(raw, 12, 0x58, 44)
    owners, _ = collect_owners(raw, entry['offset'], region_count)
    parsed = {}
    for stream, (of, sf) in enumerate([(0x3c, 0x84), (0x44, 0x8c)]):
        _, _, blob = section(raw, of, sf, 1)
        for offset, commands in groups(blob): parsed[(stream, offset)] = [body.hex() for _, body in commands]
    mine = sorted((o['group'], o['event'], o['value'], o['predicate'], o['archive_offset']) for o in owners
                  if o['owner_kind'] == 'control' and o['owner'] == CONTROL)
    assert mine == sorted(g[:5] for g in GROUPS.values()), mine
    for name, (group, *_rest, commands) in GROUPS.items():
        assert parsed[(1, group)] == commands, (name, parsed[(1, group)])
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    for n, hexed in PREDICATES.items():
        pred = predicate(table, n)
        assert pred['raw'] == hexed and pred['op'] == '==' and pred['left'] == {'owner_state': True}, pred
    with tempfile.TemporaryDirectory(prefix='museum-curtain-') as temp:
        h = Path(temp)
        map_materials.export_materials(game, 'L3_DH', h / 'materials')
        subprocess.run([sys.executable, str(ROOT / 'tools/export_map_movables.py'), '--game-root', str(game), '--material-root', str(h / 'materials'),
                        '--re-root', str(a.re_root), '--tools-root', str(ROOT / 'tools'), '--area', 'L3_DH', '--placement-kind', 'static_assembly',
                        '--out', str(h / 'assemblies')], check=True, stdout=subprocess.DEVNULL)
        data = json.loads((h / 'assemblies/movables.json').read_text())
        placement = [x for x in data['placements'] if x['source_index'] == CONTROL]
        assert len(placement) == 1 and placement[0]['placement_hex'] == PLACEMENT_HEX and placement[0]['template'] == 60, placement
        rows = [f for f in data['faces'] + data['state_faces'] if f['source_index'] == CONTROL]
        by_mask = {int(f['child_mask']): f for f in rows}
        assert len(rows) == 3 and sorted(by_mask) == [1, 2, 4], rows
        assert [by_mask[m]['resource_id'] for m in (1, 2, 4)] == [181, 61, 180]
        for f in rows: assert f['points'] == rows[0]['points'] and f['uv'] == [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]], f
        materials_root = Path(data['materials_root'])
        out = a.project.resolve() / 'assets/lol2/generated' / FOLDER
        staged = h / 'staged'; staged.mkdir()
        images = {}
        for src, dest in IMAGES.items():
            content = (materials_root / src).read_bytes()
            images[dest] = sha(content)
            (staged / dest).write_bytes(content)
        if a.print_hashes: print(json.dumps(images, indent=1))
        elif images != PINNED_IMAGES: raise SystemExit('Curtain images changed')
        assert images['drawing_0.png'] == images['closed.png'] and images['drawing_7.png'] == images['gathered.png']
        clips = stage_clips(h, FOLDER, list(SOUNDS), game=game)
        audio = {}
        for request, row in clips.items():
            shutil.copyfile(h / 'assets/lol2/generated' / FOLDER / (str(request) + '.wav'), staged / (str(request) + '.wav'))
            audio[str(request)] = {'path': f'res://assets/lol2/generated/{FOLDER}/{request}.wav', 'wav_sha256': row['wav_sha256'], 'role': SOUNDS[int(request)]}
        if out.exists(): shutil.rmtree(out)
        shutil.copytree(staged, out)
    contract = {
        'version': 1, 'source': SOURCE, 'control': CONTROL,
        'placement': {'offset': PLACEMENT_OFFSET, 'hex': PLACEMENT_HEX, 'x': placement[0]['x'], 'y': placement[0]['y'],
                      'height': placement[0]['height'], 'heading': placement[0]['heading'], 'template': 60},
        'points': rows[0]['points'], 'uv': rows[0]['uv'],
        'modes': {'0': {'mask': 1, 'resource': 181, 'image': 'closed.png'}, '1': {'mask': 2, 'resource': 61, 'frames': [f'drawing_{i}.png' for i in range(8)]},
                  '2': {'mask': 4, 'resource': 180, 'image': 'gathered.png'}},
        'groups': {name: {'group': g[0], 'event': g[1], 'value': g[2], 'predicate': g[3], 'archive_offset': g[4], 'commands': g[5]} for name, g in GROUPS.items()},
        'predicates': {str(k): v for k, v in PREDICATES.items()},
        'sounds': {'open': 347, 'close': 346},
        'images': {k: v for k, v in images.items()}, 'audio': audio,
        'root': f'res://assets/lol2/generated/{FOLDER}/',
        'not_hosted': ['op9 control81 properties 14/8/13/7', 'op7 sub-commands 0/3/8/7 (read as presentation: play forward on open, reverse on close)'],
    }
    path = a.project.resolve() / 'scripts/lol2/museum_curtain_source.json'
    path.write_text(json.dumps(contract, indent=1) + '\n')
    print('PASS museum curtain contract', path)

PINNED_IMAGES = {
    'closed.png': 'be044abf7eb3050c9bf78775d6d4d130b6106dc4575adc7de5642456d9596102',
    'gathered.png': '02a0ca5641dd731e943f44db01264ff144bb76e8dbb70e5f88686b6dc28a06a8',
    'drawing_0.png': 'be044abf7eb3050c9bf78775d6d4d130b6106dc4575adc7de5642456d9596102',
    'drawing_1.png': '8aea975721ee7f0cb84cf15f14ad6e089bdfa2d469941464f8392863d78b3808',
    'drawing_2.png': '437b1d76e9428804e8b67377eae80ed3bbc3b58d5089f920b9ac55ea8a5595d6',
    'drawing_3.png': '0278a9c1b6dc48cdeec98673fea86285f810087f067a15f39facbc5e558af9f1',
    'drawing_4.png': '3680e20b5f864545a7df7ce620f3c426ec80354ddf6377fff37ca05d09e36ef3',
    'drawing_5.png': 'f5fc7a355f7451b475ddee11e65e919ba703ee24d88f707459ba1cd271542b98',
    'drawing_6.png': '2fee9043b71f3c0d7e64448f82652f9597fd777069b317ced16628582204f81b',
    'drawing_7.png': '02a0ca5641dd731e943f44db01264ff144bb76e8dbb70e5f88686b6dc28a06a8',
}
# The group runs from the closed image (frame0 == descriptor181) to the gathered one (frame7 == descriptor180).

if __name__ == '__main__':
    main()
