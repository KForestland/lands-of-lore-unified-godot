#!/usr/bin/env python3
"""Export every level archive's native command streams and event owners as data for the native script host.

    python3 tools/prepare_native_scripts.py --game GAME_ROOT --area L7_DH [--area ...] --output-root DIR
    python3 tools/prepare_native_scripts.py --game GAME_ROOT --all --output-root DIR

Writes DIR/scripts/lol2/native_scripts/<AREA>.json for each area and the pin file
DIR/scripts/lol2/native_scripts_source.json (archive, geometry and output sha256 per area).

Port producer. It imports nothing from the RE publication tree. Framing comes from the port module
tools/lol2_source_format.py (parse_mix, u32, the 37-opcode SIZES table of native 0x645E0). The
event-list walk, the four object tables (header/count fields, stride, list word +12), the region
descriptor table (0xA4/0xAC, stride 26, list word +0x0A), the kind-12 layout and the kind-19 trailer
rule are vendored from the port's tools/audit_game_transition_owners.py, which follows the published
readers extract_region_event_lists.py / link_region_event_commands.py. The F0 group rule (byte +4 =
child count, no nesting) is vendored from tools/audit_game_actor_scripts.py, which follows
extract_progression_commands.py. Stream 0 is header 0x3C/0x84 (native global 0x2B51C), stream 1 is
header 0x44/0x8C (0x2B514); region kind 12 names stream 0, object records name stream 1.

Data only. No opcode effect, no event meaning and no table identity of a command kind byte is
assigned here. Bytes that are not decoded stay as raw hex. An opcode outside SIZES stops the framing
of that stream; it is listed under `unsupported` and the run fails. Nothing is guessed.
"""
import argparse
import hashlib
import json
import struct
import sys
from collections import Counter
from pathlib import Path

from lol2_source_format import SIZES, parse_mix, u32

ROOT = Path(__file__).resolve().parents[1]
FORMAT = 'lol2-native-scripts-2'
OUT_DIR = 'scripts/lol2/native_scripts'
PIN_FILE = 'scripts/lol2/native_scripts_source.json'
STREAMS = [(0, 0x3C, 0x84, 0x2B51C), (1, 0x44, 0x8C, 0x2B514)]
# label, header offset field, header count field, record stride (event list offset = record word +12)
TABLES = [('actor', 0x1C, 0x68, 56), ('prop', 0x14, 0x60, 37), ('control', 0x18, 0x64, 33), ('movable', 0x24, 0x70, 41)]
# Object record kinds whose word +2 is a stream-1 group (port audit_game_actor_scripts asserts this for every record).
OBJECT_GROUP_KINDS = (2, 3, 4, 5, 6, 8, 9, 10)
REGION_GROUP_KIND = 12
PREDICATE_KIND = 19
# G97 PROVEN: header +0xBC is the offset of the predicate table inside the geometry entry, +0xB8 the count; 5-byte
# entries (byte0 operator, byte1 left type, byte2 operand, byte3 right type, byte4 literal), loaded by 0x669D4.
PREDICATE_TABLE = (0xBC, 0xB8, 5)


class SourceError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise SourceError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def section(raw, offset_field, count_field, stride):
    offset, count = u32(raw, offset_field), u32(raw, count_field)
    require(offset + count * stride <= len(raw), f'section {offset_field:#x}/{count_field:#x} exceeds geometry')
    return offset, count, raw[offset:offset + count * stride]


def walk(blob, start):
    """Native list walk: byte0 length, byte1 kind; zero length or zero kind ends the list."""
    cursor, rows = start, []
    while True:
        require(cursor + 2 <= len(blob), f'event list {start} leaves its section at {cursor}')
        length, kind = blob[cursor], blob[cursor + 1]
        if not length or not kind:
            return rows, cursor
        require(length >= 2 and cursor + length <= len(blob), f'event record length {length} at {cursor}')
        rows.append((cursor, blob[cursor:cursor + length]))
        cursor += length


def frame(blob):
    """Split one stream into commands with the native size table. Stops at the first unsupported opcode."""
    commands, cursor = [], 0
    while cursor < len(blob):
        opcode = blob[cursor]
        length = SIZES.get(opcode)
        if length is None:
            return commands, dict(offset=cursor, opcode=opcode, reason='opcode not in the 37-entry size table')
        if cursor + length > len(blob):
            return commands, dict(offset=cursor, opcode=opcode, reason='command runs past the stream end')
        commands.append((cursor, blob[cursor:cursor + length]))
        cursor += length
    require(b''.join(body for _, body in commands) == blob, 'stream round trip')
    return commands, None


def group(commands):
    index, rows = 0, []
    while index < len(commands):
        offset, head = commands[index]
        grouped = head[0] == 240
        count = head[4] if grouped else 1
        first = index + int(grouped)
        children = commands[first:first + count]
        require(len(children) == count, f'group {offset} needs {count} commands')
        require(all(body[0] != 240 for _, body in children), f'nested group at {offset}')
        rows.append((offset, head if grouped else None, children))
        index = first + count
    return rows


def command_row(base, offset, body):
    return dict(offset=offset, file_offset=base + offset, opcode=body[0], kind=body[1],
                target=struct.unpack_from('<H', body, 2)[0], raw_hex=body.hex())


def area_data(area, game):
    source = area['source']
    archive = (game / source['file']).read_bytes()
    require(sha(archive) == source['sha256'], f'{area["id"]}: unsupported original {source["file"]}')
    entry = next((e for e in parse_mix(archive) if e['key'] == source['geometry_key']), None)
    require(entry is not None, f'{area["id"]}: geometry entry missing')
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    require(sha(raw) == source['geometry_sha256'], f'{area["id"]}: geometry entry changed')
    base = entry['offset']

    streams, groups, unsupported, group_index = [], [], [], {}
    for stream, offset_field, size_field, native_global in STREAMS:
        start, size, blob = section(raw, offset_field, size_field, 1)
        commands, stop = frame(blob)
        if stop is not None:
            unsupported.append(dict(stream=stream, file_offset=base + start + stop['offset'], **stop))
        rows = group(commands)
        streams.append(dict(stream=stream, native_global=native_global, header_offset_field=offset_field,
                            header_size_field=size_field, entry_offset=start, file_offset=base + start, size=size,
                            sha256=sha(blob), framed_bytes=sum(len(b) for _, b in commands),
                            command_count=len(commands) - sum(1 for _, h, _ in rows if h is not None),
                            group_count=len(rows)))
        for offset, head, children in rows:
            end = (children[-1][0] + len(children[-1][1])) if children else offset + len(head)
            groups.append(dict(stream=stream, group=offset, file_offset=base + start + offset,
                               header_hex=head.hex() if head is not None else None, count=len(children),
                               raw_hex=blob[offset:end].hex(),
                               commands=[command_row(base + start, o, b) for o, b in children]))
            group_index[(stream, offset)] = True

    pred_start, pred_count, pred_blob = section(raw, *PREDICATE_TABLE)

    def predicate(blob, blob_file, cursor, length):
        following = blob[cursor + length:cursor + length + 4]
        if len(following) < 4 or following[1] != PREDICATE_KIND:
            return None
        index = struct.unpack_from('<H', following, 2)[0]
        row = dict(trailer_hex=following.hex(), trailer_file_offset=blob_file + cursor + length, index=index)
        if index < pred_count:
            row.update(entry_hex=pred_blob[index * 5:index * 5 + 5].hex(), entry_file_offset=base + pred_start + index * 5)
        else:
            row.update(entry_hex=None, entry_file_offset=None)
        return row

    objects, record_counts, unlinked = [], Counter(), Counter()
    obj_start, _, obj_blob = section(raw, 0x40, 0x88, 1)
    table_sizes = {}
    for label, offset_field, count_field, stride in TABLES:
        table_start, count, records = section(raw, offset_field, count_field, stride)
        table_sizes[label] = count
        for index in range(count):
            list_offset = struct.unpack_from('<H', records, index * stride + 12)[0]
            rows, terminator = walk(obj_blob, list_offset)
            # Objects without records are kept too: the host seeds constructor state from every placement.
            events = []
            for cursor, body in rows:
                record_counts[body[1]] += 1
                event = dict(offset=cursor, file_offset=base + obj_start + cursor, kind=body[1], raw_hex=body.hex())
                if body[1] in OBJECT_GROUP_KINDS:
                    require(len(body) >= 5, f'object record at {cursor} is too short')
                    target = struct.unpack_from('<H', body, 2)[0]
                    require((1, target) in group_index, f'object record at {cursor} names no stream-1 group {target}')
                    event.update(stream=1, group=target, value=body[4], extra_hex=body[5:].hex())
                    event['predicate'] = predicate(obj_blob, base + obj_start, cursor, len(body))
                elif body[1] != PREDICATE_KIND:
                    unlinked[body[1]] += 1
                events.append(event)
            objects.append(dict(ref=f'{label}:{index}', table=label, index=index,
                                file_offset=base + table_start + index * stride,
                                placement_hex=records[index * stride:(index + 1) * stride].hex(),
                                list_offset=list_offset, list_file_offset=base + obj_start + list_offset,
                                terminator_offset=terminator, events=events))

    reg_start, _, reg_blob = section(raw, 0x38, 0x80, 1)
    desc_start, desc_count, descriptors = section(raw, 0xA4, 0xAC, 26)
    lists = {}
    for index in range(desc_count):
        lists.setdefault(struct.unpack_from('<H', descriptors, index * 26 + 10)[0], []).append(index)
    regions, region_lists = {}, []
    for list_offset in sorted(lists):
        rows, terminator = walk(reg_blob, list_offset)
        listed = []
        for cursor, body in rows:
            record_counts[('region', body[1])] += 1
            event = dict(offset=cursor, file_offset=base + reg_start + cursor, kind=body[1], raw_hex=body.hex())
            if body[1] == REGION_GROUP_KIND:
                require(len(body) >= 8, f'region record at {cursor} is too short')
                target, region, event_byte, value = struct.unpack_from('<HHBB', body, 2)
                require((0, target) in group_index, f'region record at {cursor} names no stream-0 group {target}')
                event.update(stream=0, group=target, region=region, event=event_byte, value=value,
                             extra_hex=body[8:].hex(), descriptors=lists[list_offset])
                event['predicate'] = predicate(reg_blob, base + reg_start, cursor, len(body))
                regions.setdefault(region, []).append(event)
            elif body[1] != PREDICATE_KIND:
                unlinked[('region', body[1])] += 1
            listed.append(event)
        region_lists.append(dict(list_offset=list_offset, list_file_offset=base + reg_start + list_offset,
                                 descriptors=lists[list_offset], terminator_offset=terminator, records=listed))
    for region in sorted(regions):
        objects.append(dict(ref=f'region:{region}', table='region', index=region, events=regions[region]))

    opcode_use = Counter(c['opcode'] for g in groups for c in g['commands'])
    counts = dict(objects=sum(1 for o in objects if o['events']), placements=sum(1 for o in objects if 'placement_hex' in o), object_tables=table_sizes, region_descriptors=desc_count,
                  region_lists=len(region_lists), groups=len(groups),
                  commands=sum(len(g['commands']) for g in groups),
                  event_links=sum(1 for o in objects for e in o['events'] if 'group' in e),
                  predicate_trailers=sum(1 for o in objects for e in o['events'] if e.get('predicate')),
                  distinct_opcodes=len(opcode_use),
                  opcode_use={str(op): n for op, n in sorted(opcode_use.items(), key=lambda kv: (-kv[1], kv[0]))},
                  unlinked_record_kinds={str(k): n for k, n in sorted(unlinked.items(), key=str)},
                  unsupported=len(unsupported))
    return dict(format=FORMAT, area=area['id'], level=area['level'],
                source=dict(source, geometry_entry_offset=base, geometry_entry_size=entry['size']),
                size_table={str(op): n for op, n in sorted(SIZES.items())},
                size_table_source='tools/lol2_source_format.py SIZES (native 0x645E0 decision tree, 37 opcodes)',
                streams=streams, predicate_table=dict(file_offset=base + pred_start, count=pred_count, entry_size=5,
                                                       entries=[pred_blob[i * 5:i * 5 + 5].hex() for i in range(pred_count)]),
                counts=counts, unsupported=unsupported, groups=groups, objects=objects, region_lists=region_lists,
                scope=('Static source data: streams framed by the native size table, F0 groups, object and region event '
                       'records with their raw bytes and kind-19 trailers, and the 5-byte predicate table. For object records '
                       'value is record byte +4 and extra_hex is every later byte; for region kind 12, region is the '
                       'u16 at +4, event byte +6, value byte +7 and extra_hex the bytes after +7. These are storage '
                       'labels, not the native matchers (G97: the matcher width differs per kind; the host matches on '
                       'raw_hex). No opcode effect, event meaning, command kind-byte table, execution order or timing '
                       'is claimed.'))


def encode(data):
    return (json.dumps(data, indent=1, sort_keys=True) + '\n').encode()


def run(game, output_root, area_ids):
    profiles = json.loads((ROOT / 'docs/game-geometry-profiles.json').read_text())
    areas = {a['id']: a for a in profiles['areas']}
    unknown = [a for a in area_ids if a not in areas]
    require(not unknown, 'unknown area ' + ', '.join(unknown))
    out = output_root / OUT_DIR
    out.mkdir(parents=True, exist_ok=True)
    pins, failed = [], False
    for area_id in area_ids:
        data = area_data(areas[area_id], game)
        blob = encode(data)
        (out / f'{area_id}.json').write_bytes(blob)
        c = data['counts']
        print(f'{area_id}: objects {c["objects"]}, groups {c["groups"]}, commands {c["commands"]}, '
              f'event links {c["event_links"]}, predicates {c["predicate_trailers"]}, '
              f'distinct opcodes {c["distinct_opcodes"]}, unsupported {c["unsupported"]}')
        for row in data['unsupported']:
            failed = True
            print(f'  UNSUPPORTED stream {row["stream"]} offset {row["offset"]} file {row["file_offset"]} '
                  f'opcode {row["opcode"]}: {row["reason"]}')
        pins.append(dict(area=area_id, source=data['source'], output=f'{OUT_DIR}/{area_id}.json',
                         output_sha256=sha(blob), counts={k: c[k] for k in ('objects', 'groups', 'commands', 'event_links')}))
    (output_root / PIN_FILE).write_bytes(encode(dict(format=FORMAT, producer='tools/prepare_native_scripts.py', areas=pins)))
    return not failed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game', type=Path, required=True, help='original game root (read only)')
    parser.add_argument('--area', action='append', default=[], help='area id such as L7_DH; repeat')
    parser.add_argument('--all', action='store_true', help='every level archive in docs/game-geometry-profiles.json')
    parser.add_argument('--output-root', type=Path, required=True)
    args = parser.parse_args(argv)
    game, out = args.game.resolve(), args.output_root.resolve()
    if out == game or out in game.parents or game in out.parents:
        parser.error('Output overlaps original game')
    if args.all:
        args.area = [a['id'] for a in json.loads((ROOT / 'docs/game-geometry-profiles.json').read_text())['areas']]
    if not args.area:
        parser.error('give --area at least once, or --all')
    try:
        ok = run(game, out, args.area)
    except (OSError, SourceError) as error:
        parser.error(str(error))
    if not ok:
        print('Unsupported opcodes were found; see the lines above. Nothing was guessed.')
        return 1
    print(f'PASS native scripts for {len(args.area)} area(s) under {out / OUT_DIR}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
