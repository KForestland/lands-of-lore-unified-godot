"""Bind verified sector shade fields. Dynamic native light selection is separate."""
import hashlib
import json
import struct
from pathlib import Path
from . import map_materials as mm


def bind(review: dict, geometry: dict, archive: bytes, texture: bytes, out: Path) -> dict:
    entry = geometry['source']['entry']
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    table = struct.unpack_from('<I', raw, 0xa4)[0]
    count = struct.unpack_from('<I', raw, 0xac)[0]
    sectors = []
    for i in range(count):
        record = raw[table + i*26:table + (i+1)*26]
        near, span = struct.unpack_from('<HH', record, 6)
        sectors.append([struct.unpack_from('<b', record, 22)[0], near, span, 128])
    regions = {}
    for region in geometry['regions']:
        sector = struct.unpack_from('<H', bytes.fromhex(region['raw_hex']), 24)[0]
        if sector >= count:
            raise ValueError(f'invalid lighting sector {sector}')
        regions[region['id']] = sectors[sector]
    bound = 0
    missing = 0
    for field in ('faces', 'movable_state_faces', 'props', 'attached_state_props'):
        for item in review.get(field, []):
            light = regions.get(item.get('region'))
            if light is None:
                # Unbound assemblies remain full-bright, explicitly recorded.
                missing += 1
                continue
            item['sector_light'] = light
            bound += 1
    offsets = mm.sections(texture)
    shades = texture[offsets[4]:offsets[5]]
    if len(shades) != 66*256:
        raise ValueError('unexpected source shade table extent')
    out.mkdir(parents=True, exist_ok=True)
    (out/'shade_indices.png').write_bytes(mm._png_gray_bytes(256, 64, shades[:64*256]))
    palette_at = struct.unpack_from('<I', texture, 4)[0]
    palette = bytes((v << 2) | (v >> 4) for v in texture[palette_at:palette_at+768])
    (out/'palette_dac.png').write_bytes(mm.png_rgb(256, 1, palette))
    result = dict(shade_image='environment/shade_indices.png', palette_image='environment/palette_dac.png',
                  bound_items=bound, unbound_items=missing, shade_sha256=hashlib.sha256(shades).hexdigest(),
                  binding='26-byte source sector: signed ambient+22, fade start u16+6, span u16+8; native E2FEB..E3084 and 131CD6..131D4F replayed',
                  limitations='Modern per-fragment distance shading; native light lists, surface scale, interpolation and palette changes unresolved. Unbound assemblies remain full-bright.',
                  magic_light='Optional modern player light, L toggle; no recovered spell cost or progression asserted.')
    review['lighting'] = result
    return result
