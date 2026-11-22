#!/usr/bin/env python3
"""Export the original region mover's tables per area (G-05, grok_research/REGION_STACK_MOVER_20261112.md).

One row per native region: [quad, flags, neighbours, floor, run, floor_corners, ceiling_corners]. quad = the four plan vertices (Godot x, z) or [] when
the record has no four vertices; flags = word +0x1C; neighbours = the four words +0x04..+0x0A in order (-1 for 0xFFFF);
floor = floor_base; run = the consecutive records a flag-0x20 region hands over to (word +0x20 onward, the geometry
export's floor_subdivisions), else []. Read-only from the pinned all-map geometry; no filtering, unlike creature_nav.

Overlaps (G-05 guard scope, lead decision (A) 2026-11-12): a pair of regions overlaps when (1) their plan quads
intersect with an area above OVERLAP_AREA (a shared edge is not an overlap), (2) their floors differ by no more than
STEP (both base floors), (3) neither lists the other as a neighbour, (4) neither has flag 0x80, and (5) their
floor-to-ceiling spaces intersect somewhere over the overlap (rule 5 added 2026-11-13 with the T3 move: a region now
stacked wholly under another is not an overlap). Written to the table
as "overlap_regions"; with a geometry move (scripts/lol2/geometry_moves/<AREA>.json) a second table <AREA>.moved.json
carries the moved floor corners and its own overlap list (every region in a pair) and, with the pairs and counts, to <AREA>_overlaps.json. The tracker's
edge guard acts only on steps out of an overlap region.
"""
import argparse, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
MAPS = Path('~/lol2_out/all_maps_20260922')
STEP = 48
OVERLAP_AREA = 4.0
AREAS = ('L1_DC', 'L3_DH', 'L4_HJ', 'L5_HC', 'L8_SJ', 'L10_DC', 'L13_RC', 'L16_CA', 'L19_BC', 'L9_DR', 'L12_CM', 'L14_HT', 'L17_HC', 'L20_BB')


def _clip(subject, clip):
    """Sutherland-Hodgman: subject polygon clipped by a convex polygon (either winding)."""
    def area2(poly):
        return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    sign = 1 if area2(clip) > 0 else -1
    out = subject
    for i in range(len(clip)):
        a, b = clip[i], clip[(i + 1) % len(clip)]
        def side(p):
            return sign * ((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]))
        src, out = out, []
        for j in range(len(src)):
            p, q = src[j], src[(j + 1) % len(src)]
            sp, sq = side(p), side(q)
            if sp >= 0:
                out.append(p)
            if (sp >= 0) != (sq >= 0):
                t = sp / (sp - sq)
                out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
        if not out:
            return []
    return out


def _area(poly):
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))) / 2 if len(poly) >= 3 else 0.0


def _height(quad, corners, x, z):
    for t in ((0, 1, 2), (0, 2, 3)):
        (ax, az), (bx, bz), (cx, cz) = (quad[k] for k in t)
        det = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)
        if abs(det) < 1e-9:
            continue
        u = ((bz - cz) * (x - cx) + (cx - bx) * (z - cz)) / det
        v = ((cz - az) * (x - cx) + (ax - cx) * (z - cz)) / det
        w = 1 - u - v
        if u >= -1e-4 and v >= -1e-4 and w >= -1e-4:
            return u * corners[t[0]] + v * corners[t[1]] + w * corners[t[2]]
    return None


def _spaces_meet(a, b, poly):
    """(5) their floor-to-ceiling spaces intersect somewhere over the overlap (its corners and centre): a region stacked
    wholly under or over the other there is not an overlap."""
    if len(a[5]) != 4 or len(b[5]) != 4 or len(a[6]) != 4 or len(b[6]) != 4:
        return True
    pts = list(poly) + [(sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))]
    for x, z in pts:
        fa, ca = _height(a[0], a[5], x, z), _height(a[0], a[6], x, z)
        fb, cb = _height(b[0], b[5], x, z), _height(b[0], b[6], x, z)
        if None in (fa, ca, fb, cb):
            continue
        if max(fa, fb) < min(ca, cb):
            return True
    return False


def overlaps(rows):
    boxes = []
    for r in rows:
        q = r[0]
        ok = len(q) == 4 and not (r[1] & 0x80) and _area(q) > OVERLAP_AREA
        boxes.append((min(p[0] for p in q), max(p[0] for p in q), min(p[1] for p in q), max(p[1] for p in q)) if ok else None)
    order = sorted((i for i, b in enumerate(boxes) if b), key=lambda i: boxes[i][0])
    pairs = []
    for k, i in enumerate(order):
        bi = boxes[i]
        for j in order[k + 1:]:
            bj = boxes[j]
            if bj[0] >= bi[1]:
                break
            if bj[3] <= bi[2] or bj[2] >= bi[3]:
                continue
            if abs(rows[i][3] - rows[j][3]) > STEP or j in rows[i][2] or i in rows[j][2]:
                continue
            poly = _clip([tuple(p) for p in rows[i][0]], [tuple(p) for p in rows[j][0]])
            a = _area(poly)
            if a > OVERLAP_AREA and _spaces_meet(rows[i], rows[j], poly):
                pairs.append([min(i, j), max(i, j), round(a, 1)])
    return sorted(pairs)


def build(area, maps, moved=False):
    g = json.loads((maps / area / 'geometry/geometry.json').read_text())
    V = g['vertices_fixed']
    rows = []
    for r in g['regions']:
        idx = r.get('vertex_indices') or []
        quad = [[round(V[v][0] / 65536, 2), round(-V[v][1] / 65536, 2)] for v in idx] if len(idx) == 4 else []
        neighbours = [-1 if n is None else int(n) for n in (r.get('neighbors') or [None] * 4)]
        floor = r.get('floor_base')
        corners = [int(c) for c in (r.get('floor_corners') or [])]
        ceilings = [int(c) for c in (r.get('ceiling_corners') or [])]
        rows.append([quad, int(r.get('flags') or 0), neighbours, 0 if floor is None else int(floor),
                     [int(x) for x in (r.get('floor_subdivisions') or [])], corners, ceilings])
    move = ROOT / f'scripts/lol2/geometry_moves/{area}.json'
    if moved and move.exists():
        spec = json.loads(move.read_text())
        for key, deltas in spec['corner_deltas'].items():
            row = rows[int(key)]
            if len(row[5]) == 4:
                row[5] = [round(c + d) for c, d in zip(row[5], deltas)]
                row[3] = round(row[3] + min(deltas))
            ceil_deltas = spec.get('ceiling_deltas', {}).get(key, deltas)
            if len(row[6]) == 4:
                row[6] = [round(c + d) for c, d in zip(row[6], ceil_deltas)]
    pairs = overlaps(rows)
    return dict(version=1, area=area, source_sha256=g['source']['sha256'], regions=rows,
                overlap_regions=sorted({i for p in pairs for i in p[:2]}), overlap_pairs=pairs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--maps', type=Path, default=MAPS)
    parser.add_argument('--output-root', type=Path, default=ROOT)
    parser.add_argument('--area', action='append', choices=AREAS)
    args = parser.parse_args()
    graphs = [(build(area, args.maps), '') for area in (args.area or AREAS)]
    graphs += [(build(area, args.maps, True), '.moved') for area in (args.area or AREAS)
                if (ROOT / f'scripts/lol2/geometry_moves/{area}.json').exists()]
    for data, suffix in graphs:
        path = args.output_root / f"scripts/lol2/region_mover/{data['area']}{suffix}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        pairs = data.pop('overlap_pairs')
        path.write_text(json.dumps(data, separators=(',', ':')))
        (path.parent / f"{data['area']}_overlaps{suffix}.json").write_text(json.dumps(dict(
            area=data['area'], rule=__doc__.split('Overlaps (')[1].strip(), step=STEP, min_area=OVERLAP_AREA,
            pair_count=len(pairs), region_count=len(data['overlap_regions']), pairs=pairs), indent=0))
        print(data['area'], 'overlap pairs', len(pairs), 'regions', len(data['overlap_regions']))
        runs = sum(1 for r in data['regions'] if r[4])
        print(data['area'], len(data['regions']), 'regions', runs, 'runs', path.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
