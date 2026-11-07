#!/usr/bin/env python3
"""Prepare pinned hive ambush films (HW07, EX05, EX06), source placements and region716/444 polygons.

Evidence comes from docs/hive-remaining-actor-triggers.json and the hash-pinned L5_HC/L5_HCI archives.
Exact background keying (cyan, or magenta for HW07) and the billboard ground anchor are explicit preview presentation choices, not native parity.
Original VQA payloads and raw decoder logs stay beneath the explicit output staging root.
"""
import re
import hashlib
import json
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

sys.path[:0] = [str(Path(__file__).resolve().parent)]
from lol2_source_format import parse_mix, u32
from lol2_movie_format import ww_hash_v1
import argparse
GAME = None

REPO = Path(__file__).resolve().parents[1]
PROOF = None
GEOMETRY = None
NEST_REVIEW = None
LOCAL = None
OUT = None
GEOMETRY_KEY, META_KEY = 3776990464, 3776335874
KEYS = {(0, 251, 251): 'cyan', (251, 0, 251): 'magenta'}
COLUMNS = 8
STEMS = {'EX05.VQA': 'ex05_eating', 'EX06.VQA': 'ex06_eat_to_attack', 'HW07.VQA': 'hw07_unfold'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def decode(binding, movie_archive, entries):
    name = binding['file']
    entry = next(e for e in entries if e['key'] == ww_hash_v1(name))
    raw = movie_archive[entry['offset']:entry['offset'] + entry['size']]
    assert sha(raw) == binding['sha256'], name
    stem = STEMS[name.split('\\')[-1]]
    source_path = LOCAL / f'{stem}.vqa'
    source_path.write_bytes(raw)
    w, h, n = binding['width'], binding['height'], binding['frames']
    with tempfile.TemporaryDirectory(prefix='hive_ambush_') as temp:
        raw_path = Path(temp) / 'frames.rgb'
        decoded = subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source_path), '-an',
                                  '-pix_fmt', 'rgb24', '-f', 'rawvideo', str(raw_path)],
                                 check=True, capture_output=True)
        pixels = raw_path.read_bytes()
    stride = w * h * 3
    assert len(pixels) == n * stride, (name, len(pixels) / stride)
    probe = subprocess.run(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(source_path)],
                           check=True, capture_output=True)
    streams = json.loads(probe.stdout)['streams']
    video = [s for s in streams if s['codec_type'] == 'video']
    audio = [s for s in streams if s['codec_type'] == 'audio']
    assert len(video) == 1
    frames = np.frombuffer(pixels, dtype=np.uint8).reshape(n, h, w, 3)
    hashes = [sha(frames[i].tobytes()) for i in range(n)]
    corners = {tuple(int(c) for c in frames[i][y, x]) for i in range(n) for y, x in ((0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1))}
    assert len(corners) == 1 and next(iter(corners)) in KEYS, (name, corners)
    key = next(iter(corners))
    opaque = ~np.all(frames == np.array(key, dtype=np.uint8), axis=3)
    per_frame = []
    for i in range(n):
        rows, cols = np.nonzero(opaque[i].any(axis=1))[0], np.nonzero(opaque[i].any(axis=0))[0]
        per_frame.append(None if not len(rows) else dict(
            left=int(cols[0]), top=int(rows[0]), right=int(cols[-1]), bottom=int(rows[-1]),
            opaque_pixels=int(opaque[i].sum())))
    boxes = [b for b in per_frame if b]
    union = dict(left=min(b['left'] for b in boxes), top=min(b['top'] for b in boxes),
                 right=max(b['right'] for b in boxes), bottom=max(b['bottom'] for b in boxes))
    rows = (n + COLUMNS - 1) // COLUMNS
    alpha = np.where(opaque, 255, 0).astype(np.uint8)
    rgba = np.concatenate([frames, alpha[..., None]], axis=3)
    sheet = np.zeros((rows * h, COLUMNS * w, 4), dtype=np.uint8)
    for i in range(n):
        y, x = (i // COLUMNS) * h, (i % COLUMNS) * w
        sheet[y:y + h, x:x + w] = rgba[i]
    atlas = f'{stem}_atlas.png'
    Image.fromarray(sheet, 'RGBA').save(OUT / atlas)
    check = np.array(Image.open(OUT / atlas).convert('RGBA'))
    for i in range(n):
        y, x = (i // COLUMNS) * h, (i % COLUMNS) * w
        assert sha(np.ascontiguousarray(check[y:y + h, x:x + w, :3]).tobytes()) == hashes[i]
    (LOCAL / (stem + '_decoder.log')).write_bytes(decoded.stderr)
    (LOCAL / (stem + '_probe.log')).write_bytes(probe.stderr)
    return dict(template=binding['template'], selector=binding['selector'], resource=binding['resource'],
                file=name, label=binding['label'], source_sha256=binding['sha256'],
                mix_entry=dict(key=entry['key'], offset=entry['offset'], size=entry['size']),
                frames=n, width=w, height=h, fps=binding['fps'], columns=COLUMNS, rows=rows,
                atlas=atlas, atlas_sha256=sha((OUT / atlas).read_bytes()),
                decoded_frame_hashes=hashes, video_streams=len(video), audio_streams=len(audio),
                stream_codecs=[s.get('codec_name') for s in streams], key_rgb=list(key), key_name=KEYS[key],
                opaque_bounds=per_frame, opaque_union=union,
                opaque_baseline_first_frame=per_frame[0]['bottom'] if per_frame[0] else None,
                opaque_baseline_max=union['bottom'],
                decoder_stderr=re.sub(r'0x[0-9a-fA-F]+', '<address>', decoded.stderr.decode()), probe_stderr=re.sub(r'0x[0-9a-fA-F]+', '<address>', probe.stderr.decode()))


def main():
    proof = json.loads(PROOF.read_text())
    LOCAL.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    movie_archive = (GAME / 'DAT/L5_HCI.MIX').read_bytes()
    assert sha(movie_archive) == proof['movie_archive_sha256']
    movie_entries = parse_mix(movie_archive)
    order = {'HW07.VQA': 0, 'EX05.VQA': 1, 'EX06.VQA': 2}
    bindings = sorted(proof['movie_bindings'], key=lambda b: order[b['file'].split('\\')[-1]])
    assert [(b['template'], b['frames']) for b in bindings] == [(43, 25), (41, 54), (41, 17)]
    clips = [decode(b, movie_archive, movie_entries) for b in bindings]

    archive = (GAME / 'DAT/L5_HC.MIX').read_bytes()
    assert sha(archive) == proof['archive_sha256']
    entries = parse_mix(archive)
    ge, me = [next(e for e in entries if e['key'] == key) for key in (GEOMETRY_KEY, META_KEY)]
    geo, meta = [archive[e['offset']:e['offset'] + e['size']] for e in (ge, me)]
    geometry = json.loads(GEOMETRY.read_text())
    assert geometry['source']['sha256'] == proof['archive_sha256']
    assert geometry['source']['entry_sha256'] == sha(geo)

    def owner(kind, index):
        offset, stride = (0x14, 37) if kind == 'prop' else (0x1c, 56)
        start = u32(geo, offset) + index * stride
        record = geo[start:start + stride]
        x, y, heading, z = struct.unpack_from('<hhHh', record)
        row = dict(kind=kind, index=index, position=[x, z, -y], heading=heading,
                   source_offset=ge['offset'] + start, raw_hex=record.hex())
        if kind == 'prop':
            row['template'] = struct.unpack_from('<H', record, 32)[0]
        return row

    constructor = {(c['kind'], c['index']): c for c in proof['shared_constructor']}
    placements = []
    for kind, index in [('prop', 316), ('prop', 318), ('prop', 363), ('actor', 33), ('actor', 35), ('prop', 317)]:
        row = owner(kind, index)
        if kind == 'prop' and (kind, index) in constructor:
            assert row['template'] == constructor[(kind, index)]['template'], row
        row['constructor'] = constructor.get((kind, index))
        placements.append(row)
    assert placements[-1]['template'] == 42

    base, count = u32(meta, 8), u32(meta, 0x40)
    templates = {index: meta[base + index * 55:base + (index + 1) * 55].hex() for index in (41, 42, 43)}
    assert len(set(templates.values())) == 3
    template_differences = {f'{a}_vs_42': [i for i in range(55) if meta[base + a * 55 + i] != meta[base + 42 * 55 + i]]
                            for a in (41, 43)}

    vertices = geometry['vertices_fixed']

    def polygon(row):
        return [[vertices[v][0] / 65536, -vertices[v][1] / 65536] for v in row['vertex_indices']]

    def inside(point, poly):
        x, y, hit = point[0], point[1], False
        for (ax, ay), (bx, by) in zip(poly, poly[1:] + poly[:1]):
            if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
                hit = not hit
        return hit

    regions = []
    for index in (444, 716, 723):
        row = geometry['regions'][index]
        assert row['id'] == index
        regions.append(dict(region=index, polygon=polygon(row), vertex_indices=row['vertex_indices'],
                            floor_corners=row['floor_corners'], ceiling_corners=row['ceiling_corners'],
                            floor=min(row['floor_corners']), ceiling=max(row['ceiling_corners']),
                            neighbors=row['neighbors'], source_offset=row['source_offset']))
    for row in placements:
        point = [row['position'][0], row['position'][2]]
        found = [r['id'] for r in geometry['regions'] if r.get('record_role') == 'primary_region'
                 and len(r['vertex_indices']) >= 3 and inside(point, polygon(r))]
        row['containing_regions'] = [dict(region=i, floor=min(geometry['regions'][i]['floor_corners']),
                                          ceiling=max(geometry['regions'][i]['ceiling_corners'])) for i in found]

    nest_clips = proof['nest_clips']
    assert not {c['source_sha256'] for c in nest_clips} & {c['source_sha256'] for c in clips}

    result = dict(
        schema='lol2-hive-ambush-media-v1',
        archive_sha256=proof['archive_sha256'], movie_archive_sha256=proof['movie_archive_sha256'],
        geometry_entry=dict(key=ge['key'], offset=ge['offset'], size=ge['size'], sha256=sha(geo)),
        metadata_entry=dict(key=me['key'], offset=me['offset'], size=me['size'], sha256=sha(meta)),
        clips=clips, placements=placements, regions=regions,
        prop_templates_hex=templates, prop_template_differing_bytes=template_differences,
        nest317_template42_clips=nest_clips,
        billboard_alignment=dict(
            authored=True,
            rule='Preview anchor: clip opaque_baseline_max row (lowest opaque row over all frames) sits on the '
                 'floor of the placement containing region; clip horizontal centre (x=width/2) on the source position.',
            world_size=None,
            note='Original on-screen or world dimensions of these films are not recovered; no size is asserted. '
                 'Lead chooses presentation scale.'),
        scope='Pinned HW07/EX05/EX06 payloads hash-checked against movie_bindings; every RGB frame decoded, '
              'counted and hashed; stream counts from ffprobe. Every frame has one uniform corner colour '
              '(EX05/EX06 cyan 0,251,251; HW07 magenta 251,0,251), exact-keyed to alpha. Placements re-read from '
              'the pinned L5_HC geometry entry; regions444/716, plus region723 containing prop318/363 and actor35, from '
              'geometry.json whose entry hash matches. Templates41/43 are distinct from nest317 template42. '
              'Trigger sequencing, loop policy, native scale and live encounters are not claimed.')
    (OUT / 'ambush.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(clips=[dict(file=c['file'], frames=c['frames'], video=c['video_streams'],
                                      audio=c['audio_streams'], baseline=c['opaque_baseline_max'],
                                      first_baseline=c['opaque_baseline_first_frame'], union=c['opaque_union'],
                                      warnings=c['decoder_stderr']) for c in clips],
                          placements=[dict(kind=p['kind'], index=p['index'], position=p['position'],
                                           template=p.get('template'), regions=p['containing_regions'])
                                      for p in placements],
                          regions=[dict(region=r['region'], floor=r['floor'], ceiling=r['ceiling'],
                                        points=len(r['polygon'])) for r in regions]), indent=1))


def explicit_main():
    global GAME, PROOF, GEOMETRY, LOCAL, OUT
    p=argparse.ArgumentParser(description='Prepare complete Hive ambush media from explicit inputs')
    for name in ['game','recipe','geometry','output-root']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args()
    output=a.output_root.resolve()
    if output.exists():p.error('Output must be a fresh directory')
    for source in (a.game,a.recipe,a.geometry):
        source=source.resolve()
        if source==output or source in output.parents or output in source.parents:p.error('Output overlaps an input')
    try:
        if sha(a.recipe.read_bytes())!='6ac631aa21e93d1fe708fc38c1e6f5695cf05aaadf056644eb73446afaf04aa5':p.error('Unsupported preparation recipe')
        proof=json.loads(a.recipe.read_text())
        for file,key in [('DAT/L5_HC.MIX','archive_sha256'),('DAT/L5_HCI.MIX','movie_archive_sha256')]:
            if sha((a.game/file).read_bytes())!=proof[key]:p.error('Unsupported original '+file)
        geometry=json.loads(a.geometry.read_text())
        if geometry['source']['sha256']!=proof['archive_sha256'] or geometry['source']['entry_sha256']!='69a9c0dd739ad36691c6513d53cf007204aa3bd35d5762e8f8f4e8c6dbcb9e85':p.error('Wrong Hive geometry')
    except (OSError,ValueError,KeyError) as error:p.error(str(error))
    GAME=a.game.resolve();PROOF=a.recipe.resolve();GEOMETRY=a.geometry.resolve()
    LOCAL=output/'tmp/hive_ambush';OUT=output/'assets/lol2/generated/hive_ambush'
    main()


if __name__ == '__main__':
    explicit_main()
