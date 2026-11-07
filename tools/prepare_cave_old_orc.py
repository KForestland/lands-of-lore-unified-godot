#!/usr/bin/env python3
"""Pin the L1_DC dying old orc (control136, template20 -> resource311 orc-diee.vqa) and stage its original movie.

Playtest 2026-10-17 report11:02:43 ("here should be the old ork speaking to Luther"): the owner camera looks straight at
control136 at (1452, -216, -12257), between the two template44 columns. The recovered Cave hosts no owner for it and no
runtime file references orc-diee.vqa (835 frames, 15 fps, 392x456 stored sideways, IMA voice track).

Source contract (asserted below, raw bytes in the output):
  regions 1350/1859 event2 (entry edge) with predicate16 (local3==0): op8 load, op8 sub7 repeat 0x00ff, op8 sub10 loop0.
  regions 838/1349 event2: op8 sub1 (clear the clip).
  control136 kind4 (use) at state0/2/4: op18 player viewpoint (g10680/g10810), conversation segment 1/3/5 played once
  (op8 sub7 0), op2 player sub0x26, local51=1, state1/3/6; g10932 also sets local3=1.
  kind6 (clip end) at state1/3: op2 player sub0x27, local51=0, loop2/loop4 repeating, state2/4.
  kind6 with local3==1: op8 sub1 clear, op6 sub2, state7 (the orc is gone).
  kind9 masks0/0 threshold2 mode0x84 (one-shot), predicates59/60 (local3==0, local51 0/1): op206, op9 properties18/20,
  segment5 once, state7, local3=1 (talking or idle, the hit jumps to the last line).
  kind2 timer (value word 0x0130, flags0x30 fixed byte6=4, countdown240) at state1: op14 sub4 stop, op6 sub1.
VQA LINF loops (first,last frame) and LNIN names: 0 Loiter, 1 OR450-453, 2 Loiter, 3 OR454-460, 4 Loiter, 5 OR461-462.
Usage: prepare_cave_old_orc.py --game GAME_ROOT --output scripts/lol2/cave_old_orc_source.json
"""
import argparse, hashlib, json, struct, sys, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MAP = Path('~/lol2_out/all_maps_20260922/L1_DC')
CONTROL = 136
CONTROL_HEX = 'ac05e12f5bb028ff82465203701818830000000001000000000000001400030014'
MOVIE = 'orc-diee.vqa'
MOVIE_SHA = 'a4583c5316fcd66e38fe6156c2f38ca38ea28680aad2713d30c75f73e0848226'
GROUPS = {
    10680: (4, 2, ['120100007405cc2f00008102c73100320000', '020100002600', '021088000500', 'c60000003301', '091088001400', '0810880007000000', '081088000a000100', '0e10880003000000', '101088000100']),
    10758: (6, 3, ['091088001400', '020100002700', '021088000600', 'c60000003300', '081088000700ff00', '081088000a000200', '101088000200']),
    10810: (4, 11, ['120100007405cb2f00008102c73100320000', '020100002600', '021088000500', 'c60000003301', '091088001400', '0810880007000000', '081088000a000300', '101088000300']),
    10880: (6, 209, ['020100002700', '021088000600', 'c60000003300', '091088001400', '081088000700ff00', '081088000a000400', '101088000400']),
    10932: (4, 210, ['091088001200', 'c60000000301', '091088001400', '0810880007000000', '081088000a000500', '101088000600']),
    10978: (6, 17, ['0810880001000000', '061088000200', '101088000700']),
    11004: (9, 60, ['ce00000000ff', '091088001200', '091088001400', '020100002700', '021088000600', '0810880007000000', '081088000a000500', '101088000700', 'c60000000301']),
    11068: (9, 59, ['ce00000000ff', '091088001200', '091088001400', '020100002700', '0810880007000000', '081088000a000500', '101088000700', 'c60000000301']),
    11126: (2, 3, ['0e10880004000000', '061088000100']),
}
REGIONS = {838: (None, ['0810880001000000']), 1349: (None, ['0810880001000000']),
           1350: (16, ['0810880000000000', '081088000700ff00', '081088000a000000']),
           1859: (16, ['0810880000000000', '081088000700ff00', '081088000a000000'])}
LOOPS = [(0, 19, 'HLoit000ORLoiter'), (20, 278, 'HOthr000OR450-453'), (279, 301, 'HLoit000ORLoiter'),
         (302, 752, 'HOthr000OR454-460'), (753, 766, 'HLoit000ORLoiter'), (767, 834, 'HOthr000OR461-462')]


def chunk(blob, name):
    from lol2_movie_format import parse_vqa_chunks
    rows = [v for k, v in parse_vqa_chunks(blob) if k == name]
    assert len(rows) == 1, name
    return rows[0]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): sys.exit('refusing to overwrite ' + str(a.output))
    out = ROOT / 'assets/lol2/generated/cave_old_orc'
    if out.exists(): sys.exit('refusing to overwrite ' + str(out))
    sys.path.insert(0, str(Path(__file__).resolve().parent / 'lol2'))
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from verify_actor_item_grants import source_area
    from build_game_atlas import section
    from prepare_jungle_exit_encounter import predicate
    from lol2_source_format import parse_mix
    from lol2_material_format import sections
    from lol2.map_video_inventory import lookup_movie
    from lol2_movie_format import parse_vqa_chunks
    from lol2_movie_media import decode, audio
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    u32 = lambda b, o: struct.unpack_from('<I', b, o)[0]
    control = raw[u32(raw, 0x18) + CONTROL * 33:][:33]
    assert control.hex() == CONTROL_HEX and control[32] == 20
    x, y, heading, h = struct.unpack_from('<hhHh', control, 0)
    assert (x, -y, h) == (1452, -12257, -216)
    meta_entry = [e for e in parse_mix(arc) if arc[e['offset']:e['offset'] + 8] == struct.pack('<II', 18, 516)]
    assert len(meta_entry) == 1
    meta = arc[meta_entry[0]['offset']:meta_entry[0]['offset'] + meta_entry[0]['size']]
    t20 = meta[u32(meta, 12) + 20 * 60:][:60]
    assert struct.unpack_from('<H', t20, 0x24)[0] == 311 and list(t20[47:50]) == [120, 0, 90]
    texture = (MAP / 'texture.bin').read_bytes(); sec = sections(texture)
    d = struct.unpack_from('<6H11I', texture, sec[2] + 311 * 56)
    payload = texture[sec[3] + d[7]:sec[3] + d[7] + d[12]]
    assert payload[8:20] == b'orc-diee.vqa', payload
    # Source groups of control136 and the four entry regions.
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    records = []
    for o in owners:
        if o['owner_kind'] != 'control' or o['owner'] != CONTROL: continue
        cmds = [c['raw_hex'] for c in streams[o['stream']][o['group']]]
        kind, pred, want = GROUPS[o['group']]
        assert (o['event'], o['predicate'], cmds) == (kind, pred, want), o
        head = arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]]
        records.append(dict(group=o['group'], kind=kind, raw=head.hex(), predicate=predicate(table, pred), commands=cmds))
    assert sorted(r['group'] for r in records) == sorted(GROUPS)
    k9 = [bytes.fromhex(r['raw']) for r in records if r['kind'] == 9]
    assert all(b[4:8] == bytes(4) and b[8] == 2 and b[9] == 0x84 for b in k9)
    timer = bytes.fromhex(next(r['raw'] for r in records if r['kind'] == 2))
    assert timer[4:10] == bytes.fromhex('30010404f000'), timer.hex()
    geometry = json.loads((MAP / 'geometry/geometry.json').read_text())
    regions = []
    for o in owners:
        if o['owner_kind'] != 'region' or o['owner'] not in REGIONS: continue
        pred, want = REGIONS[o['owner']]
        cmds = [c['raw_hex'] for c in streams[o['stream']][o['group']]]
        assert (o['event'], o['predicate'], cmds) == (2, pred, want), o
        row = geometry['regions'][o['owner']]
        regions.append(dict(region=o['owner'], group=o['group'], predicate=predicate(table, pred) if pred is not None else None,
                            commands=cmds, floor_min=min(row['floor_corners']), floor_max=max(row['floor_corners']),
                            polygon=[[geometry['vertices_fixed'][v][0] / 65536, -geometry['vertices_fixed'][v][1] / 65536] for v in row['vertex_indices']]))
    assert sorted(r['region'] for r in regions) == sorted(REGIONS)
    regions.sort(key=lambda r: r['region'])
    # Original movie, loops and voice.
    found = lookup_movie(a.game, 'L1_DC', MOVIE)
    assert found['sha256'] == MOVIE_SHA, found['sha256']
    head = found['vqhd']; assert (head['count'], head['width'], head['height'], head['fps']) == (835, 392, 456, 15)
    lind = chunk(found['blob'], b'LINF'); assert lind[:4] == b'LINH' and lind[14:18] == b'LIND'
    pairs = struct.unpack_from('<12H', lind, 22)
    names = chunk(found['blob'], b'LNIN').split(b'LNID')[1][4:].split(b'\x00')
    loops = [(pairs[2 * i], pairs[2 * i + 1], names[i].decode()) for i in range(6)]
    assert loops == LOOPS, loops
    cache = ROOT / 'tmp/cave_old_orc'; cache.mkdir(parents=True, exist_ok=True)
    path = cache / 'orc-diee.vqa'; path.write_bytes(found['blob'])
    frames = decode(path, cache / 'frames', 835, (392, 456))
    out.mkdir(parents=True)
    rows = []
    for i, fp in enumerate(frames):
        im = Image.open(fp).convert('RGBA').transpose(Image.Transpose.ROTATE_270)
        im.putdata([(r, g, b, 0) if (r, g, b) == (0, 251, 251) else (r, g, b, 255) for r, g, b, _ in im.getdata()])
        dst = out / f'frame_{i:03d}.png'; im.save(dst, optimize=True)
        rows.append(dict(file='res://' + str(dst.relative_to(ROOT)), sha256=hashlib.sha256(dst.read_bytes()).hexdigest()))
    # Indexed frames (2026-10-31, report 09-19-01): the Cave draws its world through index buffers and the host palette, so a
    # 2D movie overlay cannot be occluded by the stone in front of the orc. Each cut-out frame is quantised to the Cave palette
    # (wall_indices/palette.png, the L1_DC palette the indexed viewports resolve with; index 0 = transparent) and drawn as an
    # indexed billboard on the world layer. The RGB frames above stay the proven decode; the index frames are an adapter.
    import numpy as np
    palette_png = ROOT / 'assets/lol2/generated/wall_indices/palette.png'
    pal = np.asarray(Image.open(palette_png).convert('RGB'), dtype=np.int32).reshape(256, 3)
    index_rows = []
    nearest = {}  # packed RGB -> palette index (never 0, which is transparent)
    for i, fp in enumerate(frames):
        im = Image.open(out / f'frame_{i:03d}.png').convert('RGBA')
        px = np.asarray(im, dtype=np.int32)
        rgb = px[..., :3].reshape(-1, 3); alpha = px[..., 3].reshape(-1)
        packed = (rgb[:, 0] << 16) | (rgb[:, 1] << 8) | rgb[:, 2]
        unique = np.unique(packed[alpha != 0])
        missing = [int(u) for u in unique if int(u) not in nearest]
        if missing:
            cols = np.array([[u >> 16, (u >> 8) & 255, u & 255] for u in missing], dtype=np.int32)
            d = ((cols[:, None, :] - pal[None, 1:, :]) ** 2).sum(axis=2)
            for u, k in zip(missing, d.argmin(axis=1)): nearest[u] = int(k) + 1
        best = np.zeros(packed.shape[0], dtype=np.uint8)
        opaque = alpha != 0
        best[opaque] = np.vectorize(nearest.__getitem__, otypes=[np.uint8])(packed[opaque])
        idx = Image.fromarray(best.reshape(px.shape[0], px.shape[1]), mode='L')
        dst = out / f'index_{i:03d}.png'; idx.save(dst, optimize=True)
        index_rows.append(dict(file='res://' + str(dst.relative_to(ROOT)), sha256=hashlib.sha256(dst.read_bytes()).hexdigest()))
    samples = sum(len(v) * 2 for k, v in parse_vqa_chunks(found['blob']) if k == b'SND2')
    rate = audio(path, out / 'voice.wav', samples)
    result = dict(version=1, source=dict(area='L1_DC', archive_sha256=hashlib.sha256(arc).hexdigest()),
                  control=CONTROL, control_hex=CONTROL_HEX, position=[x, h, -y], dimensions=[t20[47], t20[49]],
                  template=20, template_hex=t20.hex(), resource=311, descriptor_payload=payload.hex(),
                  movie=MOVIE, movie_archive=found['archive'], movie_sha256=MOVIE_SHA, fps=15, width=456, height=392,
                  loops=[dict(index=i, first=f, last=l, name=n) for i, (f, l, n) in enumerate(loops)],
                  frames=rows, index_frames=index_rows, index_palette='res://assets/lol2/generated/wall_indices/palette.png',
                  index_palette_sha256=hashlib.sha256(palette_png.read_bytes()).hexdigest(),
                  audio='res://' + str((out / 'voice.wav').relative_to(ROOT)),
                  voice_sha256=hashlib.sha256((out / 'voice.wav').read_bytes()).hexdigest(), samples=samples, rate=rate,
                  records=records, regions=regions,
                  timer=dict(flags=timer[4], countdown=struct.unpack_from('<H', timer, 8)[0], fixed=timer[6], enabled=not (timer[5] & 1)),
                  adapters=['frames rotated 270 degrees and cyan-keyed (same presentation as the captain movie); world rectangle = template dims 120x90',
                            'index frames: each frame quantised to the Cave palette (nearest RGB, index 0 transparent) and drawn as an indexed billboard on the world layer so props occlude it (2026-10-31)',
                            'op2 player sub0x26/0x27 (native handler not decoded) are treated as the conversation lock/release',
                            'op6 sub1/sub2, op9 property18/20, op206 and op2 on the control are saved receipts only',
                            'kind2 timer: countdown240 at 60 ticks/s (4 s); flags0x30 reload multiplier [223A8] assumed 60',
                            'kind9 durability not decoded for controls: any landed hit admits (masks 0/0 are wildcards)',
                            'kind6 raised at the end of a non-repeating segment; looping segments raise none',
                            'use/hit only while a clip is shown (loaded by the region entry)'])
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    shutil.rmtree(cache)
    print('PASS cave old orc: control136, %d frames, %d loops, %d records, %d regions, voice %d samples @%d' % (len(rows), len(loops), len(records), len(regions), samples, rate))


if __name__ == '__main__':
    main()
