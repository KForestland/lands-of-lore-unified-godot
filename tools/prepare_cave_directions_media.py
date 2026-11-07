#!/usr/bin/env python3
"""Prepare the complete Roach directional pack with published readers and explicit inputs."""
import argparse,hashlib,json,struct
from pathlib import Path
from PIL import Image
from lol2_source_format import parse_mix
from lol2_material_format import sections
from lol2_creature_sprite_format import parse_states,read_events,group_frames,lcw,decode_blocks,require
HASH='102410e0b69037da2bdf451dd4de9c7e30df2c9d1309b1d0a1c0224ab7218c97'
BEARING_VALUES = [-16777216,-1048576,-65536,-4096,-257,-256,-255,-33,-32,-1,0,1,31,32,33,255,256,257,4096,65536,1048576,16777216]
def sha(data):return hashlib.sha256(data).hexdigest()

def load_events(game_root):
    arc=(game_root/'DAT/L1_DC.MIX').read_bytes()
    require(sha(arc)=='6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345','Unsupported Cave archive')
    entries=[e for e in parse_mix(arc) if e['key']==2971019266]
    require(len(entries)==1,'Expected one Cave metadata entry')
    entry=entries[0];raw=arc[entry['offset']:entry['offset']+entry['size']]
    source=parse_states(raw);source['entry_sha256']=sha(raw)
    require(source['entry_sha256']=='b3d6b8f528166aad4fe316033eed2bd8404a8f42bd5dadc63bcc15cf08b3cf5a','Metadata differs')
    count,offset=struct.unpack_from('<II',raw,0x50)
    require(offset+count*8+1==len(raw),'Event table/trailer boundary')
    for entity in source['entities']:
        for state in entity['states']:
            state_raw=bytes.fromhex(state['raw_hex']);first=struct.unpack_from('<H',state_raw,8)[0]
            events,end=read_events(raw,offset,count,first)
            state.update(frame_event_first=first,frame_events=events,event_terminator=end,native_interval_units=struct.unpack_from('<i',state_raw,4)[0]>>8)
    return source

def select(entries, action, mask, tag, roll=0):
    first = eligible = -1
    for index, (key, flags, value, unused) in enumerate(entries):
        if key != action:
            continue
        if first < 0:
            first = index
        if not flags & mask:
            continue
        if tag == -1:
            roll -= value
            if roll < 0:
                return index
        elif value == tag:
            return index
        if eligible < 0:
            eligible = index
    return eligible if eligible >= 0 else first

def bearing(dx, dy):
    """1366EA's ratio-based 256-unit bearing, not floating-point atan2."""
    quadrant = (0xc0 if dx < 0 else 0) ^ (0x40 if dy < 0 else 0)
    x, y = abs(dx), abs(dy)
    reverse = (quadrant & 0x40) ^ 0x40
    if y >= x:
        x, y = y, x
        reverse ^= 0x40
    if y < 256:
        while x >= 256:
            x >>= 1
            y >>= 1
    result = ((y << 8)//x if x else 0xffffffff) >> 3
    return ((63-result if reverse else result) + quadrant) & 255

def shared_canvas(images, reference_bbox, height):
    boxes = [image.getbbox() for image in images]
    require(all(box is not None for box in boxes), 'Empty frame')
    union = (min(b[0] for b in boxes), min(b[1] for b in boxes),
             max(b[2] for b in boxes), max(b[3] for b in boxes))
    scale = height / (reference_bbox[3] - reference_bbox[1])
    centre = [((union[0] + union[2]) - (reference_bbox[0] + reference_bbox[2])) * 0.5 * scale,
              (reference_bbox[3] - (union[1] + union[3]) * 0.5) * scale, 0]
    return union, scale, centre

def export(game_root, texture, out):
    require(not out.exists(), "Output must be fresh")
    for source_path in (game_root,texture):
        require(out!=source_path and out not in source_path.parents and source_path not in out.parents,"Output overlaps input")
    source = load_events(game_root)
    state = source['entities'][4]['states'][2]
    require(source['entities'][4]['name'] == 'Roach', 'Named definition changed')
    refs = state['views']
    require([v['resource_reference'] for v in refs] == [769,733,742,751,760,751,742,733], 'View sequence changed')
    require([v['flags_byte2'] for v in refs] == [0,64,64,64,0,0,0,0], 'View flags changed')
    actions = {}
    entity = source['entities'][4]
    for key, selector, base, count in [(5,6,794,16),(14,9,810,20)]:
        require(all(select(entity['entries_bytes'],key,7,-1,r) == selector for r in range(101)), 'Action selector changed')
        action_state = entity['states'][selector]
        require([v['resource_reference'] for v in action_state['views']] == [base], 'Action resource changed')
        markers = [event['frame'] for event in action_state['frame_events'] if event['kind'] == 1]
        require(markers == ([12] if key == 5 else []), 'Attack frame markers changed')
        actions[key] = dict(selector=selector, resource=base, count=count, native_state=action_state,
                            impact_frames=markers)
    blob = texture.read_bytes()
    require(sha(blob) == HASH, 'Cache changed')
    s = sections(blob)
    descriptors = {d: struct.unpack_from('<6H11I', blob, s[2]+d*56) for d in range((s[3]-s[2])//56)}
    groups = {g['base']:g for g in group_frames({d:v for d,v in descriptors.items() if v[3] == 0x1246})}
    decoded, provenance, books = {}, {}, {}
    bases = {v['resource_reference']:9 for v in refs}
    bases.update({a['resource']:a['count'] for a in actions.values()})
    for base, count in sorted(bases.items()):
        require(groups[base]['count'] == count, 'Frame count differs')
        for d in groups[base]['frames']:
            v = descriptors[d]
            pos, size = s[3]+v[7], v[12]
            payload = blob[pos:pos+size]
            ci = struct.unpack_from('<I', payload, 8)[0]
            require(ci < 17, 'Codebook index')
            if ci not in books:
                offset, allocation, packed = struct.unpack_from('<3I', blob, s[9]+ci*12)
                require(s[8] <= offset and offset+allocation <= s[9] and packed <= allocation, 'Codebook bounds')
                books[ci] = lcw(blob[offset:offset+packed])
            w,h,pixels,_,_ = decode_blocks(payload, books[ci])
            require((w,h) == (320,200) and 1 not in pixels, 'Unsupported directional frame')
            decoded[d] = Image.frombytes('L', (w,h), pixels)
            provenance[d] = dict(payload_sha256=sha(payload), full_indices_sha256=sha(pixels), codebook_sha256=sha(books[ci]))
    images, rows = [], []
    for view in refs:
        for d in groups[view['resource_reference']]['frames']:
            image = decoded[d]
            if view['flags_byte2'] & 64:
                image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            images.append(image)
            rows.append(dict(view_slot=view['slot'], descriptor=d, mirrored=bool(view['flags_byte2'] & 64), **provenance[d]))
    for key, action in actions.items():
        for d in groups[action['resource']]['frames']:
            images.append(decoded[d])
            rows.append(dict(view_slot=-1, action_key=key, descriptor=d, mirrored=False, **provenance[d]))
    reference = decoded[733].getbbox()
    require(reference == (46,82,260,137), 'Original encounter anchor changed')
    # The final collapse poses can be empty. Preserve them as source frames.
    union, scale, centre = shared_canvas([image for image in images if image.getbbox()], reference, 12.0)
    out.mkdir(parents=True, exist_ok=True)
    for image, row in zip(images, rows):
        crop = image.crop(union)
        restored = Image.new('L', image.size)
        restored.paste(crop, union[:2])
        # Undo mirroring before comparing to the independently decoded original.
        if row['mirrored']:
            restored = restored.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        require(restored.tobytes() == decoded[row['descriptor']].tobytes(), 'Directional crop loses pixels')
        name = (f"view_{row['view_slot']}" if row['view_slot'] >= 0 else f"action_{row['action_key']}") + f"_frame_{row['descriptor']}.png"
        crop.save(out/name)
        row.update(png=name, png_sha256=sha((out/name).read_bytes()), indices_sha256=sha(crop.tobytes()))
    report = dict(cache_sha256=HASH, source_entry_sha256=source['entry_sha256'],
                  native_state=state, entity_record=4, entity_name='Roach',
                  canvas_size=[union[2]-union[0],union[3]-union[1]], crop_box=list(union),
                  centre_offset=centre, world_units_per_pixel=scale,
                  actions={str(k):dict(**a, frames=[r for r in rows if r.get('action_key')==k]) for k,a in actions.items()},
                  views=[dict(slot=v['slot'], resource=v['resource_reference'], mirrored=bool(v['flags_byte2'] & 64),
                              frames=[r for r in rows if r['view_slot'] == v['slot']]) for v in refs],
                  scope='Original selector2 views and action5/14 source links. Bit40 mirrors full source before a common lossless crop; empty collapse frames retained. Native bearing and action lookup verified separately. Action5 impact uses the native kind1 frame12 marker. Combat assignment, damage amount, world scale, facing and8fps remain prototype choices; native clock-to-seconds and full AI semantics unverified.')
    (out/'animation.json').write_text(json.dumps(report, indent=2)+'\n')
    # The verifier independently checks these inputs against original instructions.
    fixtures = [dict(dx=x, dy=y, bearing=bearing(x,y)) for x in BEARING_VALUES for y in BEARING_VALUES]
    (out/'bearing_fixtures.json').write_text(json.dumps(fixtures, indent=2)+'\n')
    print(dict(source_frames=len(decoded), views=len(refs), reconstructions=len(rows), canvas=report['canvas_size']))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('game','texture','output-root'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    output=a.output_root.resolve()
    if output.exists():p.error('Output must be fresh')
    for source in (a.game.resolve(),a.texture.resolve()):
        if output==source or output in source.parents or source in output.parents:p.error('Output overlaps input')
    try:export(a.game.resolve(),a.texture.resolve(),output/'assets/lol2/generated/encounter_directions')
    except (ValueError,OSError,KeyError,IndexError,struct.error) as error:p.error(str(error))
