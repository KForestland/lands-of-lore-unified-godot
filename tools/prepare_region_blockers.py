#!/usr/bin/env python3
"""Player-impassable region edges for one area (native region word +0x1C bit0).

Native (LOLG.DAT, static):
- B0D98 / AFF85: a mover whose kind byte [0xB7D4D] is 1 or 4 is refused entry to a region with word +0x1C bit0 set;
  kind 2 is refused by bit1. The Bacatta57 seal (op197 sub2) uses bit0 as the player-impassable bit.
- op197 (dispatcher 64CD4, case table 0x64CA8): sub0 clears bit0, sub1 clears bit1, sub2 sets bit0, sub3 sets bit1,
  sub4 sets bits 0|1, sub5 clears bits 0|1; subs 6-10 touch other bytes.

Output: every open edge from a region with bit0 clear into a neighbour with bit0 set, plus each blocked region's
outline (Godot X/Z) so the host can tell when the player already stands inside one. Regions any op197 sub0/2/4/5 of
the area touches are left out of that static set (so it never disagrees with a runtime toggle) and listed separately
(2026-10-31, version 2): dynamic_initial (bit0 of the data), dynamic_outlines/heights, and dynamic_edges = every edge
with a dynamic region on either side (from a region that can be passable into one that can be blocked), tagged
from_dynamic / to_dynamic. region_blockers.gd builds the dynamic edges only when a native script host binder enables
them (act2_progression.gd), and toggles them from the host's 0x22d0c:N bit_0x1c_0x01 writes (opcode 197 arms 0-5).
Without a binder the pack behaves as before: the static set only.
--open-regions (2026-10-31, owner workaround rule): bit0 regions the original opens by a path the host does not read yet are
taken out of the static set and listed as open_regions (an adapter; its witness goes to docs/DEVIATIONS.md). Museum L3_DH 1422:
the escape run ends inside it; its only commands are five opcode-197 arm-10 list marks fired by the event-4 records of the
approach regions 1012/1013/1016/1017/1020 (the LIKELY opener; the bit-0 drops do not read that list, Grok backlog 4).

  PYTHONPATH=tools python3 tools/prepare_region_blockers.py --game-root GAME --area L4_HJ \\
      --geometry .../L4_HJ/geometry/geometry.json --out assets/lol2/generated/region_blockers/L4_HJ.json
"""
import argparse, hashlib, json, sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path[:0] = [str(TOOLS), str(TOOLS / 'lol2')]
BIT0_SUBS = {0, 2, 4, 5}


def op197_regions(area, game):
    from verify_actor_item_grants import source_area
    _, _, _, _, _, streams = source_area(area, game)
    found = {}

    def walk(o):
        if isinstance(o, dict):
            h = o.get('raw_hex')
            if isinstance(h, str) and h.startswith('c590'):
                b = bytes.fromhex(h)
                if b[4] in BIT0_SUBS: found.setdefault(int.from_bytes(b[2:4], 'little'), set()).add(b[4])
            for v in o.values(): walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(streams)
    return found


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game-root', type=Path, required=True)
    p.add_argument('--area', required=True)
    p.add_argument('--geometry', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--open-regions', default='', help='comma-separated bit0 region ids taken as open (adapter, see the docstring)')
    a = p.parse_args()
    opened = {int(x) for x in a.open_regions.split(',') if x.strip()}
    g = json.loads(a.geometry.read_text())
    archive = (a.game_root / 'DAT' / f'{a.area}.MIX').read_bytes()
    assert hashlib.sha256(archive).hexdigest() == g['source']['sha256'], 'geometry belongs to a different archive'
    dynamic = op197_regions(a.area, a.game_root.resolve())
    regions = {r['id']: r for r in g['regions']}
    # Floor-subdivision children carry no ceiling corners (L3_DH: 115 regions, all with an owner that has them); the
    # owner's ceiling stands in. The ceiling only sets the blocker's top (floor..ceiling+1024, the port adapter).
    for r in g['regions']:
        if r.get('ceiling_corners') is None:
            owner = r.get('owner')
            if owner is None or g['regions'][owner].get('ceiling_corners') is None: raise ValueError(f"region {r['id']}: no ceiling and no owner ceiling")
            r['ceiling_corners'] = list(g['regions'][owner]['ceiling_corners'])
    v = g['vertices_fixed']
    for n in opened:
        if n not in regions or not (regions[n]['flags'] & 1): raise ValueError(f'--open-regions {n}: not a bit0 region of {a.area}')
        if n in dynamic: raise ValueError(f'--open-regions {n}: an opcode-197 region (dynamic), not a static one')
    blocked = {r['id'] for r in g['regions'] if r['flags'] & 1 and r['id'] not in dynamic and r['id'] not in opened}
    edges = []
    for r in g['regions']:
        if (r['flags'] & 1 and r['id'] not in opened) or r['id'] in dynamic: continue
        for j, n in enumerate(r['neighbors']):
            if n not in blocked: continue
            k = (j + 1) % 4
            i0, i1 = r['vertex_indices'][j], r['vertex_indices'][k]
            o = regions[n]
            edges.append(dict(region=r['id'], edge=j, blocked=n,
                              a=[v[i0][0] / 65536, -v[i0][1] / 65536], b=[v[i1][0] / 65536, -v[i1][1] / 65536],
                              floor=min(r['floor_corners'] + o['floor_corners']),
                              ceiling=max(r['ceiling_corners'] + o['ceiling_corners']),
                              inside=[sum(v[i][0] for i in r['vertex_indices']) / 4 / 65536,
                                      -sum(v[i][1] for i in r['vertex_indices']) / 4 / 65536]))
    passable = {r['id'] for r in g['regions'] if (not (r['flags'] & 1) or r['id'] in opened) and r['id'] not in dynamic}
    dynamic_edges = []
    for r in g['regions']:
        if r['id'] not in passable and r['id'] not in dynamic: continue
        for j, n in enumerate(r['neighbors']):
            if n == r['id'] or (n not in blocked and n not in dynamic): continue
            if r['id'] not in dynamic and n not in dynamic: continue
            k = (j + 1) % 4
            i0, i1 = r['vertex_indices'][j], r['vertex_indices'][k]
            o = regions[n]
            dynamic_edges.append(dict(region=r['id'], edge=j, blocked=n,
                                      from_dynamic=r['id'] if r['id'] in dynamic else -1, to_dynamic=n if n in dynamic else -1,
                                      a=[v[i0][0] / 65536, -v[i0][1] / 65536], b=[v[i1][0] / 65536, -v[i1][1] / 65536],
                                      floor=min(r['floor_corners'] + o['floor_corners']),
                                      ceiling=max(r['ceiling_corners'] + o['ceiling_corners']),
                                      inside=[sum(v[i][0] for i in r['vertex_indices']) / 4 / 65536,
                                              -sum(v[i][1] for i in r['vertex_indices']) / 4 / 65536],
                                      target_inside=[sum(v[i][0] for i in o['vertex_indices']) / 4 / 65536,
                                                     -sum(v[i][1] for i in o['vertex_indices']) / 4 / 65536]))
    out = dict(version=2, area=a.area, archive_sha256=g['source']['sha256'],
               geometry_sha256=hashlib.sha256(a.geometry.read_bytes()).hexdigest(),
               blocked_regions=sorted(blocked),
               blocked_outlines={str(n): [[v[i][0] / 65536, -v[i][1] / 65536] for i in regions[n]['vertex_indices']]
                                 for n in sorted(blocked)},
               blocked_heights={str(n): [min(regions[n]['floor_corners']), max(regions[n]['ceiling_corners'])]
                                for n in sorted(blocked)},
               dynamic_regions={str(k): sorted(s) for k, s in sorted(dynamic.items())},
               dynamic_initial={str(k): bool(regions[k]['flags'] & 1) for k in sorted(dynamic)},
               dynamic_outlines={str(n): [[v[i][0] / 65536, -v[i][1] / 65536] for i in regions[n]['vertex_indices']]
                                 for n in sorted(dynamic)},
               dynamic_heights={str(n): [min(regions[n]['floor_corners']), max(regions[n]['ceiling_corners'])]
                                for n in sorted(dynamic)},
               dynamic_edges=dynamic_edges,
               open_regions=sorted(opened),
               open_outlines={str(n): [[v[i][0] / 65536, -v[i][1] / 65536] for i in regions[n]['vertex_indices']] for n in sorted(opened)},
               edges=edges,
               scope='Native region word +0x1C bit0 (player-impassable, B0D98/AFF85). Edges from bit0-clear regions into '
                     'bit0-set neighbours; op197 sub0/2/4/5 regions excluded (hosted by their owners). Godot X/Z = '
                     'native x, -native y. Collision height floor..ceiling+1024 is a port adapter (jumping is also refused '
                     'natively). Version 2: dynamic_* lists the op197 regions (initial bit0, outlines, heights) and every edge '
                     'with a dynamic region on either side, built and toggled only by a native script host binder.')
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(out, indent=1) + '\n')
    print(f'{a.area}: {len(blocked)} blocked regions, {len(dynamic)} op197 regions dynamic, {len(opened)} opened by --open-regions, {len(edges)} static edges, {len(dynamic_edges)} dynamic edges')


if __name__ == '__main__':
    main()
