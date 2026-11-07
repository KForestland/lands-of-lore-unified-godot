#!/usr/bin/env python3
"""Pin the Museum wheel door (static assembly / control80) as a source contract and stage its media.

Longplay 19:02-19:06 (deep dive museum REFERENCE): behind the curtain (control81) the player clicks the marble wall,
which swirls into a round vortex and vanishes, opening a dark passage.
Source (L3_DH): static placement80, template61, (-3809, height 0, native y 1091), heading 49152. Template61 child151 is
a 12 x 70 x 85 box across the doorway: west face resource138 (40-phase group, marble -> vortex -> transparent index 0),
east face resource227, other faces resource31. Control80 records (stream1, no predicate): kind4 value0 (empty-hand use)
-> g7008 [op7 control80 sub0 (play the phase group), op0x14 sound342]; kind6 value2 (end of the group) -> g7030
[op9 control80 property2 (B49EC unlink: the assembly is removed)]. Groups are asserted byte for byte.
Usage: prepare_museum_wheel_door.py --game GAME --re-root RE [--project PROJECT] [--print-hashes]
Writes PROJECT/scripts/lol2/museum_wheel_door_source.json and PROJECT/assets/lol2/generated/museum_wheel_door/.
"""
import argparse, hashlib, json, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = {'file': 'DAT/L3_DH.MIX', 'sha256': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac', 'geometry_key': 3106551060,
          'geometry_sha256': 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'}
CONTROL = 80
TEMPLATE = 61
PLACEMENT_OFFSET = 5870945
PLACEMENT_HEX = '1ff1430400c000008204d004b40d7f00000000000100000000000000140030003d'
GROUPS = {
    'use': (7008, 4, 0, None, 5851016, ['071050000000', '14105000560180000a14']),
    'end': (7030, 6, 2, None, 5851026, ['091050000200']),
}
SOUND = 342
FRAMES = 40
# Resource per face index of child151 (0 top, 1 bottom, 2 east, 3 west, 4/5 ends).
FACE_RESOURCES = [31, 31, 227, 138, 31, 31]
FOLDER = 'museum_wheel_door'

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
    from prepare_creature_audio_clips import stage_clips
    from lol2 import map_materials
    archive = (game / SOURCE['file']).read_bytes()
    if sha(archive) != SOURCE['sha256']: raise SystemExit('Wrong L3_DH archive')
    entry = next(e for e in parse_mix(archive) if e['key'] == SOURCE['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    if sha(raw) != SOURCE['geometry_sha256']: raise SystemExit('Wrong L3_DH geometry')
    if archive[PLACEMENT_OFFSET:PLACEMENT_OFFSET + len(PLACEMENT_HEX) // 2].hex() != PLACEMENT_HEX: raise SystemExit('Wheel door placement changed')
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
    # No other group in either stream addresses control80 (opcode target bytes 50 10).
    others = [k for k, c in parsed.items() if any(h[2:6] == '5010' for h in c) and k[1] not in (7008, 7030)]
    assert not others, others
    with tempfile.TemporaryDirectory(prefix='museum-wheel-door-') as temp:
        h = Path(temp)
        map_materials.export_materials(game, 'L3_DH', h / 'materials')
        subprocess.run([sys.executable, str(ROOT / 'tools/export_map_movables.py'), '--game-root', str(game), '--material-root', str(h / 'materials'),
                        '--re-root', str(a.re_root), '--tools-root', str(ROOT / 'tools'), '--area', 'L3_DH', '--placement-kind', 'static_assembly',
                        '--out', str(h / 'assemblies')], check=True, stdout=subprocess.DEVNULL)
        data = json.loads((h / 'assemblies/movables.json').read_text())
        placement = [x for x in data['placements'] if x['source_index'] == CONTROL]
        assert len(placement) == 1 and placement[0]['placement_hex'] == PLACEMENT_HEX and placement[0]['template'] == TEMPLATE, placement
        rows = sorted([f for f in data['faces'] + data['state_faces'] if f['source_index'] == CONTROL], key=lambda f: f['face'])
        assert [f['face'] for f in rows] == list(range(6)) and all(f['child'] == 151 for f in rows), rows
        assert [f['resource_id'] for f in rows] == FACE_RESOURCES, [f['resource_id'] for f in rows]
        materials_root = Path(data['materials_root'])
        out = a.project.resolve() / 'assets/lol2/generated' / FOLDER
        staged = h / 'staged'; staged.mkdir()
        images = {}
        sources = {'material_31.png': 'material_0031/mip_0_palette.png', 'material_227.png': 'material_0227/mip_0_palette.png',
                   **{f'wheel_{i}.png': f'material_0138/variant_{i}.png' for i in range(FRAMES)}}
        assert not (materials_root / f'material_0138/variant_{FRAMES}.png').exists(), 'Wheel group length changed'
        for dest, src in sources.items():
            content = (materials_root / src).read_bytes()
            images[dest] = sha(content)
            (staged / dest).write_bytes(content)
        if a.print_hashes: print(json.dumps(images, indent=1))
        elif images != PINNED_IMAGES: raise SystemExit('Wheel door images changed')
        clips = stage_clips(h, FOLDER, [SOUND], game=game)
        audio = {}
        for request, row in clips.items():
            shutil.copyfile(h / 'assets/lol2/generated' / FOLDER / (str(request) + '.wav'), staged / (str(request) + '.wav'))
            audio[str(request)] = {'path': f'res://assets/lol2/generated/{FOLDER}/{request}.wav', 'wav_sha256': row['wav_sha256'], 'role': 'use'}
        if out.exists(): shutil.rmtree(out)
        shutil.copytree(staged, out)
    contract = {
        'version': 1, 'source': SOURCE, 'control': CONTROL,
        'placement': {'offset': PLACEMENT_OFFSET, 'hex': PLACEMENT_HEX, 'x': placement[0]['x'], 'y': placement[0]['y'],
                      'height': placement[0]['height'], 'heading': placement[0]['heading'], 'template': TEMPLATE},
        'faces': [{'face': f['face'], 'resource': f['resource_id'], 'points': f['points'], 'uv': f['uv']} for f in rows],
        'frames': [f'wheel_{i}.png' for i in range(FRAMES)],
        'groups': {name: {'group': g[0], 'event': g[1], 'value': g[2], 'predicate': g[3], 'archive_offset': g[4], 'commands': g[5]} for name, g in GROUPS.items()},
        'sound': SOUND,
        'images': images, 'audio': audio,
        'root': f'res://assets/lol2/generated/{FOLDER}/',
        'not_hosted': ['op7 playback clock (adapter: 15 frames/s measured from the longplay, 40 frames in about 2.7 s)',
                       'native collision of static assemblies (adapter: the box blocks while linked; the end group unlinks it)'],
    }
    path = a.project.resolve() / 'scripts/lol2/museum_wheel_door_source.json'
    path.write_text(json.dumps(contract, indent=1) + '\n')
    print('PASS museum wheel door contract', path)

PINNED_IMAGES = {
    'material_31.png': '9322a887b20838eca38b167e482d745ae21a640a9a299c37e1646a986819b7da',
    'material_227.png': 'fe4b4a88a580b69094e25d43ca01c0615541e727539d5b63938d48179cf5c764',
    'wheel_0.png': '4dbb001299d428f0d411605022f19483752abd245611f27340af3dd1e443f743',
    'wheel_1.png': 'd1686bf1a2b28889b693a5eb7e23d9e611d79128e4f981e6f5dcb084b958f53d',
    'wheel_2.png': 'ea1f7a1ee7267d474a70e9649d4087642d4aa064ddd9e25800e6b3402832c721',
    'wheel_3.png': 'ae8da4c93141f24f404b2bf900b281c6a787b4cfd1f499ddd7ca5eba72b1d1f3',
    'wheel_4.png': '76d1be3f716b693c16c3c6978f3433789d524c6372926c230860cbca570520e6',
    'wheel_5.png': 'a5764f8043346bdb96ecf93c2cc2008c2c59fbcd73d5c3a76076c95249a9cee6',
    'wheel_6.png': '714cfc0b349d8741625f02a29f4c40f331f559242e42da274058cabce3cba4a2',
    'wheel_7.png': '358ef2e093ed6a9610af4e23b9b8b253e81efd27186fd7e95b1a3106d2a6b0dc',
    'wheel_8.png': '27febed7d4d753779221f909f7051f3c2e00594a3a9afed699d09e1ddd1a74ac',
    'wheel_9.png': 'cab0b2c00979c614aeb08363876a05cf949baf8363c8e59d44c6254479d5358a',
    'wheel_10.png': '9127e5773c98fe033f156f44d6e3c23d777eaf1ffcbb88dd2cc0b778448639f9',
    'wheel_11.png': 'b7ddac0609b4197d424ae759691d522c8d68c87a338b9b3bc647ca040d828daa',
    'wheel_12.png': 'bb7da5d98832a121462284ff2a29d6b6460bd49b265b5b5ee2d592e468376c32',
    'wheel_13.png': '98f6b87963fe4e15437cc0b7f5a26f3a37bd4939f4a18b830feda3a1b4bbfc4f',
    'wheel_14.png': '3a7a6c78fccf3dfdd120d2f81be2079956b10d81b60670c0403f46226c0df34e',
    'wheel_15.png': '3ddf05d73da438c071d8346aab4d3b5c77351b9b9dd8237cdea5f73337513ffd',
    'wheel_16.png': '65edbf21c1eae3fa72b76b467a92aae563d1591da137bd1554d3e3ef8dbf551e',
    'wheel_17.png': '49c3474123c06859c27923c4ff097bfcbc43d36b0e29c0a67be62cc0cce1a682',
    'wheel_18.png': '35aac271964af27ec36f0aebd215c319089a22815df91e483b58a278d72c4521',
    'wheel_19.png': '65a1cef85fcc8ff741a277599bd38320b5e4fbabaceed52cac7cb097c6602b2c',
    'wheel_20.png': '0fe18c43fff91d570092da86df9129a694176e99085b9be5417fc5a3d3ded5f9',
    'wheel_21.png': '5731b4257609a7bcd0cdf544f5554b97774f49bec16bc9b2ab61f3da06fcc1b6',
    'wheel_22.png': 'b03b92de1ee52578b791d9ba308743211a66ae93e3ff0d15806ae02f15b75255',
    'wheel_23.png': '3a0dac6287aa4fb823a9c92a129d718713c3bcba6b352d6eda406c405b8eaeca',
    'wheel_24.png': '2a57e640aa6dbf1762e76ef378e8fc6451270dca7f22cba9053fa1ea101cca2c',
    'wheel_25.png': '583764f0ea4b0be3566b3dc8c074f898449545c180cc18dd49fd50196efc9c3f',
    'wheel_26.png': 'af18635e0943670ee8445630af2547de2b9f75c58d27e8d5e6829037b1878f46',
    'wheel_27.png': 'cd4fc4ce15ff8f5b7415e43e5f2fad09571a23f154a1ca660e4a0af8d5ee52c9',
    'wheel_28.png': '61366a5c4a0f539d3f8d81ed52c395f7e59b035b37aaf8b000edbef7e0885721',
    'wheel_29.png': '9852dbabd27a719fa24284e60793a5ac10c069ee7e94eea636fb63b433094186',
    'wheel_30.png': '9289ffe55bdcbf0b21c1c73e3a462999725480902eaf3885d4090cae840f2455',
    'wheel_31.png': 'f9cf2fd0bd4cb9db5851b1ee11de6c613948b9a49e1c1e51281232003ed5d677',
    'wheel_32.png': '482335a1672f775c3d7d80a98b27fb2e962c8bb9eb3d30bd5a08bc9caa37d03d',
    'wheel_33.png': 'a93f38e42c38812f098cb443434675f5aba690b9ded21300f5daa7f69978c052',
    'wheel_34.png': '68f87b92549b85871e5f44920d34c60704b89ced659c41d889ba068cc1f6e54c',
    'wheel_35.png': '0585fe699df1d525fc5b7d4787266654d280d57b5ad6d38371f005e6c1280e49',
    'wheel_36.png': 'e1cabc0d8e1e6da0ae3da0f7505ad25fa945baae636baeb0bd3465bf7c5a60dc',
    'wheel_37.png': 'e1cabc0d8e1e6da0ae3da0f7505ad25fa945baae636baeb0bd3465bf7c5a60dc',
    'wheel_38.png': 'e1cabc0d8e1e6da0ae3da0f7505ad25fa945baae636baeb0bd3465bf7c5a60dc',
    'wheel_39.png': 'e1cabc0d8e1e6da0ae3da0f7505ad25fa945baae636baeb0bd3465bf7c5a60dc',
}
# The group runs from plain marble (phase0) through the vortex to fully transparent index0 (phases 35-39 identical).

if __name__ == '__main__':
    main()
