#!/usr/bin/env python3
"""Height-boundary packet for the City (L16_CA): every drawn wall with no floor the body can stand on beyond it collides.

Lead 2026-11-16: Grok fell through the amphitheater tier and off the canal bank; 40 of 40 avenue terraces and facades
walked by real W also let the body through. L16 source walls are drawn only, so where the floor beyond a wall stands above
the 64-high body, or there is none, the body walked under the raised floor or into the building and fell.

Selection: Sol's height-aware census (tools/prepare_boundary_collision.py: interpolated floor and ceiling spans, linked
edges collide only below a rise over STEP 48, dynamic (opcode 197) and sloped faces withheld) on the L16 pack, minus the
walls a player really walked through onto ground beyond (WITHHELD, from the owner's F10 bundles of 2026-11-12 replayed
with AI_COMMS/opus_lane/tools/trace_replay_boundary.py). The plain region-edge rule (EDGE_RULE_AREAS) was not used: its
nav keeps one floor per region, so it walled 46 walls the owner walked (stairs and ramps).
Writes scripts/lol2/height_boundary/L16_CA.json.
"""
import argparse, hashlib, json, math, pathlib, subprocess, sys, tempfile
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from prepare_boundary_collision import face_key

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAP = ROOT / "assets/lol2/generated/maps/L16_CA/area.json"
SCRIPTS = ROOT / "scripts/lol2/native_scripts/L16_CA.json"
OUT = ROOT / "scripts/lol2/height_boundary/L16_CA.json"
# Grok's two falls (r19o8): must stay in the selection.
NAMED = [22719, 22721, 22720, 18343, 18344, 18349, 18315, 18312, 18429, 18428, 18307, 18385]
# Grok's Y 5720 arcade step (r19p step class): must be selected.
STEP_NAMED = [17230, 17235]
# Walls the owner walked through and stayed beyond (2026-11-12 F10 bundles): left open.
WITHHELD = [17009, 17010, 17114, 17135, 17171, 17208, 17210, 17737, 17846, 19071, 19564, 19687, 19703, 22486, 22487,
            22504, 22673, 25026, 25278, 25280, 25288, 26155, 26422, 28088, 25301]

def gd_round(v):
    return int(math.floor(abs(v) + 0.5)) * (1 if v >= 0 else -1)

def gd_key(face):
    """RegionEdgeRule.face_key: ends in first-encounter order (points under 1 apart merged), GDScript rounding."""
    ends = []
    for p in face["points"]:
        q = (float(p[0]), float(p[2]))
        if all(math.hypot(q[0] - e[0], q[1] - e[1]) >= 1.0 for e in ends): ends.append(q)
    if len(ends) != 2: return None
    lo = min(float(p[1]) for p in face["points"]); hi = max(float(p[1]) for p in face["points"])
    return "%s|%d,%d|%d,%d|%d|%d" % (face["kind"], gd_round(ends[0][0]), gd_round(ends[0][1]), gd_round(ends[1][0]),
                                     gd_round(ends[1][1]), gd_round(lo), gd_round(hi))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

# Step class (lead 2026-11-16, r19p): a drawn riser from one floor up to the next, 31 or less, does not collide, so the
# step-up (walk_step.gd, up to 32) never fires and the body slides under the upper floor's edge and falls (Grok 11:10Z,
# arrival-avenue arcade at Y 5720: risers 17230/17235, 0 -> 30, 5 of 5 falls by real W). Such a riser now collides, and
# the body steps up it. Selected: source walls of rise 0.2..31 with the lower floor at the riser's foot on one side and the
# upper floor at its top on the other (sampled 6 units out), neither side a live/scripted floor region.
RISER_MAX = 31.0
SIDE = 6.0

def inside(point, poly):
    x, z = point; c = False
    for i in range(len(poly)):
        a, b = poly[i], poly[i - 1]
        if (a[1] > z) != (b[1] > z) and x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]: c = not c
    return c

def step_risers(faces, live_regions):
    floors = [(f.get("region"), [(p[0], p[2]) for p in f["points"]], round(min(p[1] for p in f["points"])))
              for f in faces if f["kind"] == "floor"]
    def at(point):
        return {(r, h) for r, poly, h in floors if inside(point, poly)}
    out = []
    for index, face in enumerate(faces):
        if face["kind"] != "source_wall": continue
        ends = []
        for p in face["points"]:
            q = (float(p[0]), float(p[2]))
            if all(math.hypot(q[0] - e[0], q[1] - e[1]) >= 1.0 for e in ends): ends.append(q)
        if len(ends) != 2: continue
        lo = min(float(p[1]) for p in face["points"]); hi = max(float(p[1]) for p in face["points"])
        if not 0.2 < hi - lo <= RISER_MAX: continue
        (ax, az), (bx, bz) = ends; length = math.hypot(bx - ax, bz - az)
        nx, nz = -(bz - az) / length, (bx - ax) / length; mx, mz = (ax + bx) / 2, (az + bz) / 2
        one, two = at((mx + nx * SIDE, mz + nz * SIDE)), at((mx - nx * SIDE, mz - nz * SIDE))
        if any(r in live_regions for r, _ in one | two): continue
        h1, h2 = {h for _, h in one}, {h for _, h in two}
        low, high = round(lo), round(hi)
        if (low in h1 and high in h2 and high not in h1) or (low in h2 and high in h1 and high not in h2): out.append(index)
    return out

def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--geometry", required=True, help="decoded L16_CA geometry.json (lol2_out all_maps)")
    args = parser.parse_args()
    data = json.loads(MAP.read_text())
    faces = data["faces"]
    with tempfile.TemporaryDirectory() as tmp:
        census = pathlib.Path(tmp) / "census.json"
        subprocess.run([sys.executable, str(ROOT / "tools/prepare_boundary_collision.py"), "--geometry", args.geometry,
                        "--map", str(MAP), "--scripts", str(SCRIPTS), "--out", str(census),
                        "--report", str(pathlib.Path(tmp) / "report.md")], check=True, capture_output=True)
        packet = json.loads(census.read_text())
    withheld = {face_key(faces[i]) for i in WITHHELD}
    selected = {k for k in packet["block_face_keys"] if k not in withheld}
    # The runtime matches RegionEdgeRule.face_key (GDScript roundi: half away from zero); the census keys use Python's
    # round (half to even), which differs at .5 coordinates (three City walls at x -182.5 / -7812.5). Re-key every face.
    wall_keys = {gd_key(f) for f in faces if f["kind"] == "source_wall" and face_key(f) in selected}
    risers = [i for i in step_risers(faces, set(packet.get("excluded_live_floor_regions", []))) if i not in WITHHELD]
    riser_keys = {gd_key(faces[i]) for i in risers} - wall_keys
    keys = sorted(wall_keys | riser_keys)
    for i in NAMED + STEP_NAMED:
        assert gd_key(faces[i]) in keys, f"named face {i} not selected"
    packet.update({
        "version": 1,
        "area": "L16_CA",
        "rule": "City class adapter (lead 2026-11-16): every L16 source wall with no standable floor beyond it collides "
                "(Sol's height-aware census), minus walls a player walked through onto ground; plus every riser of 31 or less "
                "between two static floors, so the step-up fires (step class, r19p)",
        "reason": "Grok 08:25Z/08:53Z falls (amphitheater tier, canal bank) and 40 of 40 avenue terraces/facades walked by real W "
                  "fell; named faces " + ",".join(map(str, NAMED)) + "; withheld (owner walked through, 2026-11-12) "
                  + ",".join(map(str, WITHHELD)),
        "faces": NAMED,
        "withheld_faces": WITHHELD,
        "step_named_faces": STEP_NAMED,
        "block_face_keys": keys,
        "source": {"producer": "tools/prepare_l16_city_fall_packet.py", "census": "tools/prepare_boundary_collision.py"},
        "inputs": {"map": {"sha256": sha(MAP)}, "geometry": {"sha256": sha(pathlib.Path(args.geometry))}},
    })
    packet["counts"] = dict(packet.get("counts", {}), block_face_keys=len(keys), wall_keys=len(wall_keys), step_riser_keys=len(riser_keys),
                            collision_polygons=len(packet.get("collision_faces", [])), withheld=len(WITHHELD))
    OUT.write_text(json.dumps(packet, indent=1) + "\n")
    print(OUT, len(keys))

if __name__ == "__main__":
    main()
