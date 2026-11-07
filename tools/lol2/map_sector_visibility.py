"""Conservative source sector draw membership, replayed against E2AA4/E2CD4.

This excludes sectors absent from the native potential tree. It does not replace
portal screen clipping. Unbound objects and cameras outside known regions stay
visible rather than guessing a sector from the nearest surface.
"""
import struct
from .map_wall_admission import _sectors, _walk


def bind(review, geometry, archive):
    entry = geometry['source']['entry']
    raw = archive[entry['offset']:entry['offset']+entry['size']]
    records = [struct.unpack('<22H', bytes.fromhex(r['raw_hex'])) for r in geometry['regions']]
    sectors = _sectors(raw)
    membership = [sorted(set(_walk(raw, sector, records)) | {sector['index']}) for sector in sectors]
    regions = []
    for region in geometry['regions']:
        if region.get('record_role') != 'primary_region': continue
        vertices = [geometry['vertices_fixed'][i] for i in region['vertex_indices']]
        regions.append(dict(id=region['id'], sector=records[region['id']][12],
                            polygon=[[v[0]/65536., -v[1]/65536.] for v in vertices],
                            floor=region['floor_corners'], ceiling=region['ceiling_corners']))
    bound = unbound = 0
    for key in ('faces','movable_state_faces','props','attached_state_props'):
        for item in review.get(key,[]):
            region = item.get('region')
            if region is None or not 0 <= region < len(records):
                item['render_sector'] = -1
                unbound += 1
            else:
                item['render_sector'] = records[region][12]
                bound += 1
    review['sector_visibility'] = dict(potential_sectors=membership, regions=regions,
        bound_items=bound, unbound_items=unbound,
        binding='Source sector edge trees, geometry+34/+30, native E2AA4/E2CD4; conservative membership only.',
        limits='Modern camera-region lookup. No portal rectangle clipping. Unbound objects and out-of-region cameras remain visible.')
    return review['sector_visibility']
