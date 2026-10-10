#!/usr/bin/env python3
"""Pin the Cave prop83 hit -> sound -> selector2 -> g264 chain that lifts the control75 (Mana foil) shaft floor.

prop83 (template92, at (387,-192,-11066), region1040, placement durability byte30 = 2):
  kind9 g108: masks 0x0906/0x0004, mode4, threshold9, owner state0 -> op20 sound request 956 (0x3BC).
  kind9 g124: masks 0x0011/0x0001, mode4, threshold9, owner state0 -> op198 local25 = 1, op20 sound 956.
  kind8 value956 (sound finished, AE510 walker; value = request) at state0, g146: op9 self property8, op21, op18
      (flags word 0x0805, bit 0x20 clear: no queued command), op5 selector2, op16 state1, op9 props 190/473
      property2, op204 materials on regions 1037/1039/1041, op6 event1 on prop614, op16 state1, op9 self property21.
  kind3 value2 (selector2 reached), g264: op9 self property16, op196 floor of shaft regions
      397/434/436/451/452/503/505/506 -> -290 (absolute, speed5, byte6 bit4), op20 sound, op9 props 1047..1049
      property3, op196 floor of regions 1029..1033 by -160 (relative, speed0 = immediate): the zero-height wall
      regions (floor = ceiling = -32) open into a 160-unit passage toward the chamber; only corridor1820..1822 becomes reachable (source slopes still seal the main chamber).
Usage: prepare_cave_prop83_lift.py --output scripts/lol2/cave_prop83_lift_source.json
"""
import argparse, json, struct, sys, wave
from pathlib import Path
from verify_actor_item_grants import source_area
from build_game_atlas import section
from prepare_jungle_exit_encounter import predicate

ROOT = Path(__file__).resolve().parents[1]
GEOMETRY = Path('/home/bob/lol2_out/all_maps_20260922/L1_DC/geometry/geometry.json')
SHAFT = [397, 434, 436, 451, 452, 503, 505, 506]
POCKET = [397, 431, 434, 436, 451, 452, 503, 505, 506]
WALL = [1029, 1030, 1031, 1032, 1033]


def mover(cmd):
    b = bytes.fromhex(cmd); assert b[0] == 0xC4 and b[1] == 0x90 and len(b) == 12, cmd
    region, target = struct.unpack_from('<Hh', b, 2)
    return dict(region=region, surface='ceiling' if b[6] & 1 else 'floor', target=target, relative=bool(b[6] & 8), speed=b[7], flags=b[6])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    area, arc, entry, raw, owners, streams = source_area('L1_DC')
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    _, _, placements = section(raw, 0x14, 0x60, 37)
    rows = {}
    for r in [r for r in owners if r['owner_kind'] == 'prop' and r['owner'] == 83]:
        rows[r['group']] = dict(kind=r['event'], value=r['value'], predicate=predicate(table, r['predicate'])['raw'] if r['predicate'] is not None else None,
                                raw=arc[r['archive_offset']:r['archive_offset'] + arc[r['archive_offset']]].hex(), commands=[c['raw_hex'] for c in streams[r['stream']][r['group']]])
    assert placements[83 * 37 + 30] == 2
    h108, h124, s146, l264 = rows[108], rows[124], rows[146], rows[264]
    assert h108['raw'] == '0a096c00060904000904' and h108['predicate'] == '0005000000' and h108['commands'] == ['14035300bc03ff010f00']
    assert h124['raw'] == '0a097c00110001000904' and h124['predicate'] == '0005000000' and h124['commands'] == ['c60000001901', '14035300bc03ff010f00']
    assert s146['kind'] == 8 and s146['value'] == 956 and s146['predicate'] == '0005000000'
    assert '050353000200' in s146['commands'] and s146['commands'].count('100353000100') == 2
    op18 = next(c for c in s146['commands'] if c.startswith('12'))
    assert not struct.unpack_from('<H', bytes.fromhex(op18), 10)[0] & 0x20  # B59CE: bit 0x20 clear -> no queued command
    assert l264['kind'] == 3 and l264['value'] == 2 and l264['predicate'] is None and l264['commands'][0] == '090353001000'
    moves = [mover(c) for c in l264['commands'] if c.startswith('c4')]
    shaft = [m for m in moves if m['region'] in SHAFT]; wall = [m for m in moves if m['region'] in WALL]
    assert sorted(m['region'] for m in shaft) == SHAFT and all(m == dict(region=m['region'], surface='floor', target=-290, relative=False, speed=5, flags=0x10) for m in shaft)
    assert sorted(m['region'] for m in wall) == WALL and all(m == dict(region=m['region'], surface='floor', target=-160, relative=True, speed=0, flags=0x08) for m in wall)
    g = json.loads(GEOMETRY.read_text()); R = g['regions']; V = g['vertices_fixed']
    def poly(r): return [[V[v][0] / 65536, -V[v][1] / 65536] for v in R[r]['vertex_indices']]
    regions = {}
    for r in POCKET:
        assert R[r]['floor_base'] == -1000 and R[r]['ceiling_base'] == 5
        regions[str(r)] = dict(polygon=poly(r), floor=-1000, ceiling=5, neighbors=R[r]['neighbors'])
    for r in WALL:
        assert R[r]['floor_base'] == -32 and R[r]['ceiling_base'] == -32
        # Per edge i (vertex i -> i+1): the neighbour's floor and ceiling at those two shared vertices (per-vertex
        # source corners). After the opening the passage floor is -192: an edge needs wall where the neighbour floor
        # stands higher (the chamber edge slopes 1026/1027/1028 top out at -32 there) or has no neighbour.
        vi = R[r]['vertex_indices']; edges = []
        for i, nb in enumerate(R[r]['neighbors']):
            a_v, b_v = vi[i], vi[(i + 1) % len(vi)]
            if nb is None or nb in WALL: edges.append(dict(neighbor=nb, floor=None, ceiling=None)); continue
            nv = R[nb]['vertex_indices']
            fc = R[nb]['floor_corners'] or [R[nb]['floor_base']] * len(nv); cc = R[nb]['ceiling_corners'] or [R[nb]['ceiling_base']] * len(nv)
            assert a_v in nv and b_v in nv, (r, nb)
            edges.append(dict(neighbor=nb, floor=[fc[nv.index(a_v)], fc[nv.index(b_v)]], ceiling=[cc[nv.index(a_v)], cc[nv.index(b_v)]]))
        regions[str(r)] = dict(polygon=poly(r), floor=-32, ceiling=-32, neighbors=R[r]['neighbors'], edges=edges,
                               neighbor_spans={str(n): [R[n]['floor_base'], R[n]['ceiling_base']] for n in R[r]['neighbors'] if n is not None})
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from prepare_creature_audio_clips import stage_clips
    stage_clips(ROOT, 'cave_prop83_lift', [956])
    with wave.open(str(ROOT / 'assets/lol2/generated/cave_prop83_lift/956.wav')) as w: seconds = w.getnframes() / w.getframerate()
    # Prop83's own animated sprite (template92, 8 frames of the all-maps export): not in the recovered prop preview.
    import shutil, hashlib
    sprites = Path('/home/bob/lol2_out/all_maps_20260922/L1_DC/props/sprites')
    exported = {q['record']: q for q in json.loads(Path('/home/bob/lol2_out/all_maps_20260922/L1_DC/props/props.json').read_text())['props']}
    q83 = exported[83]; assert q83['template'] == 92 and q83['material'] == 'prop_19' and q83['animated']
    frames = sorted(sprites.glob('prop_19_frame_*.png'))
    frames = [f for f in frames if not f.name.endswith(('_index.png', '_shadow.png'))]
    assert len(frames) == 8, frames
    out_dir = ROOT / 'assets/lol2/generated/cave_prop83_lift'
    names = []
    for i in range(8):
        name = 'prop83_%d.png' % i; shutil.copyfile(sprites / ('prop_19_frame_%d.png' % i), out_dir / name); names.append(name)
        shutil.copyfile(sprites / ('prop_19_frame_%d_index.png' % i), out_dir / ('prop83_%d_index.png' % i))
    result = dict(version=1, source=area['source'], prop=83, position=[387, -192, -11066], durability=2,
                  sprite=dict(frames=names, index_frames=[n.replace('.png', '_index.png') for n in names], left=q83['left'], right=q83['right'], bottom=q83['bottom'], top=q83['top'], frame_seconds=0.1),
                  hits={'108': dict(mask0=0x0906, mask2=0x0004, mode=4, threshold=9, local25=False),
                        '124': dict(mask0=0x0011, mask2=0x0001, mode=4, threshold=9, local25=True)},
                  sound=dict(request=956, file='956.wav', seconds=round(seconds, 4)), groups={k: rows[k] for k in (108, 124, 146, 264)},
                  shaft_movers=shaft, wall_movers=wall, regions=regions, speed_units_per_second_per_byte=2.5,
                  adapters=['an armed melee strike aimed at prop83 in reach is the g108 producer (context 2/4); a Spark ray hitting prop83 is g124 (1/1)',
                            'the kind8 sound-finished event fires when the staged 956 clip ends (its sample length)',
                            'op196 speed = byte7 x 2.5 units/s (assumed [0x22C54] = 16.16 ticks at 60/s); speed0 moves at once',
                            'a rising shaft floor carries a player standing on it',
                            'the opened wall regions replace their solid-block wall faces by a floor at -192 and walls on open edges',
                            'prop83 is drawn from its 8 exported frames at 10 frames/s (native animation clock not replayed)',
                            'op9 property effects (other than property16 hiding prop83), op204 materials, op21 and op6 event1 on prop614 are not hosted'],
                  scope='Direct source records; the region and mover sets are asserted byte for byte.')
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS cave prop83 lift: sound956 %.3f s, %d shaft movers, %d wall movers' % (seconds, len(shaft), len(wall)))


if __name__ == '__main__':
    main()
