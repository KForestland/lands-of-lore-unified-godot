#!/usr/bin/env python3
"""Inventory the 0x342 filename placements already reported in props.json.

Each placement filename is hashed as SPHERE1, SPHERE2, and SPHERE3
\\<area>\\<FILE>.VQA with ww_hash_v1, only in that area's movie MIX
(DAT/<area>I.MIX). A unique FORM/WVQA hit is a hash and header witness.
It is not a replay of the native path builder. Several hits stay
candidates and are not extracted. Descriptor width/height, placement
position, and the signed state frame count are compared with VQHD.
No world quad and no cutscene activation is produced.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

# Also support direct invocation from tools/lol2 and existing callers that put
# only this directory on sys.path.
TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))
from lol2_source_format import parse_mix
from lol2_movie_format import parse_vqhd, ww_hash_v1

GAME_ROOT = Path('/home/bob/lol2_out/museum_capture_20260913/game')
PROPS_ROOT = Path('/home/bob/lol2_out/all_maps_20260922')
INVENTORY_PATH = Path('/home/bob/AI_COMMS/map_first_20260922/video_map_inventory.json')
RESOURCE_ROOT = PROPS_ROOT / 'video_resources'

REASON = re.compile(
    r"external 0x342 resource '([^']+)' \(raw ([0-9a-fA-F]+)\)")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


PREFIXES = ('SPHERE1', 'SPHERE2', 'SPHERE3')
BINDING = 'unique_hash_header_witness'


def movie_name(area_id: str, filename: str, prefix: str = 'SPHERE1') -> str:
    return f'{prefix}\\{area_id}\\{filename.upper()}'


def movie_mix_name(area_id: str) -> str:
    return f'DAT/{area_id}I.MIX'


def parse_reason(reason: str) -> dict | None:
    match = REASON.search(reason)
    if not match:
        return None
    raw = bytes.fromhex(match.group(2))
    flags, width, height, tail = struct.unpack_from('<4H', raw)
    return dict(filename=match.group(1), raw_hex=match.group(2).lower(),
                flags=flags, width=width, height=height, tail_u16=tail)


def frame_fields(frame_hex: str) -> dict:
    frame = bytes.fromhex(frame_hex)
    return dict(
        descriptor=struct.unpack_from('<h', frame)[0],
        flags=frame[2],
        left_add=frame[5],
        top_trim=frame[6],
        right_sub=frame[7],
        bottom=frame[8],
        frame_hex=frame_hex,
    )


def placement_position(placement_hex: str) -> dict:
    data = bytes.fromhex(placement_hex)
    x, y = struct.unpack_from('<hh', data, 0)
    z = struct.unpack_from('<h', data, 6)[0]
    return dict(x=x, y=y, z=z, position=[x, z, -y], placement_hex=placement_hex)


def vqhd_fields(blob: bytes) -> dict | None:
    if len(blob) < 12 or blob[:4] != b'FORM' or blob[8:12] != b'WVQA':
        return None
    form_size = struct.unpack_from('>I', blob, 4)[0]
    pos = 12
    header = None
    while pos + 8 <= len(blob):
        tag = blob[pos:pos + 4]
        size = struct.unpack_from('>I', blob, pos + 4)[0]
        if pos + 8 + size > len(blob):
            break
        if tag == b'VQHD':
            header = parse_vqhd(blob[pos + 8:pos + 8 + size])
            break
        pos += 8 + size + (size & 1)
    if not header or 'width' not in header:
        return None
    return dict(
        form_size=form_size,
        form_spans_entry=form_size + 8 == len(blob),
        version=header['version'],
        flags=header['flags'],
        count=header['num_frames'],
        width=header['width'],
        height=header['height'],
        fps=header['frame_rate'],
        block_w=header['block_w'],
        block_h=header['block_h'],
    )


def iter_external_placements(props_root: Path):
    for path in sorted(props_root.glob('*/props/props.json')):
        report = json.loads(path.read_text())
        seen = set()
        for issue in report.get('video_references', []) + report.get('issues', []):
            parsed = parse_reason(issue.get('reason', ''))
            if parsed is None:
                continue
            identity = (issue.get('record'), issue.get('descriptor'))
            if identity in seen:
                continue
            seen.add(identity)
            yield report, issue, parsed


def lookup_movie(game_root: Path, area_id: str, filename: str) -> dict:
    """Hash SPHERE1/2/3 in this area's movie MIX. One WVQA binds; several stay candidates."""
    archive_rel = movie_mix_name(area_id)
    mix_path = game_root / archive_rel
    if not mix_path.is_file():
        return dict(status='unresolved', archive=archive_rel, logical_name=None, key=None,
                    candidates=[], reason='movie MIX absent')
    archive = mix_path.read_bytes()
    by_key = {item['key']: item for item in parse_mix(archive)}
    hits = []
    for prefix in PREFIXES:
        logical = movie_name(area_id, filename, prefix)
        key = ww_hash_v1(logical)
        entry = by_key.get(key)
        if entry is None:
            continue
        start, length = entry['offset'], entry['size']
        blob = archive[start:start + length]
        header = vqhd_fields(blob)
        hits.append(dict(prefix=prefix, logical_name=logical, key=key, offset=start,
                         length=length, sha256=sha256_hex(blob), mix_index=entry['index'],
                         vqhd=header, wvqa=header is not None, blob=blob if header else None))
    valid = [hit for hit in hits if hit['wvqa']]
    candidates = [dict(prefix=hit['prefix'], logical_name=hit['logical_name'], key=hit['key'],
                       offset=hit['offset'], length=hit['length'], sha256=hit['sha256'],
                       wvqa=hit['wvqa']) for hit in hits]
    shared = dict(archive=archive_rel, archive_sha256=sha256_hex(archive), candidates=candidates)
    if len(valid) == 1:
        hit = valid[0]
        return dict(**shared, status='exact', binding=BINDING, prefix=hit['prefix'],
                    logical_name=hit['logical_name'], key=hit['key'], offset=hit['offset'],
                    length=hit['length'], sha256=hit['sha256'], mix_index=hit['mix_index'],
                    vqhd=hit['vqhd'], blob=hit['blob'],
                    reason='one SPHERE prefix key in this area movie MIX is FORM/WVQA')
    if len(hits) > 1 or (hits and not valid):
        return dict(**shared, status='ambiguous', binding=None, logical_name=None, key=None,
                    reason='more than one prefix key, or the key is not FORM/WVQA')
    return dict(**shared, status='unresolved', binding=None, logical_name=None, key=None,
                reason='no SPHERE1/2/3 key in this area movie MIX')


def compare_placement(parsed: dict, issue: dict, found: dict) -> dict:
    position = placement_position(issue['placement_hex'])
    frame = frame_fields(issue['frame_hex'])
    state_count = issue.get('source_frame_count')
    compared = dict(
        descriptor_width=parsed['width'],
        descriptor_height=parsed['height'],
        descriptor_flags=parsed['flags'],
        descriptor_tail_u16=parsed['tail_u16'],
        source_frame_count=state_count,
        state_consumes_one_frame=isinstance(state_count, int) and state_count < 0,
        later_state_frames=issue.get('later_state_frames'),
        frame=frame,
        placement=dict(record=issue['record'], template=issue['template'],
                       selector=issue['selector'], region=issue.get('region'),
                       placement_offset=issue.get('placement_offset'), **position),
    )
    header = found.get('vqhd')
    if header is None:
        compared['vqhd'] = None
        compared['dimensions_equal'] = None
        compared['frame_count_equals_consumed_state'] = None
        return compared
    consumed = 1 if compared['state_consumes_one_frame'] else state_count
    compared['vqhd'] = dict(width=header['width'], height=header['height'],
                            fps=header['fps'], count=header['count'])
    compared['dimensions_equal'] = (parsed['width'], parsed['height']) == (header['width'], header['height'])
    compared['frame_count_equals_consumed_state'] = header['count'] == consumed
    compared['tail_u16_equals_fps'] = parsed['tail_u16'] == header['fps']
    return compared


def build_inventory(game_root: Path, props_root: Path, resource_root: Path | None) -> dict:
    placements = []
    assets: dict[tuple, dict] = {}
    for report, issue, parsed in iter_external_placements(props_root):
        area_id = report['area_id']
        found = lookup_movie(game_root, area_id, parsed['filename'])
        blob = found.pop('blob', None)
        asset_key = (found.get('archive'), found.get('key'), found.get('sha256'))
        extracted = None
        if found['status'] == 'exact' and blob is not None and resource_root is not None:
            slot = assets.get(asset_key)
            if slot is None:
                dest = resource_root / area_id / parsed['filename']
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(blob)
                extracted = str(dest)
                assets[asset_key] = dict(
                    filename=parsed['filename'], logical_name=found['logical_name'],
                    prefix=found.get('prefix'), binding=BINDING,
                    archive=found['archive'], archive_sha256=found['archive_sha256'],
                    key=found['key'], offset=found['offset'], length=found['length'],
                    sha256=found['sha256'], mix_index=found['mix_index'],
                    vqhd=found['vqhd'], extracted=extracted)
            else:
                extracted = slot['extracted']
        row = dict(
            area_id=area_id,
            map_source=report.get('source'),
            filename=parsed['filename'],
            raw_hex=parsed['raw_hex'],
            descriptor=issue.get('descriptor'),
            status=found['status'],
            binding=found.get('binding'),
            prefix=found.get('prefix'),
            logical_name=found['logical_name'],
            candidates=found.get('candidates', []),
            archive=found['archive'],
            key=found['key'],
            offset=found.get('offset'),
            length=found.get('length'),
            sha256=found.get('sha256'),
            archive_sha256=found.get('archive_sha256'),
            mix_index=found.get('mix_index'),
            vqhd=found.get('vqhd'),
            extracted=extracted,
            resolve_reason=found.get('reason'),
            comparison=compare_placement(parsed, issue, found),
        )
        for collection, kind in (('props', 'visual'), ('nonvisual_props', 'nonvisual')):
            display = next((item for item in report.get(collection, [])
                            if item.get('record') == issue.get('record')
                            and 'displayed_selector' in item), None)
            if display is not None:
                row['inactive_fallback'] = dict(
                    kind=kind, source_selector=display['source_selector'],
                    displayed_selector=display['displayed_selector'],
                    fallback_chain=display['fallback_chain'],
                    state_hex=display['state_hex'], frame_hex=display.get('frame_hex'),
                    scope='Pre-script display with movie override inactive; original movie assets retained.')
                break
        placements.append(row)
    exact = [row for row in placements if row['status'] == 'exact']
    return dict(
        schema_version=2,
        placement_count=len(placements),
        exact_count=len(exact),
        unresolved_count=sum(row['status'] == 'unresolved' for row in placements),
        ambiguous_count=sum(row['status'] == 'ambiguous' for row in placements),
        unique_extracted=len(assets),
        lookup='SPHERE{1,2,3}\\\\<area_id>\\\\<FILENAME>.VQA via ww_hash_v1 in DAT/<area_id>I.MIX only',
        binding=BINDING,
        scope='Filename inventory of existing static 0x342 placements. SPHERE1, SPHERE2, and SPHERE3 are hashed in the same area movie MIX. A unique FORM/WVQA entry is kept with archive, key, offset, length, sha256, and VQHD width, height, fps, and frame count. That bind is a hash and header witness, not a native path replay. Multiple keys stay candidates and are not extracted. Same basename on two areas stays two files. Descriptor size, placement position, and signed state count are compared with the header. No world quad and no cutscene activation.',
        assets=list(assets.values()),
        placements=placements,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, default=GAME_ROOT)
    parser.add_argument('--props', type=Path, default=PROPS_ROOT)
    parser.add_argument('--resources', type=Path, default=RESOURCE_ROOT)
    parser.add_argument('--inventory', type=Path, default=INVENTORY_PATH)
    args = parser.parse_args()
    inventory = build_inventory(args.game, args.props, args.resources)
    args.inventory.parent.mkdir(parents=True, exist_ok=True)
    args.inventory.write_text(json.dumps(inventory, indent=2) + '\n')
    print(json.dumps(dict(
        placements=inventory['placement_count'], exact=inventory['exact_count'],
        unresolved=inventory['unresolved_count'], ambiguous=inventory['ambiguous_count'],
        extracted=inventory['unique_extracted'], inventory=str(args.inventory)), indent=2))


if __name__ == '__main__':
    main()
