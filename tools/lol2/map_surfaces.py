"""Bind original per-area surface records to reusable review geometry.

Preserves unresolved faces with diagnostics. Static initial state only; source
animation timing and runtime material/geometry state changes remain separate.
"""
from pathlib import Path
import argparse
from collections import Counter
import hashlib
import json
import math
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
RE_TOOLS = Path('/home/bob/lol2_re_publish_20260911/tools/draracle')
sys.path.insert(0, str(RE_TOOLS))
from lol2_extract_draracle_geometry import parse_mix, u32

ROTATION_TABLE = Path('/home/bob/lol2_out/draracle_rotation_table_2026-09-11/rotation_table.bin')
ROTATION_HASH = 'd7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53'


def source_tables(game_root, area_id):
    inventory = json.loads((ROOT / 'docs/game-source-inventory.json').read_text())
    area = next(a for a in inventory['areas'] if a['id'] == area_id)
    archive = (game_root / area['source']['file']).read_bytes()
    if hashlib.sha256(archive).hexdigest() != area['source']['sha256']:
        raise ValueError('Source archive identity changed')
    entries = parse_mix(archive)
    entry = next(e for e in entries if e['key'] == area['source']['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    candidates = []
    for e in entries:
        body = archive[e['offset']:e['offset'] + e['size']]
        if len(body) >= 0x204 and u32(body, 0) == 18 and u32(body, 4) == 0x204:
            candidates.append(body)
    if len(candidates) != 1:
        raise ValueError('Expected one metadata table')
    meta = candidates[0]
    start, count = u32(meta, 4), u32(meta, 0x3c)
    names = start + count * 24
    if not 0 < count < 255 or names + count * 22 != u32(meta, 8):
        raise ValueError('Invalid preset table')
    presets = []
    for i in range(count):
        d = meta[start + i * 24:start + (i + 1) * 24]
        mode = bool(d[19])
        presets.append(dict(index=i, name=meta[names+i*22:names+(i+1)*22].split(b'\0')[0].decode('cp437'),
            resource=struct.unpack_from('<h', d, 4)[0], raw_hex=d.hex(),
            angle=struct.unpack_from('<H', d, 6)[0],
            offset_x=struct.unpack_from('<h', d, 8)[0]*65536 if mode else 0,
            offset_y=struct.unpack_from('<h', d, 10)[0]*65536 if mode else 0,
            offsets=[0, 0] if mode else [d[8], d[10]], scale=[2., 1., .5, .25][d[20] & 3]))
    return area, raw, presets


def resolve_resource(reference, blob):
    if reference >= 0:
        return reference, None
    offset, size = u32(blob, 0x20), u32(blob, 0x5c)
    index = -reference
    if size % 8 or index * 8 + 8 > size or offset + size > len(blob):
        raise ValueError(f'Invalid indirection {reference}')
    d = blob[offset + index*8:offset + index*8 + 8]
    resource = struct.unpack_from('<H', d)[0] + d[7]
    return resource, dict(reference=reference, initial_resource=resource, raw_hex=d.hex())


def floor_uv(points, preset, material, table):
    def trig(angle):
        angle &= 65535
        return table[(angle & 32767) >> 3] * (-1 if angle >= 32768 else 1)
    aa, bb = trig(preset['angle']), trig(preset['angle'] + 16384)
    uv = []
    for px, _, pz in points:
        x, y = round(px*65536)-preset['offset_x'], round(-pz*65536)-preset['offset_y']
        u = (((y*bb)>>16)+((x*aa)>>16))*preset['scale']/65536+preset['offsets'][0]
        v = (((x*bb)>>16)-((y*aa)>>16))*preset['scale']/65536+preset['offsets'][1]
        uv.append([u/material['width'], v/material['height']])
    return uv


def wall_uv(points, d, material):
    # Same source-record addressing as the existing Hive review, using full edge
    # endpoints where supplied by the caller (clipped spans use that same frame).
    top = [points[3], points[2], points[1], points[0]]
    length = math.dist(top[0][::2], top[1][::2])
    height = max(p[1] for p in top)-min(p[1] for p in top)
    if length <= 1e-9 or height <= 1e-9:
        raise ValueError('degenerate wall span')
    mode = (d[6] >> 5) & 3
    anchor, other = [(0,1),(1,0),(3,2),(2,3)][mode]
    origin, end = list(top[anchor]), top[other]
    origin[1] = max(p[1] for p in top) if mode < 2 else min(p[1] for p in top)
    scale = [2.,1.,.5,.25][d[7]&3]
    addressing = 8 if d[6]&16 else (16 if d[6]&8 else 0)
    w, h = material['width'], material['height']
    dx, dz = (end[0]-origin[0])/length, (end[2]-origin[2])/length
    uscale, vscale = scale if addressing else w/length, scale if addressing == 8 else h/height
    return [[(((p[0]-origin[0])*dx+(p[2]-origin[2])*dz)*uscale+(d[2] if addressing else 0))/w,
             ((p[1]-origin[1])*(-1 if mode<2 else 1)*vscale+(d[3] if addressing==8 else 0))/h] for p in points]


def bind_surfaces(game_root, area_id, geometry_root, material_root, out):
    area, raw, presets = source_tables(game_root, area_id)
    g = json.loads((geometry_root/'geometry.json').read_text())
    if g.get('source', {}).get('area_id') != area_id or g['source'].get('sha256') != area['source']['sha256']:
        raise ValueError('Geometry export belongs to a different source archive')
    # Geometry exporter writes a separate face payload; accept either wrapper.
    face_path = geometry_root/'faces.json'
    data = json.loads(face_path.read_text()) if face_path.exists() else g
    faces = data['faces'] if isinstance(data, dict) else data
    source_walls = None
    source_wall_path = geometry_root/'source_walls.json'
    if source_wall_path.exists():
        source_walls = json.loads(source_wall_path.read_text())
        # Native walls arrive top-first; the established UV frame is bottom-first.
        faces = [f for f in faces if f['kind'] in ('floor', 'ceiling')] + [
            dict(f, points=list(reversed(f['points']))) for f in source_walls['faces']]
    report = json.loads((material_root/'materials.json').read_text())
    if report.get('area_id') != area_id or report.get('source_hash', {}).get('archive_sha256') != area['source']['sha256']:
        raise ValueError('Material export belongs to a different source archive')
    available = {m['index']:m for m in report['materials']}
    blob = (material_root/'texture.bin').read_bytes()
    if hashlib.sha256(blob).hexdigest() != report['source_hash'].get('decoded_texture_sha256'):
        raise ValueError('Decoded texture blob differs from the material export')
    table_bytes = ROTATION_TABLE.read_bytes()
    if hashlib.sha256(table_bytes).hexdigest() != ROTATION_HASH:
        raise ValueError('Rotation table identity changed')
    table = struct.unpack('<4096i', table_bytes)
    wall_start, wall_count = u32(raw, 8), u32(raw, 0x54)
    if wall_start+wall_count*8 != u32(raw, 12):
        raise ValueError('Wall table boundary mismatch')
    regions = g['regions']
    materials, animations, alpha, issues, bindings, indirects = {}, {}, [], [], [], {}
    indexed_materials = {}
    import os
    def use_material(k):
        key = str(k)
        if key in materials:
            return
        m = available[k]
        folder = material_root / f'material_{k:04d}'
        filename = folder/'mip_0_palette.png'
        if not filename.is_file():
            raise ValueError(f'Missing image {filename}')
        materials[key] = os.path.relpath(filename, out)
        index_file = folder/'mip_0_indices.png'
        if index_file.is_file():
            indexed_materials[key] = os.path.relpath(index_file, out)
        if m.get('alpha_cutout') or m.get('has_alpha'):
            alpha.append(key)
        if m.get('animation_frames'):
            frames = [os.path.relpath(folder/f, out) for f in m['animation_frames']]
            accepted_lava_rate = area_id == 'L5_HC' and k in (13, 21, 24)
            animations[key] = dict(frames=frames,
                fps=1.6 if accepted_lava_rate else m.get('review_fps', 8.),
                timing='user accepted' if accepted_lava_rate else 'provisional')
            index_frames = [folder/(Path(frame).stem+'_indices.png') for frame in m['animation_frames']]
            if all(path.is_file() for path in index_frames):
                animations[key]['index_frames'] = [os.path.relpath(path, out) for path in index_frames]
    bound = []
    omitted = []
    for original in faces:
        f = dict(original)
        r = regions[f['region']]
        words = struct.unpack('<22H', bytes.fromhex(r['raw_hex']))
        kind = f['kind']
        try:
            if kind in ('floor', 'ceiling'):
                # Child records use the floor-material selector for their polygon,
                # including ceiling subdivision polygons interpreted by the exporter.
                selector = words[16 if kind=='floor' or words[14]&128 else 17] & 255
                if selector == 255:
                    omitted.append(dict(region=r['id'], kind=kind, reason='source selector 255: no surface material'))
                    continue
                if selector >= len(presets):
                    raise ValueError('surface selector out of bounds')
                preset = presets[selector]
                reference = preset['resource']
                k, indirection = resolve_resource(reference, blob)
                if k not in available:
                    raise ValueError(f'unsupported descriptor {k}')
                f['uv'] = floor_uv(f['points'], preset, available[k], table)
                binding = dict(region=r['id'], kind=kind, preset=selector, reference=reference, material=k)
            else:
                edge = f['edge']
                exposure = f.get('exposure', f.get('span_kind'))
                if isinstance(exposure, dict):
                    exposure = exposure.get('kind')
                code = f.get('surface_code', edge | (4 if kind in ('boundary','boundary_wall') else 8 if exposure=='step' else 0))
                first, count = words[13], words[15]&255
                if count and first+count > wall_count:
                    raise ValueError('wall record range out of bounds')
                candidates = []
                wall_indices = [f['wall_record']] if 'wall_record' in f else range(first, first+count)
                for wi in wall_indices:
                    if not first <= wi < first+count:
                        raise ValueError('source face wall record outside region range')
                    d = raw[wall_start+wi*8:wall_start+(wi+1)*8]
                    if d[5]&31 == code:
                        candidates.append((wi, d))
                if len(candidates) != 1:
                    raise ValueError('missing wall record' if not candidates else 'ambiguous wall records')
                wi, d = candidates[0]
                if 'special_uv' in f:
                    d = bytes(f['special_uv'])
                if 'vertical_offset' in f:
                    d = bytearray(d)
                    d[3] = f['vertical_offset']
                reference = struct.unpack_from('<h', d)[0]
                k, indirection = resolve_resource(reference, blob)
                if k not in available:
                    raise ValueError(f'unsupported descriptor {k}')
                f['uv'] = wall_uv(f['points'], d, available[k])
                binding = dict(region=r['id'], kind=kind, edge=edge, wall_record=wi, reference=reference, material=k)
            if indirection:
                indirects[str(reference)] = indirection
            use_material(k)
            f['material'] = str(k)
            if not all(math.isfinite(c) for uv in f['uv'] for c in uv):
                raise ValueError('nonfinite UV')
            bindings.append(binding)
        except ValueError as exc:
            f['material'] = 'unresolved'
            f['uv'] = [[0.,0.]]*len(f['points'])
            issues.append(dict(region=r['id'], kind=kind, edge=f.get('edge'), reason=str(exc)))
        bound.append(f)
    arrivals = []
    start, count = u32(raw, 0x48), u32(raw, 0x90)
    for i in range(count):
        x,y,heading,region,selector,flags,tail = struct.unpack_from('<hhHHBBH',raw,start+i*12)
        heights = regions[region]['floor_corners'] if region < len(regions) else None
        height = max(heights)+48 if heights else 48
        arrivals.append(dict(index=i, selector=selector, region=region, heading=heading, position=[x,height,-y]))
    summary = dict(faces=len(bound), textured_faces=len(bindings), unresolved_faces=len(issues),
        issue_counts=dict(Counter(i['reason'] for i in issues)), materials=len(materials),
        source_regions=len(regions), absent_source_surfaces=len(omitted), props_source=area['counts']['props'], props_rendered=0,
        ready_for_content=False, visual_qa='pending',
        scope='Initial source surfaces. Native UV parity, animated rates, static props and changed geometry states remain under review.')
    result = dict(id=area_id, name=area['name'], source=area['source'], faces=bound, materials=materials,
        animations=animations, alpha_cutout_materials=alpha, start=arrivals[0]['position'], arrivals=arrivals,
        issues=issues, omitted_surfaces=omitted, bindings=bindings, indirections=indirects, props=[], summary=summary)
    result['indexed_materials'] = indexed_materials
    if (material_root/'palette_rgb.png').is_file():
        result['palette_image'] = os.path.relpath(material_root/'palette_rgb.png', out)
    if (material_root/'shade64_remap.png').is_file():
        result['remap_image'] = os.path.relpath(material_root/'shade64_remap.png', out)
    if source_walls is not None:
        result['geometry_issues'] = source_walls['issues']
        summary['source_walls'] = source_walls['summary']
    ceiling_path = geometry_root/'ceiling_subdivisions.json'
    if ceiling_path.exists():
        ceiling_report = json.loads(ceiling_path.read_text())
        result.setdefault('geometry_issues', []).extend(
            dict(kind='ceiling_subdivision', **gap) for gap in ceiling_report['gaps'])
        summary['ceiling_subdivisions'] = {key: ceiling_report[key]
            for key in ('chains', 'children', 'child_faces')}
        summary['ceiling_subdivisions']['gaps'] = len(ceiling_report['gaps'])
    material_issues = [dict(kind='wall_uv', region=f['region'],
        wall_record=f.get('wall_record'), reason=f['uv_issue'],
        source_setup=f.get('uv_setup', {})) for f in bound if f.get('uv_issue')]
    for key in materials:
        material = available[int(key)]
        if material.get('shadow_blend_candidates'):
            material_issues.append(dict(material=key, reason=material['shadow_blend_note'],
                slots=material['shadow_blend_candidates']))
        if material.get('rle_repeat_note'):
            material_issues.append(dict(material=key, reason=material['rle_repeat_note']))
        if material.get('variable_frame_sizes'):
            material_issues.append(dict(material=key,
                reason='Variable frame dimensions decoded; native animation addressing remains under review.',
                frames=material.get('frame_sizes', [])))
    result['material_issues'] = material_issues
    summary['material_layout_issues'] = len(material_issues)
    out.mkdir(parents=True, exist_ok=True)
    (out/'review.json').write_text(json.dumps(result,separators=(',',':'))+'\n')
    (out/'surface_coverage.json').write_text(json.dumps(summary,indent=2)+'\n')
    return result


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game-root',type=Path,default=Path('/home/bob/lol2_out/museum_capture_20260913/game'))
    p.add_argument('--root',type=Path,default=Path('/home/bob/lol2_out/all_maps_20260922'))
    p.add_argument('--area',required=True)
    a=p.parse_args()
    base=a.root/a.area
    result=bind_surfaces(a.game_root,a.area,base/'geometry',base/'materials',base)
    print(json.dumps(result['summary'],indent=2))
