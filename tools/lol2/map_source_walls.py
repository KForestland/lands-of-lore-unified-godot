#!/usr/bin/env python3
"""Export wall faces from original per-region wall records.

Caller 0x114584 tests region word +0x1C bit 0x80 first (0x1145d2): set calls
0x115250 with the owner height already walked back to (owner word 10 when flag
0x20 is set, otherwise owner word 11). Child word 11 stays the chain
continuation. Otherwise byte5 bit 0x10 (0x11471c) calls 0x11511c, which reads
the region's own vertices and wall bytes 2, 3, 4 and 7 and does not load a
neighbor. Every other record calls 0x114aa4. Object init at 0x11464d stores
0x7f at +0x40 unless an earlier wall in the region has the same code with bit
0x10 cleared, in which case that record's byte4 is the scale. Byte4 bit 7 is
that scale (128), not an inactive bit. +0x31 is the vertical UV offset: 0 on
the bit-0x10 path, wall byte 3 otherwise, unless 0x114aa4 overwrites it.
Isolated class 0/8 neighbor 65535 stays an issue. No face is invented for a
missing record, and texture positions are not invented for 0x11511c.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from collections import Counter
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1]
INVENTORY = Path(__file__).resolve().parents[2] / 'docs' / 'game-geometry-profiles.json'
EXE_HASH = 'b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775'
CODE_RANGES = (
    (0x114aa4, 0x115119),
    (0x11511c, 0x11524e),
    (0x115250, 0x11553e),
    (0xf4504, 0xf458d),
    (0xf4590, 0xf4614),
    (0xf49fc, 0xf4a3c),
)
_INSTRUCTIONS = None


def _helpers():
    if str(TOOLS) not in sys.path:
        sys.path.insert(0, str(TOOLS))
    import re_helper_root
    re_helper_root.insert('draracle')
    from lol2_extract_draracle_geometry import parse_mix, u32
    from lol2_verify_flat_wall_spans import WallReplay
    return parse_mix, u32, WallReplay


def _signed_word(value):
    return value - 0x10000 if value & 0x8000 else value


class ChildWallReplay:
    """Original 0x115250 on the same memory image WallReplay uses.

    Callers 0x114584 (test at 0x1145d2) and 0x115540 (test at 0x115569) push
    the output object, the child region, and the owner height. 0x114642 writes
    wall byte 3 to output+0x31 unless surface bit 0x10 is set, which stores 0.
    0x115250 does not modify that byte. Approved helper is 0xf4504 only.
    """

    def __init__(self, replay):
        self.replay = replay

    def execute(self, region, code, owner_height, vertical_offset):
        replay = self.replay
        replay.regs = {name: 0 for name in replay.regs}
        replay.regs['esp'] = 0x700000
        for off, value in (
            (0, 0xdeadbeef),
            (4, 0x600000),
            (8, 0x400000 + 44 * region),
            (12, owner_height & 0xffffffff),
        ):
            replay.writemem(0x700000 + off, 4, value)
        replay.mem[0x600000:0x600046] = bytes(70)
        replay.writemem(0x600042, 1, code & 31)
        replay.writemem(0x600031, 1, vertical_offset & 255)
        return _interpret(replay, 0x115250, approved_calls=frozenset({0xf4504}))


class SpecialWallReplay:
    """Original 0x11511c. No helper calls and no neighbor load.

    Caller 0x11471c reaches here only when region flag 0x80 is clear and wall
    byte5 bit 0x10 is set. Geometry uses the region vertex words and wall bytes
    2, 3, 4 and 7. Object +0x31 stays 0. Object +0x40 is the render scale from
    caller 0x11464d (default 0x7f, or byte4 of an earlier record whose code
    matches with bit 0x10 removed).
    """

    RECORD = 0x610000

    def __init__(self, replay):
        self.replay = replay

    def execute(self, region, code, record, render_scale):
        replay = self.replay
        replay.regs = {name: 0 for name in replay.regs}
        replay.regs['esp'] = 0x700000
        replay.mem[self.RECORD:self.RECORD + 8] = bytes(record[:8])
        for off, value in (
            (0, 0xdeadbeef),
            (4, 0x600000),
            (8, 0x400000 + 44 * region),
            (12, self.RECORD),
        ):
            replay.writemem(0x700000 + off, 4, value)
        replay.mem[0x600000:0x600046] = bytes(70)
        replay.writemem(0x600042, 1, code & 31)
        replay.writemem(0x600030, 1, 0)
        replay.writemem(0x600031, 1, 0)
        replay.writemem(0x600040, 1, render_scale & 255)
        return _interpret(replay, 0x11511c, approved_calls=frozenset())


def _interpret(replay, pc, approved_calls):
    zero = less = below = False
    for _ in range(2000):
        item = replay.instructions[pc]
        operands = item.operands
        op = item.mnemonic
        nxt = pc + item.size
        if op == 'push':
            value = replay.get(item, operands[0])
            replay.regs['esp'] -= 4
            replay.writemem(replay.regs['esp'], 4, value)
        elif op == 'pop':
            replay.put(item, operands[0], replay.readmem(replay.regs['esp'], 4))
            replay.regs['esp'] += 4
        elif op == 'call':
            destination = replay.get(item, operands[0])
            if destination not in approved_calls:
                raise ValueError('Unapproved helper call')
            replay.regs['esp'] -= 4
            replay.writemem(replay.regs['esp'], 4, nxt)
            nxt = destination
        elif op == 'ret':
            destination = replay.readmem(replay.regs['esp'], 4)
            if destination != 0xdeadbeef:
                replay.regs['esp'] += 4
                pc = destination
                continue
            points = [list(struct.unpack_from('<3i', replay.mem, 0x600000 + index * 12)) for index in range(4)]
            return points, bool(replay.readmem(0x600044, 1))
        elif op in ('mov', 'movzx'):
            replay.put(item, operands[0], replay.get(item, operands[1]))
        elif op == 'lea':
            replay.put(item, operands[0], replay.addr(item, operands[1]))
        elif op in ('cmp', 'test'):
            left, right = replay.get(item, operands[0]), replay.get(item, operands[1])
            bits = operands[0].size * 8
            mask = (1 << bits) - 1
            zero = ((left - right) & mask) == 0 if op == 'cmp' else ((left & right) & mask) == 0
            less = _signed(left, bits) < _signed(right, bits) if op == 'cmp' else _signed(left & right, bits) < 0
            below = (left & mask) < (right & mask) if op == 'cmp' else False
        elif op == 'setne':
            replay.put(item, operands[0], int(not zero))
        elif op.startswith('j'):
            take = {
                'jmp': True, 'je': zero, 'jne': not zero, 'jl': less, 'jge': not less,
                'jle': less or zero, 'jg': not less and not zero, 'jb': below,
                'jbe': below or zero, 'ja': not below and not zero,
            }.get(op)
            if take is None:
                raise ValueError(op)
            if take:
                nxt = replay.get(item, operands[0])
        elif op == 'imul':
            if len(operands) != 2:
                raise ValueError(f'Unsupported imul at {pc:x}')
            bits = operands[0].size * 8
            value = _signed(replay.get(item, operands[0]), bits) * _signed(replay.get(item, operands[1]), bits)
            replay.put(item, operands[0], value)
        elif op in ('add', 'sub', 'and', 'xor', 'shl', 'shr', 'sar', 'inc', 'dec'):
            left = replay.get(item, operands[0])
            right = 1 if op in ('inc', 'dec') else replay.get(item, operands[1])
            bits = operands[0].size * 8
            if op in ('add', 'inc'):
                value = left + right
            elif op in ('sub', 'dec'):
                value = left - right
            elif op == 'and':
                value = left & right
            elif op == 'xor':
                value = left ^ right
            elif op == 'shl':
                value = left << (right & 31)
            elif op == 'shr':
                value = (left & ((1 << bits) - 1)) >> (right & 31)
            else:
                value = _signed(left, bits) >> (right & 31)
            replay.put(item, operands[0], value)
            zero = (value & ((1 << bits) - 1)) == 0
            if op in ('and', 'xor'):
                less = _signed(value, bits) < 0
                below = False
        else:
            raise ValueError(f'Unsupported instruction {pc:x}: {op}')
        pc = nxt
    raise ValueError('Instruction limit')


def _signed(value, bits):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def _special_render_scale(raw, wall_offset, first, index, code):
    """0x11464d: default 0x7f, else byte4 of the first earlier code match.

    The match is wall byte5 masked to 5 bits, compared with this code after
    bit 0x10 is cleared. The stored byte is the render scale at object +0x40.
    """
    stripped = code & 0xEF
    for earlier in range(first, index):
        record = raw[wall_offset + earlier * 8:wall_offset + (earlier + 1) * 8]
        if (record[5] & 31) == stripped:
            return record[4], earlier
    return 0x7F, None


def _owner_height_fixed(regions, region_id):
    """Caller walk at 0xf5901 and 0x11557c: previous region until flag 0x80 clears."""
    index = region_id
    for _ in range(len(regions) + 1):
        if index < 0 or index >= len(regions):
            raise ValueError('child owner walk left the region table')
        words = struct.unpack('<22H', bytes.fromhex(regions[index]['raw_hex']))
        if not words[14] & 0x80:
            chosen = words[10] if words[14] & 0x20 else words[11]
            return _signed_word(chosen) << 16
        index -= 1
    raise ValueError('child owner walk left the region table')


def _inventory():
    data = json.loads(INVENTORY.read_text())
    return {area['id']: area for area in data['areas']}, [area['id'] for area in data['areas']]


def load_instructions(exe: bytes):
    global _INSTRUCTIONS
    if hashlib.sha256(exe).hexdigest() != EXE_HASH:
        raise ValueError('Executable changed')
    if _INSTRUCTIONS is None:
        import capstone
        md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        md.detail = True
        instructions = {}
        for start, end in CODE_RANGES:
            code = exe[start + 0x37000:end + 0x37000]
            instructions.update({item.address: item for item in md.disasm(code, start)})
        _INSTRUCTIONS = instructions
    return _INSTRUCTIONS


def native_points(fixed):
    """Fixed [X, height, map Y] -> native [X, height, -Y]."""
    return [[point[0] / 65536, point[1] / 65536, -point[2] / 65536] for point in fixed]


def quad_area(points):
    acc = [0.0, 0.0, 0.0]
    for index, point in enumerate(points):
        nxt = points[(index + 1) % len(points)]
        acc[0] += point[1] * nxt[2] - point[2] * nxt[1]
        acc[1] += point[2] * nxt[0] - point[0] * nxt[2]
        acc[2] += point[0] * nxt[1] - point[1] * nxt[0]
    return (acc[0] * acc[0] + acc[1] * acc[1] + acc[2] * acc[2]) ** 0.5 * 0.5


def _issue(region, wall_record, code, raw_hex, reason):
    return dict(
        region=region,
        edge=None if code is None else code & 3,
        surface_code=code,
        wall_record=wall_record,
        raw_hex=raw_hex,
        reason=reason,
    )


def _linked_region(region, regions, code):
    """Neighbor on this wall edge, or an issue reason."""
    edge = code & 3
    neighbors = region.get('neighbors') or []
    if edge >= len(neighbors):
        return None, 'wall edge out of range'
    neighbor = neighbors[edge]
    if neighbor is None:
        return None, None
    if not isinstance(neighbor, int) or neighbor < 0 or neighbor >= len(regions):
        return None, 'neighbor out of range'
    return regions[neighbor], None


def _reciprocal_edge(region, neighbor, edge):
    """Witness rule: one shared start vertex and the reversed next vertex."""
    own = region.get('vertex_indices') or []
    other = neighbor.get('vertex_indices') or []
    if edge >= len(own) or len(other) < 4:
        return False
    nxt = (edge + 1) % 4
    matches = [index for index, vertex in enumerate(other) if vertex == own[edge]]
    return len(matches) == 1 and other[(matches[0] + 3) % 4] == own[nxt]


def _child_continuation(region, neighbor):
    """A non-child wall still uses 0x114aa4, which would read neighbor word 11.

    The region itself having flag 0x80 is the 0x115250 path, decided by the
    caller before this check. A neighbor with that flag keeps word 11 as the
    chain continuation, and 0x114aa4 is not given a rewritten height.
    """
    del region
    if neighbor is not None and neighbor.get('flags', 0) & 0x80:
        return 'neighbor flag 0x80 keeps word 11 as the chain continuation'
    return None


def _domain_reason(region, regions, code):
    """None when 0x114aa4 is the runtime builder for this serialized record."""
    klass = code & 12
    neighbor, problem = _linked_region(region, regions, code)
    if problem:
        return problem
    if klass in (4, 12):
        blocked = _child_continuation(region, neighbor)
        if blocked:
            return blocked
        # Extra flag bits outside the older witness masks are not tested by
        # 0x114aa4. The same builder reads dword +0x12 / +0x14 (words 10 and 11).
        return None
    if klass in (0, 8):
        if neighbor is None:
            # 0x114aca skips only the connector vertex swap. 0x114c4c loads the
            # neighbor index again and does not treat 0xffff as inactive.
            # Callers do not replace that serialized link.
            return 'absent neighbor'
        blocked = _child_continuation(region, neighbor)
        if blocked:
            return blocked
        flags = region.get('flags', 0)
        nflags = neighbor.get('flags', 0)
        if not (flags & 0xF0 or nflags & 0xF0) and (flags | nflags) & 12:
            neighbor_slope = bool(nflags & (8 if klass == 0 else 4))
            if neighbor_slope and not _reciprocal_edge(region, neighbor, code & 3):
                return 'nonreciprocal or ambiguous edge'
        return None
    return 'unsupported surface class'


def export_source_walls(game_root: Path, area_id: str, geometry_root: Path, out: Path) -> dict:
    """Write source_walls.json for one pinned area."""
    game_root = Path(game_root)
    geometry_root = Path(geometry_root)
    out = Path(out)
    areas, _order = _inventory()
    if area_id not in areas:
        raise ValueError(f'Unknown area {area_id}')
    area = areas[area_id]
    src = area['source']
    parse_mix, u32, WallReplay = _helpers()
    archive = (game_root / src['file']).read_bytes()
    if hashlib.sha256(archive).hexdigest() != src['sha256']:
        raise ValueError(f'{area_id} archive hash does not match inventory')
    entry = next((item for item in parse_mix(archive) if item['key'] == src['geometry_key']), None)
    if entry is None:
        raise ValueError(f'{area_id} geometry key {src["geometry_key"]} missing')
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    if hashlib.sha256(raw).hexdigest() != src['geometry_sha256']:
        raise ValueError(f'{area_id} geometry entry hash does not match inventory')
    exe = (game_root / 'LOLG.DAT').read_bytes()
    instructions = load_instructions(exe)
    geometry = json.loads((geometry_root / 'geometry.json').read_text())
    regions = geometry['regions']
    vertices = geometry['vertices_fixed']
    wall_offset, wall_count = u32(raw, 8), u32(raw, 0x54)
    if wall_offset + wall_count * 8 > len(raw):
        raise ValueError(f'{area_id} wall table exceeds geometry entry')
    blob = b''.join(bytes.fromhex(region['raw_hex']) for region in regions)
    replay = WallReplay(instructions, blob)
    child_replay = ChildWallReplay(replay)
    special_replay = SpecialWallReplay(replay)
    replay.writemem(0x22d04, 4, 0x500000)
    packed = b''.join(struct.pack('<2i', *vertex) for vertex in vertices)
    replay.mem[0x500000:0x500000 + len(packed)] = packed

    faces = []
    issues = []
    inactive = 0
    zero_area = 0
    class_counts = Counter()
    rendered_classes = Counter()
    for region in regions:
        words = struct.unpack('<22H', bytes.fromhex(region['raw_hex']))
        first, count = words[13], words[15] & 255
        if count and (first + count > wall_count or wall_offset + (first + count) * 8 > len(raw)):
            issues.append(_issue(region['id'], None, None, None, 'wall record range out of bounds'))
            continue
        for index in range(first, first + count):
            record = raw[wall_offset + index * 8:wall_offset + (index + 1) * 8]
            raw_hex = record.hex()
            code = record[5] & 31
            class_counts[str(code & 12)] += 1
            source_kind = '0x114aa4'
            render_scale = None
            scale_record = None
            try:
                # 0x114705, then 0x11471c, else 0x11472b. Bit 0x10 is not a class mask.
                if words[14] & 0x80:
                    source_kind = '0x115250'
                    owner_height = _owner_height_fixed(regions, region['id'])
                    # 0x114642: bit 0x10 clears the copied wall byte, else record[3].
                    vertical_init = 0 if code & 0x10 else record[3]
                    fixed, active = child_replay.execute(region['id'], code, owner_height, vertical_init)
                elif code & 0x10:
                    source_kind = '0x11511c'
                    render_scale, scale_record = _special_render_scale(
                        raw, wall_offset, first, index, code,
                    )
                    fixed, active = special_replay.execute(region['id'], code, record, render_scale)
                else:
                    reason = _domain_reason(region, regions, code)
                    if reason:
                        issues.append(_issue(region['id'], index, code, raw_hex, reason))
                        continue
                    fixed, active = replay.execute(
                        region['id'], code, (record[7] & 3) << 14, record[3], record[6],
                    )
                vertical_offset = replay.readmem(0x600031, 1)
                horizontal_offset = None
                if source_kind == '0x11511c':
                    horizontal_offset = replay.readmem(0x600030, 1)
                    render_scale = replay.readmem(0x600040, 1)
            except (ValueError, KeyError) as exc:
                reason = 'absent neighbor' if str(exc) == 'Absent-neighbor region dereference' else f'builder: {exc}'
                issues.append(_issue(region['id'], index, code, raw_hex, reason))
                continue
            if not active:
                inactive += 1
                continue
            points = native_points(fixed)
            if len(points) != 4 or quad_area(points) <= 1e-9:
                zero_area += 1
                continue
            rendered_classes[str(code & 12)] += 1
            face = dict(
                kind='source_wall',
                source_kind=source_kind,
                region=region['id'],
                edge=code & 3,
                surface_code=code,
                wall_record=index,
                raw_hex=raw_hex,
                vertical_offset=vertical_offset,
                points=points,
            )
            if source_kind == '0x11511c':
                # 0x12759e / 0x1275ad zero-extend object +0x30 and +0x31 and shl 16.
                # Those are wall_uv bytes 2 and 3. Object +0x40 is the shade dword
                # 0xfd8a8 (sar 7 at 0x131d1c / 0x13217e), which wall_uv does not read.
                # Bytes 6 and 7 still select mode and the 2/1/0.5/0.25 scale through
                # the shared object +0x3e init, so they stay the source bytes.
                descriptor = bytearray(record[:8])
                descriptor[2] = horizontal_offset & 255
                descriptor[3] = vertical_offset & 255
                face['render_scale'] = render_scale
                face['uv_setup'] = dict(
                    object_0x30=horizontal_offset,
                    object_0x31=vertical_offset,
                    object_0x40=render_scale,
                    scale_record=scale_record,
                    scale_default=scale_record is None,
                )
                face['special_uv'] = list(descriptor)
            faces.append(face)
    summary = dict(
        area_id=area_id,
        source_wall_records=sum(class_counts.values()),
        class_counts=dict(class_counts),
        rendered_faces=len(faces),
        rendered_class_counts=dict(rendered_classes),
        inactive_nonrendered=inactive,
        zero_area_skipped=zero_area,
        unsupported=len(issues),
        issue_counts=dict(Counter(item['reason'] for item in issues)),
        scope='Original wall records. Caller order is region flag 0x80 to 0x115250, '
              'else wall byte5 bit 0x10 to 0x11511c, else 0x114aa4. Flag 0x80 uses '
              'the owner height from the caller walk (word 10 if owner flag 0x20, else '
              'word 11). Child word 11 stays the chain continuation and is not a height. '
              '0x11511c uses the region vertices and wall bytes 2, 3, 4 and 7, with no '
              'neighbor read. Its vertical_offset is object +0x31 (0). Its render_scale '
              'is object +0x40 from caller 0x11464d (0x7f, or byte4 of the earlier record '
              'whose code matches with bit 0x10 removed). Byte4 bit 7 is that scale, '
              'including 128, and does not reject the record. special_uv is the wall '
              'record with bytes 2 and 3 replaced by object +0x30 and +0x31 (both 0 on '
              'this path). wall_uv consumes those bytes; it does not read object +0x40. '
              'That byte remains render_scale for the shade multiply and is not a UV term. '
              'vertical_offset on every face is the native byte at output+0x31. Point order '
              'is native top0, top1, '
              'bottom1, bottom0. Class 0/8 records with bit 0x10 clear and neighbor '
              '65535 stay issues: 0x114c4c and 0x114d2a dereference that word and no '
              'caller replaces it. Those isolated walls, 500 across the fifteen areas, '
              'are unresolved. Inactive builder results are counted and not rendered. '
              'No synthetic face is added for a missing record.',
    )
    payload = dict(faces=faces, issues=issues, summary=summary)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'source_walls.json').write_text(json.dumps(payload, indent=2) + '\n')
    return payload


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root', type=Path, default=Path('~/lol2_out/museum_capture_20260913/game'))
    parser.add_argument('--root', type=Path, default=Path('~/lol2_out/all_maps_20260922'))
    parser.add_argument('--area', default=None)
    args = parser.parse_args(argv)
    _areas, order = _inventory()
    selected = [args.area] if args.area else order
    rows = []
    for area_id in selected:
        geometry_root = args.root / area_id / 'geometry'
        try:
            payload = export_source_walls(args.game_root, area_id, geometry_root, geometry_root)
            summary = payload['summary']
            rows.append(dict(
                area_id=area_id,
                source_wall_records=summary['source_wall_records'],
                rendered_faces=summary['rendered_faces'],
                inactive_nonrendered=summary['inactive_nonrendered'],
                zero_area_skipped=summary['zero_area_skipped'],
                unsupported=summary['unsupported'],
                issue_counts=summary['issue_counts'],
                class_counts=summary['class_counts'],
                rendered_class_counts=summary['rendered_class_counts'],
            ))
        except Exception as exc:
            rows.append(dict(area_id=area_id, error=str(exc)))
    print(json.dumps(rows, indent=2))
    return rows


if __name__ == '__main__':
    rows = main()
    raise SystemExit(1 if any('error' in row for row in rows) else 0)
