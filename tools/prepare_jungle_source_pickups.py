#!/usr/bin/env python3
"""Stage Huline Jungle world-item row 51, 10-Th Dagger. Other rows stay unadmitted."""
import json, struct
from collections import deque
from PIL import Image
from pathlib import Path

MAGIC_REGION = 2636
ADMITTED_ROW = 51
ITEM_ID = 'jungle:item51:Th_Dagger'

def neighbors(level):
    count, start = u32(level, 0x58), u32(level, 12)
    assert u32(level, 0) == 18 and start + count * 44 <= len(level)
    graph = []
    for index in range(count):
        words = struct.unpack_from('<22H', level, start + index * 44)
        graph.append([n for n in words[2:6] if n != 65535])
    return graph

def hops(graph, origin, goal):
    if origin == goal:
        return 0, [origin]
    distance = {origin: 0}
    previous = {origin: None}
    queue = deque([origin])
    while queue:
        current = queue.popleft()
        for nxt in graph[current]:
            if nxt in distance or nxt >= len(graph):
                continue
            distance[nxt] = distance[current] + 1
            previous[nxt] = current
            if nxt == goal:
                path = [goal]
                while previous[path[-1]] is not None:
                    path.append(previous[path[-1]])
                return distance[nxt], list(reversed(path))
            queue.append(nxt)
    raise SystemExit(f'no region path {origin} -> {goal}')

def main():
    source = json.loads(SOURCE.read_text())
    area = next(row for row in source['areas'] if row['id'] == 'L4_HJ')
    blob = (GAME / area['source']['file']).read_bytes()
    assert digest(blob) == area['source']['sha256']
    geometry = next(row for row in parse_mix(blob) if row['key'] == area['source']['geometry_key'])
    level = blob[geometry['offset']:geometry['offset'] + geometry['size']]
    assert digest(level) == area['source']['geometry_sha256']
    row_count = u32(level, 0x6c)
    assert row_count == 88
    row = level[u32(level, 0x20) + 37 * ADMITTED_ROW:][:37]
    x, y, _, z = struct.unpack_from('<hhHh', row)
    flags, region = struct.unpack_from('<HH', row, 8)
    identity = u32(row, 32)
    assert (x, y, z) == (-1629, 4932, 70) and flags == 2 and not flags & 0x1000 and region == 3827
    assert identity == 2242013435
    graph = neighbors(level)
    distance, path = hops(graph, MAGIC_REGION, region)
    blocked = [list(links) for links in graph]
    blocked[2443] = []
    for links in blocked:
        if 2443 in links:
            links.remove(2443)
    try:
        hops(blocked, MAGIC_REGION, region)
        reaches_without_2443 = True
    except SystemExit:
        reaches_without_2443 = False
    definitions = entry('GLOBAL.MIX', 3984507021)
    assert digest(definitions) == 'b399b5c8bfea3597293a3237f30f45985efa2dd88d2dc29d5d18ca7488f60891'
    base, count = u32(definitions, 4), u32(definitions, 0x34)
    state = base + count * 91 + 4
    view = state + u32(definitions, state - 4) * 16 + 4
    names = view + u32(definitions, view - 4) * 12
    name = definitions[names + 9 * 30:names + 9 * 30 + 24].split(b'\0')[0].decode()
    definition = definitions[base + 9 * 91:][:91]
    assert name == '10-Th Dagger' and u32(definition, 24) == identity and definition[46] + definition[47] == 1
    selector = 0
    resource = None
    state_index = view_index = 0
    for index in range(count):
        record = definitions[base + index * 91:][:91]
        for _selector in range(record[46] + record[47]):
            views = max(1, struct.unpack_from('<b', definitions, state + state_index * 16 + 13)[0])
            if index == 9 and _selector == 0:
                assert views == 1
                resource = struct.unpack_from('<h', definitions, view + view_index * 12)[0]
                selector = _selector
            state_index += 1
            view_index += views
    assert resource is not None
    graphics = entry('LOCAL.MIX', 4018716831)
    assert digest(graphics) == '36e0d2a0e843126e28d60411ea3e67b3db2f8ea6185bcd6d520271790736ad93'
    sec = sections(graphics)
    desc = struct.unpack_from('<6H11I', graphics, sec[2] + resource * 56)
    width, height, pixels, _marked = decode_rows(graphics[sec[3] + desc[7]:][:desc[12]], allow_special=True)
    assert (width, height) == desc[1:3]
    palette = rgb_palette(graphics[u32(graphics, 4):][:768], 6)
    rgba = bytes(channel for pixel in pixels for channel in (*palette[pixel * 3:pixel * 3 + 3], 0 if pixel in (0, 1) else 255))
    out = ROOT / 'assets' / 'lol2' / 'generated' / 'jungle_source_pickups'
    out.mkdir(parents=True, exist_ok=True)
    Image.frombytes('RGBA', (width, height), rgba).save(out / 'th_dagger.png')
    godot = [x, z, -y]
    report = dict(
        id=ITEM_ID, row=ADMITTED_ROW, admitted=True, name=name, label='Th Dagger',
        native_position=[x, y, z], position=godot, flags=flags, dormant=False, region=region,
        magic_region=MAGIC_REGION, region_hops_from_magic=distance,
        shortest_region_path_includes_2443=2443 in path,
        reachable_from_magic_without_region_2443=reaches_without_2443,
        definition=9, identity=identity, handler=definition[0x42], resource=resource, selector=selector,
        size=[width, height], icon='res://assets/lol2/generated/jungle_source_pickups/th_dagger.png',
        placement_hex=row.hex(), definition_sha256=digest(definition), pixels_sha256=digest(pixels),
        omitted_remap_pixels=pixels.count(1),
        level_sha256=digest(level), definitions_sha256=digest(definitions), graphics_sha256=digest(graphics),
        world_item_rows=row_count, rows_not_admitted=row_count - 1,
        scope='Source row 51 position, flags 2 with dormant bit 0x1000 clear, region 3827, definition 9 identity and inventory icon. Godot position is x, y=native z, z=-native y. Region hops are neighbour connectivity from MAGIC region 2636, not a walked route or earned pickup. Native pickup admission and the original world-sprite renderer are not replayed. The other 87 world-item rows are counted and not enabled.')
    catalog = dict(admitted_rows=[ADMITTED_ROW], world_item_rows=row_count, rows_not_admitted=row_count - 1, pickups=[report])
    (out / 'pickups.json').write_text(json.dumps(catalog, indent=2) + '\n')
    (ROOT / 'docs' / 'jungle-source-pickups-source.json').write_text(json.dumps(catalog, indent=2) + '\n')
    print('PASS row51 Th Dagger', godot, 'definition9 resource', resource, 'hops', distance, 'via2443', 2443 in path, 'without2443', reaches_without_2443, 'sprite', width, height)
def explicit_main():
    import argparse, hashlib
    global ROOT, GAME, SOURCE, entry, sections, rgb_palette, decode_rows, digest, u32, parse_mix
    from lol2_source_format import parse_mix, u32
    from lol2_material_format import sections, rgb_palette
    from lol2_creature_sprite_format import decode_rows
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'source', 'output-root']:
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    GAME, SOURCE, ROOT = args.game.resolve(), args.source.resolve(), args.output_root.resolve()
    if ROOT.exists(): parser.error('Output must be a fresh directory')
    for path in [GAME, SOURCE]:
        if ROOT == path or ROOT in path.parents or path in ROOT.parents:
            parser.error('Output overlaps input')
    digest = lambda raw: hashlib.sha256(raw).hexdigest()
    archives = {}
    try:
        for name, wanted in [
            ('DAT/L4_HJ.MIX', '517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f'),
            ('GLOBAL.MIX', '1e3e2a46340d714aaf4d583e5aff7e58dc11005bac6c694fac49c07d13e01edd'),
            ('LOCAL.MIX', 'd0783146cad8823b3cbc540373fc85cd80482dff4375eaab7bc2a352e97fa278')]:
            archives[name] = (GAME / name).read_bytes()
            if digest(archives[name]) != wanted: raise ValueError('Unsupported original ' + name)
        source = json.loads(SOURCE.read_text())
        area = next(row for row in source['areas'] if row['id'] == 'L4_HJ')
        if area['source'] != dict(file='DAT/L4_HJ.MIX',
                sha256=digest(archives['DAT/L4_HJ.MIX']), geometry_key=3710797084,
                geometry_sha256='445d9b270d3e62574d719851305e3e30867715993f073a2dcd0e888295172aba'):
            raise ValueError('Unsupported Jungle source profile')
        def entry(filename, key):
            raw = archives[filename]
            matches = [e for e in parse_mix(raw) if e['key'] == key]
            if len(matches) != 1: raise ValueError('Expected one source entry')
            e = matches[0]
            return raw[e['offset']:e['offset'] + e['size']]
        (ROOT / 'docs').mkdir(parents=True)
        main()
    except (OSError, ValueError, AssertionError, KeyError, StopIteration) as error:
        parser.error(str(error) or type(error).__name__)


if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        explicit_main()
    else:
        from prepare_hive_wax import entry, sections, rgb_palette, decode_rows, ROOT, digest, u32
        from build_game_atlas import parse_mix
        from audit_monastery_rooms import GAME
        SOURCE = ROOT / 'docs' / 'game-source-inventory.json'
        main()
