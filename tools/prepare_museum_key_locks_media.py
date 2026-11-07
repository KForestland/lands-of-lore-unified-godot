#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_key_locks pack (passage78.json, sk_key.png, ss1.png) from explicit
original game files and a freshly prepared Museum base.

  python3 tools/prepare_museum_key_locks_media.py --game GAME --source scripts/lol2/museum_key_locks_source.json \
      --recipe scripts/lol2/museum_review_selection_source.json --museum-review BASE/assets/lol2/generated/museum_review/museum.json \
      --output-root FRESH

prepare_museum_key_locks.py (unchanged; still writes the published contract) builds passage78.json by rerunning
build_museum_review.py on historical exports and reads control106 from a historical static-assembly export. Here:
- control78 insert/take and prop81 kind6/event20 records come from the original L3_DH geometry with the same published
  readers as that writer (collect_owners, groups, predicate); control78 must equal the contract's locks.78 records;
- control106 position/heading/template come from its original 33-byte static placement row;
- the passage variant faces come from the unchanged builder rerun on inputs regenerated from the originals
  (prepare_museum_long_arm_media.builder_inputs/build, selection recipe), base faces required equal to --museum-review's
  faces (the paired Museum base; its sha256 is recorded as passage78 shipped_sha256), with regions1237/1477 lowered to 0;
- icons from prepare_museum_key_locks.icon (definitions 94 "92-Sk key" and the contract's SS1 definition).
The output root must be fresh and must not equal, contain or lie inside the game root, the paired base pack root or
the contract/recipe folders. Nothing is written until every check passes.
No historical export, no RE checkout, no native replay.
"""
import argparse, hashlib, json, shutil, struct, sys, tempfile
from pathlib import Path

SOURCE_SHA256 = '29bd7dfca4e3e3b38e47a7c623271c22eee7bba60e486177ae5618830cc73eab'  # scripts/lol2/museum_key_locks_source.json
RECIPE_SHA256 = '501ea933b9944ab7cfc893446fef346d142861ee53f96c137865a42b9348b477'  # scripts/lol2/museum_review_selection_source.json
ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac',
             'GLOBAL.MIX': '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd',
             'LOCAL.MIX': 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278'}
PACK = 'assets/lol2/generated/museum_key_locks'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


def source_records(game, area):
    """records(kind, owner) as prepare_museum_key_locks.main computes them, plus the static placement rows."""
    from lol2_source_format import parse_mix
    from build_game_atlas import section
    from audit_game_transition_owners import collect_owners
    from audit_game_actor_scripts import groups
    from prepare_jungle_exit_encounter import predicate
    arc = (game / area['file']).read_bytes()
    entry = next(e for e in parse_mix(arc) if e['key'] == area['geometry_key'])
    raw = arc[entry['offset']:entry['offset'] + entry['size']]; assert digest(raw) == area['geometry_sha256'], 'geometry entry'
    owners, _ = collect_owners(raw, entry['offset'], struct.unpack_from('<I', raw, 0x58)[0]); _, _, table = section(raw, 0xbc, 0xb8, 5)
    streams = []
    for of, sf in [(0x3c, 0x84), (0x44, 0x8c)]:
        _, _, blob = section(raw, of, sf, 1); streams.append({g: [b.hex() for _, b in c] for g, c in groups(blob)})
    def records(kind, owner):
        out = []
        for o in owners:
            if o['owner_kind'] != kind or o['owner'] != owner: continue
            n = arc[o['archive_offset']]; r = arc[o['archive_offset']:o['archive_offset'] + n]
            rec = dict(kind=o['event'], value=o['value'], group=o['group'], predicate=o['predicate'], raw=r.hex(),
                       predicate_expression=predicate(table, o['predicate']) if o['predicate'] is not None else None,
                       commands=streams[o['stream']][o['group']])
            if o['event'] == 4: rec.update(mode=r[4], held_identity=struct.unpack_from('<I', r, 6)[0])
            out.append(rec)
        return out
    _, _, placements = section(raw, 0x18, 0x64, 33)
    return records, placements


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'source', 'recipe', 'museum-review', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    # Input domains: the game root, the paired Museum base pack root (BASE of BASE/assets/lol2/generated/museum_review/
    # museum.json, else the manifest's folder) and the folders holding the contract/recipe.
    review_root = a.museum_review.resolve().parents[4] if a.museum_review.resolve().parts[-5:-1] == ('assets', 'lol2', 'generated', 'museum_review') else a.museum_review.resolve().parent
    for path in [a.game, review_root, a.source.resolve().parent, a.recipe.resolve().parent]:
        if overlaps(a.output_root, path): p.error(f'--output-root overlaps input {path}')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    for need in ['build_museum_review.py', 'export_museum_geometry.py', 'prepare_museum_long_arm_media.py']:
        if not (tools / need).is_file(): p.error('Missing builder file ' + str(tools / need))
    for path, want, label in [(a.source, SOURCE_SHA256, 'Museum key locks contract'), (a.recipe, RECIPE_SHA256, 'Museum review selection recipe')]:
        if not path.is_file(): p.error('Missing input: ' + str(path))
        if digest(path.read_bytes()) != want: p.error(f'{path}: not the pinned {label} ({want})')
    if not a.museum_review.is_file(): p.error('Missing input: ' + str(a.museum_review))
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    source, recipe = json.loads(a.source.read_text()), json.loads(a.recipe.read_text())
    review_bytes = a.museum_review.read_bytes()
    try: review = json.loads(review_bytes); assert isinstance(review, dict) and isinstance(review.get('faces'), list) and review['faces']
    except (ValueError, AssertionError): p.error(f'{a.museum_review}: not a museum_review manifest')
    from prepare_museum_key_locks import PASSAGE_REGIONS, definitions, icon
    from prepare_museum_long_arm_media import builder_inputs, build
    from lol2_source_format import u32
    import map_geometry, map_materials, map_surfaces
    from lol2_rotation_table import rotation_table
    try:
        assert source['source']['sha256'] == ORIGINALS['DAT/L3_DH.MIX'], 'contract archive'
        records, placements = source_records(a.game, source['source'])
        recs = records('control', 78)
        insert = [r for r in recs if r['kind'] == 4 and r['mode'] == 3]; take = [r for r in recs if r['kind'] == 4 and r['mode'] == 0]
        assert len(insert) == len(take) == 1 and insert[0] == source['locks']['78']['insert'] and take[0] == source['locks']['78']['take'], 'control78 records'
        lock = dict(insert=insert[0], take=take[0])
        # passage78() source checks, unchanged.
        assert lock['insert']['commands'][1] == '090351001500' and lock['take']['commands'][0] == '090351001500'
        ev = {r['predicate_expression']['raw']: r for r in records('prop', 81) if r['kind'] == 6 and r['value'] == 20}
        assert set(ev) == {'0005000000', '0005000001'}, 'prop81 records'
        opening, closing = ev['0005000000']['commands'], ev['0005000001']['commands']
        for region, (word, height) in PASSAGE_REGIONS.items():
            assert 'c490%04x0000000f00000000' % struct.unpack('>H', struct.pack('<H', word))[0] in opening
            assert 'c490%04x%04x000f00000000' % (struct.unpack('>H', struct.pack('<H', word))[0], struct.unpack('>H', struct.pack('<H', height))[0]) in closing
        assert '100351000100' in opening and '100351000000' in closing
        move = lambda c: dict(x=struct.unpack_from('<h', bytes.fromhex(c), 4)[0], y=struct.unpack_from('<h', bytes.fromhex(c), 6)[0],
                              heading=struct.unpack_from('<H', bytes.fromhex(c), 12)[0], raw=c)
        poses = dict(open=move(opening[0]), closed=move(closing[0])); assert opening[0].startswith('12106a00') and closing[0].startswith('12106a00')
        row = placements[106 * 33:107 * 33]; x, y, heading, height = struct.unpack_from('<hhHh', row)
        control106 = dict(position=[x, height, -y], heading=heading, template=row[32], poses=poses)
        blob, base, count, names = definitions(game=a.game)
        icons = {}
        for item in (source['key'], source['ss1']):
            assert names[item['definition']] == item['name'] and u32(blob, base + item['definition'] * 91 + 24) == item['identity'], item['name']
            icons[item['icon']] = item['definition']
        assert sorted(icons) == ['sk_key.png', 'ss1.png']
    except (AssertionError, KeyError, StopIteration, ValueError, IndexError, TypeError, struct.error) as error:
        p.error('Inputs do not match the published contract/originals: ' + (str(error) or type(error).__name__))
    with tempfile.TemporaryDirectory(prefix='museum-key-locks-') as tmp:
        tmp = Path(tmp)
        try:
            map_geometry.export_geometry(a.game, 'L3_DH', tmp / 'geometry')
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            geometry = tmp / 'geometry/geometry.json'
            inputs = builder_inputs(a.game, tmp, recipe, geometry, map_surfaces, rotation_table)
            base = build(tools, a.game, geometry, inputs, tmp / 'base')
            if base['faces'] != review['faces']: p.error('Fresh museum_review rebuild differs from --museum-review faces')
            g = json.loads(geometry.read_text())
            for r in g['regions']:
                if r['id'] in PASSAGE_REGIONS:
                    assert r['floor_base'] == PASSAGE_REGIONS[r['id']][1]; r['floor_base'] = 0; r['floor_corners'] = [0] * len(r['floor_corners'])
            opened_geometry = tmp / 'open_geometry.json'; opened_geometry.write_text(json.dumps(g))
            opened = build(tools, a.game, opened_geometry, inputs, tmp / 'open')
            (tmp / 'icons').mkdir()
            for name, definition in icons.items(): icon(definition, tmp / 'icons' / name, game=a.game)
        except (AssertionError, ValueError, KeyError, OSError) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
        # passage78() face diff and output, unchanged.
        key = lambda f: json.dumps(f, sort_keys=True)
        base_keys = [key(f) for f in base['faces']]; open_keys = {key(f) for f in opened['faces']}
        closed_only = [i for i, k in enumerate(base_keys) if k not in open_keys]
        open_only = [f for f in opened['faces'] if key(f) not in set(base_keys)]
        if not (closed_only and open_only and all(base['faces'][i]['material'] in base['materials'] or base['faces'][i]['material'] in ('shell', 'unresolved') for i in closed_only)):
            p.error('passage face diff is empty or uses unknown materials')
        missing = sorted({f['material'] for f in open_only} - set(base['materials']) - {'shell', 'unresolved'})
        if missing: p.error('Open faces use materials outside the base set: %s' % missing)
        passage = dict(version=1, shipped_sha256=digest(review_bytes), regions=sorted(PASSAGE_REGIONS), closed_face_indices=closed_only,
                       closed_faces=[base['faces'][i] for i in closed_only], open_faces=open_only, prop81=dict(opening=opening, closing=closing),
                       control106=control106)
        out = a.output_root / PACK; out.mkdir(parents=True)
        for name in icons: shutil.copyfile(tmp / 'icons' / name, out / name)
        (out / 'passage78.json').write_text(json.dumps(passage, indent=1) + '\n')
    print('PASS museum_key_locks: passage78 closed-only %d open-only %d, icons %s' % (len(closed_only), len(open_only), sorted(icons)))


if __name__ == '__main__':
    main()
