#!/usr/bin/env python3
"""Group creature-nav regions into storeys.

A storey is one connected component of the nav's own edges. An edge joins
two regions when their floor fields differ by at most 32, which is the nav's
own step. Equal floors with no path stay apart. An empty quad is unmapped.
A blocked region keeps its component and takes kind blocked.
"""
import argparse
import json
from pathlib import Path

STEP = 32


def _find(parent, index):
    while parent[index] != index:
        parent[index] = parent[parent[index]]
        index = parent[index]
    return index


def _union(parent, left, right):
    root_left = _find(parent, left)
    root_right = _find(parent, right)
    if root_left != root_right:
        parent[root_right] = root_left


def _median(values):
    ordered = sorted(values)
    count = len(ordered)
    if count == 0:
        return 0
    mid = count // 2
    if count % 2:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) / 2.0


def _num(value):
    number = float(value)
    if number == int(number):
        return int(number)
    return number


def group_regions(regions, blocked):
    count = len(regions)
    parent = list(range(count))
    empty = []
    floors = []
    for index, row in enumerate(regions):
        polygon = row[0]
        floor = float(row[1])
        corner = float(row[2])
        edges = row[3]
        floors.append((floor, corner))
        is_empty = len(polygon) == 0
        empty.append(is_empty)
        if is_empty:
            continue
        for edge in edges:
            other = int(edge[0])
            if other < 0 or other >= count or other == index:
                continue
            if len(regions[other][0]) == 0:
                continue
            if abs(floor - float(regions[other][1])) > STEP:
                continue
            _union(parent, index, other)
    components = {}
    for index in range(count):
        if empty[index]:
            continue
        root = _find(parent, index)
        components.setdefault(root, []).append(index)
    ordered = sorted(
        components.values(),
        key=lambda ids: (_median([floors[i][0] for i in ids]), min(ids)),
    )
    storey_of = {}
    storeys = []
    for number, ids in enumerate(ordered):
        for region in ids:
            storey_of[region] = number
        span_lo = min(min(floors[i]) for i in ids)
        span_hi = max(max(floors[i]) for i in ids)
        storeys.append({
            "id": number,
            "floor_min": _num(span_lo),
            "floor_max": _num(span_hi),
            "region_count": len(ids),
        })
    blocked_set = {int(region) for region in blocked}
    rows = []
    for index in range(count):
        low, high = floors[index]
        if empty[index]:
            kind = "unmapped"
            storey = -1
        elif index in blocked_set:
            kind = "blocked"
            storey = storey_of[index]
        elif len(regions[index][3]) > 0:
            kind = "linked"
            storey = storey_of[index]
        else:
            kind = "isolated"
            storey = storey_of[index]
        rows.append({
            "region": index,
            "storey": storey,
            "floor_min": _num(min(low, high)),
            "floor_max": _num(max(low, high)),
            "kind": kind,
        })
    return rows, storeys


def load_blocked(path):
    file_path = Path(path)
    if not file_path.is_file():
        return []
    data = json.loads(file_path.read_text())
    return [int(region) for region in data.get("blocked_regions", [])]


def build_area(nav_path, block_dir):
    data = json.loads(Path(nav_path).read_text())
    area = str(data["area"])
    blocked = load_blocked(Path(block_dir) / ("%s.json" % area))
    regions, storeys = group_regions(data["regions"], blocked)
    return {
        "area": area,
        "source": "creature_nav edges with floor step at most 32",
        "step": STEP,
        "regions": regions,
        "storeys": storeys,
    }


def write_area(nav_path, block_dir, out_dir):
    payload = build_area(nav_path, block_dir)
    destination = Path(out_dir)
    destination.mkdir(parents=True, exist_ok=True)
    out = destination / ("%s.json" % payload["area"])
    out.write_text(json.dumps(payload, indent=2) + "\n")
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--nav-dir", required=True)
    parser.add_argument("--block-dir", required=True)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    written = []
    for path in sorted(Path(args.nav_dir).glob("*.json")):
        written.append(str(write_area(path, args.block_dir, args.out_dir)))
    print("\n".join(written))


if __name__ == "__main__":
    main()
