#!/usr/bin/env python3
"""Stage the complete assets/lol2/generated/museum_broken_thohan pack (control.json, icon.png, sword_0..9.png) from
explicit original game files.

  python3 tools/prepare_museum_broken_thohan_media.py --game GAME --output-root FRESH

prepare_museum_broken_thohan.py (unchanged) builds the same pack but copies the sword frames from a historical
all-maps attached-prop export, and imports unicorn and the RE draracle closure for evidence that only reaches its docs
report (qualifier replay, LE fixup). Here:
- control.json is the writer's pure parsing of the original L3_DH geometry and metadata, ported unchanged (identity,
  contains, region_polygon, prop_state; placement row, trigger events, predicates, groups, Case children, template 24);
- sword_0..9.png are prop template 24's decoded frames from published lol2/map_props.load_templates/resolve_templates on
  the decoded L3_DH texture of lol2/map_materials.export_materials (the same calls the attached-prop exporter makes);
- icon.png is published prepare_museum_key_locks.icon for the "12-Tho Broken" definition (identity checked).
The output root must be fresh and must not equal, contain or lie inside the game root. Nothing is written until every
check passes. No historical export, no RE checkout, no capstone/unicorn, no native replay.
"""
import argparse, hashlib, json, shutil, struct, sys, tempfile
from pathlib import Path

ORIGINALS = {'DAT/L3_DH.MIX': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac',
             'GLOBAL.MIX': '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd',
             'LOCAL.MIX': 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278'}
GEOMETRY_SHA = 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'
META_SHA = 'f701bfed7800cb3d74ae1770878312930399c36e12f4518a1efc1c125f512a31'
TEXTURE_SHA = '7e353789b4ca6ff8b5630f894e85ec1788d9c4713eaa537aded98b78ece21e07'
IDENTITY = 1958882940
ITEM = 'museum:control181:Tho_Broken'
GRANT = bytes.fromhex('0a04b22e00000000000004131200')
RETURN = bytes.fromhex('0a04d02e03007c2ec27404131300')
PACK = 'assets/lol2/generated/museum_broken_thohan'


def digest(b):
    return hashlib.sha256(b).hexdigest()


def overlaps(a, b):
    a, b = a.resolve(), b.resolve()
    return a == b or a in b.parents or b in a.parents


# ---- helpers ported unchanged from prepare_museum_broken_thohan.py ---------------------------------------------------
def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]


def identity(name):
    raw = name.encode()
    value = 0
    for index in range(len(raw) // 4):
        value = ((value << 1 | value >> 31) + struct.unpack_from('<I', raw, 4 * index)[0]) & 0xffffffff
    tail = len(raw) % 4
    if tail:
        packed = 0
        for byte in raw[-tail:]:
            packed = ((packed & 0xffffff00 | byte) >> 8 | (byte << 24)) & 0xffffffff
        shift = (4 - tail) * 8
        packed = (packed >> shift | packed << (32 - shift)) & 0xffffffff
        value = ((value << 1 | value >> 31) + packed) & 0xffffffff
    return value


def contains(polygon, x, y):
    inside = False
    previous = polygon[-1]
    for current in polygon:
        if (current[1] > y) != (previous[1] > y):
            edge = (previous[0] - current[0]) * (y - current[1]) / (previous[1] - current[1]) + current[0]
            if x < edge:
                inside = not inside
        previous = current
    return inside


def region_polygon(level, index):
    record = level[u32(level, 12) + index * 44:][:44]
    words = struct.unpack('<22H', record)
    origin = u32(level, 4)
    polygon = []
    for vertex in words[6:10]:
        vx, vy = struct.unpack_from('<ii', level, origin + vertex * 8)
        polygon.append((vx / 65536, vy / 65536))
    return polygon


def prop_state(meta, template_index):
    """First forward state of one 55-byte prop template. Index -1 starts there."""
    assert u32(meta, 0) == 18 and u32(meta, 4) == 516
    offset, count = u32(meta, 8), u32(meta, 0x40)
    state_at = offset + count * 55 + 4
    frame_at = state_at + u32(meta, state_at - 4) * 16 + 4
    state_index = frame_index = 0
    found = None
    for index in range(count):
        record = meta[offset + index * 55:offset + (index + 1) * 55]
        forward = record[46]
        for selector in range(forward + record[47]):
            state = meta[state_at + state_index * 16:state_at + (state_index + 1) * 16]
            frames = struct.unpack_from('<b', state, 13)[0]
            frames = 1 if frames < 0 else frames
            if index == template_index and selector == 0:
                frame = meta[frame_at + frame_index * 12:frame_at + (frame_index + 1) * 12]
                height = state[15]
                found = dict(
                    forward_states=forward, state_hex=state.hex(), frame_hex=frame.hex(),
                    resource=struct.unpack_from('<h', frame)[0],
                    left=-state[14] / 2 + frame[5], right=state[14] / 2 - frame[7],
                    bottom=frame[8], top=height - frame[6], frames=frames)
            state_index += 1
            frame_index += frames
    assert found and found['frames'] == 1 and found['resource'] == 466
    return found


def catalog_from_originals(archive, parse_mix, section, groups, events):
    """The writer's main() checks and control.json catalog, without its docs-only native evidence."""
    assert identity('12-Tho Broken') == IDENTITY
    geometry = next(row for row in parse_mix(archive) if row['key'] == 3106551060)
    meta_entry = next(row for row in parse_mix(archive) if row['key'] == 3105896470)
    level = archive[geometry['offset']:geometry['offset'] + geometry['size']]
    meta = archive[meta_entry['offset']:meta_entry['offset'] + meta_entry['size']]
    assert digest(level) == GEOMETRY_SHA and digest(meta) == META_SHA, 'geometry/metadata entries'
    row = level[u32(level, 0x18) + 181 * 33:][:33]
    assert row.hex() == 'd503f80900000f0082049d01ae157f000000000001000000000000001400000009', 'control181 placement'
    x, y, heading, height = struct.unpack_from('<hhHh', row)
    region = struct.unpack_from('<H', row, 10)[0]
    trigger = struct.unpack_from('<H', row, 12)[0]
    assert (x, y, heading, height, region, trigger, row[32]) == (981, 2552, 0, 15, 413, 5550, 9)
    _offset, _count, blob = section(level, 0x40, 0x88, 1)
    listing = [(kind, body.hex(), predicate) for _cursor, kind, body, predicate in events(blob, trigger)]
    assert listing[:4] == [(4, GRANT[:10].hex(), 18), (19, '04131200', None), (4, RETURN[:10].hex(), 19), (19, '04131300', None)], 'trigger events'
    _offset, _count, predicates = section(level, 0xbc, 0xb8, 5)
    assert predicates[18 * 5:19 * 5] == bytes.fromhex('0005000000') and predicates[19 * 5:20 * 5] == bytes.fromhex('0005000001'), 'predicates'
    _offset, _count, stream = section(level, 0x44, 0x8c, 1)
    parsed = {group: [body.hex() for _at, body in commands] for group, commands in groups(stream)}
    assert parsed[11954] == ['030100007c2ec27401000000', '0510b5000100', '1010b5000100'], 'group11954'
    assert parsed[11984] == ['020100001800', '0510b5000000', '1010b5000000'], 'group11984'
    template_at, template_count = u32(meta, 12), u32(meta, 0x44)
    template = meta[template_at + 9 * 60:template_at + 10 * 60]
    assert template[47:50] == bytes((22, 22, 70)) and b'Case' in template, 'Case template'
    child_at = template_at + template_count * 60 + 4
    cursor = sum(meta[template_at + index * 60 + 50] for index in range(9))
    children = {cursor + index: meta[child_at + (cursor + index) * 60:child_at + (cursor + index + 1) * 60] for index in range(template[50])}
    sword_child, empty_child = children[35], children[36]
    assert sword_child[59] == 1 and u32(sword_child, 48) == 1 and u32(sword_child, 0) == 24
    assert empty_child[59] == 0 and u32(empty_child, 48) == 2
    assert all(struct.unpack_from('<h', empty_child, face * 8)[0] == 0 for face in range(6))
    dx, dz, dy = (struct.unpack_from('<i', sword_child, off)[0] / 65536 for off in (4, 8, 12))
    assert (dx, dz, dy) == (0, 38, 0)
    visual = prop_state(meta, 24)
    assert (visual['left'], visual['right'], visual['bottom'], visual['top']) == (-8, 8, 0, 25)
    polygon = region_polygon(level, 413)
    holders = [index for index in range(u32(level, 0x58)) if contains(region_polygon(level, index), x, y)]
    frames = ['sword_%d.png' % index for index in range(10)]
    catalog = dict(
        id=ITEM, source_name='12-Tho Broken', identity=IDENTITY, control=181, region_field=413,
        region_contains_control=contains(polygon, x, y), regions_containing_point=holders,
        template=9, template_name='Case', native_position=[x, y], height=height, heading=heading,
        position=[x, height, -y], placement_hex=row.hex(), initial_sprite_mode=0, initial_owner_state=0,
        grant=dict(group=11954, event_hex=GRANT[:10].hex(), predicate=18, predicate_hex='0005000000',
                   qualifier=0, requires='null context+0xC', commands=parsed[11954], next_owner_state=1, next_sprite_mode=1),
        put_back=dict(group=11984, event_hex=RETURN[:10].hex(), predicate=19, predicate_hex='0005000001',
                      qualifier=3, requires='context definition identity', commands=parsed[11984], next_owner_state=0, next_sprite_mode=0),
        sword=dict(child=35, mask=1, visible_mode=0, prop_template=24, resource=466, position=[x + dx, height + dz, -(y + dy)],
                   left=visual['left'], right=visual['right'], bottom=visual['bottom'], top=visual['top'],
                   image='sword_0.png', frames=frames, child_hex=sword_child.hex(), state_hex=visual['state_hex'], frame_hex=visual['frame_hex']),
        empty_child=dict(child=36, mask=2, drawable_surfaces=0, child_hex=empty_child.hex()),
        modern_adapter=dict(reach=96, aim=0.97, input='E', note='Museum item reach. Not an event-record field.'))
    return catalog, meta


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ['game', 'output-root']: p.add_argument('--' + name, type=Path, required=True)
    a = p.parse_args()
    if a.output_root.exists(): p.error('--output-root must be a fresh directory')
    if overlaps(a.output_root, a.game): p.error(f'--output-root overlaps input {a.game}')
    for rel, want in ORIGINALS.items():
        if not (a.game / rel).is_file(): p.error('Missing original ' + str(a.game / rel))
        if digest((a.game / rel).read_bytes()) != want: p.error(f'{a.game / rel}: not the pinned original')
    tools = Path(__file__).resolve().parent; sys.path[:0] = [str(tools), str(tools / 'lol2')]
    try:
        from lol2_source_format import parse_mix
        from build_game_atlas import section
        from audit_game_actor_scripts import groups
        from audit_game_transition_owners import events
        from lol2_material_format import sections
        from prepare_museum_key_locks import definitions, icon
        import map_materials, map_props
        from PIL import Image
    except ImportError as error:
        p.error('Missing published helper or library: ' + str(error))
    try:
        catalog, meta = catalog_from_originals((a.game / 'DAT/L3_DH.MIX').read_bytes(), parse_mix, section, groups, events)
        blob, base, count, names = definitions(game=a.game)
        found = [i for i in range(count) if u32(blob, base + i * 91 + 24) == IDENTITY]
        assert len(found) == 1 and names[found[0]] == '12-Tho Broken', 'item definition'
    except (AssertionError, StopIteration, KeyError, ValueError, IndexError, struct.error) as error:
        p.error('Originals do not match: ' + (str(error) or type(error).__name__))
    with tempfile.TemporaryDirectory(prefix='museum-broken-thohan-') as tmp:
        tmp = Path(tmp)
        try:
            map_materials.export_materials(a.game, 'L3_DH', tmp / 'materials')
            texture = (tmp / 'materials/texture.bin').read_bytes(); assert digest(texture) == TEXTURE_SHA, 'museum texture'
            # Same template decode as lol2/map_primitive_geometry.prepare_templates (that module loads the RE closure).
            parsed = map_props.load_templates(meta); sec = sections(texture); po = u32(texture, 4)
            rgb = map_materials.rgb_palette(texture[po:po + 768], 6)
            selected = [t for t in parsed['templates'] if t['index'] == 24]; assert len(selected) == 1, 'template 24'
            (tmp / 'props').mkdir(); map_props.resolve_templates(selected, texture, sec, rgb, tmp / 'props/sprites', tmp / 'props', {})
            frames = [tmp / 'props/sprites' / ('prop_466_frame_%d.png' % i) for i in range(10)]
            assert all(f.is_file() for f in frames) and Image.open(frames[0]).size == (64, 66), 'prop 466 frames'
            icon(found[0], tmp / 'icon.png', game=a.game)
        except (AssertionError, ValueError, KeyError, OSError) as error:
            p.error('Fresh preparation refused: ' + (str(error) or type(error).__name__))
        out = a.output_root / PACK; out.mkdir(parents=True)
        for index, source in enumerate(frames): shutil.copyfile(source, out / ('sword_%d.png' % index))
        shutil.copyfile(tmp / 'icon.png', out / 'icon.png')
        (out / 'control.json').write_text(json.dumps(catalog, indent=2) + '\n')
    print('PASS museum_broken_thohan: control181 region413 contains', catalog['region_contains_control'], 'holders', catalog['regions_containing_point'], 'frames 10, icon')


if __name__ == '__main__':
    main()
