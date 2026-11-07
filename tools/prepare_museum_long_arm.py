#!/usr/bin/env python3
"""Pin Museum prop153 ("7-Long arm" pedestal) and its floor trap.

Prop153's only record is kind4 mode0 (empty hand, no predicate), group2656: sounds, prop72 spawn/op7, opcode196 floor
targets (regions197/198 -> -190; 185-196, 199-203, 166 -> -210), op14 op3 enabling prop108's kind2 timer, op199
GV_LONG_ARM_AXE (global43) = 1, one op3 grant of "7-Long arm" (identity 0x7F71F12A, property1) and prop153
property2 (removed). Prop108's timer expiry (group2052) runs player op2 sub 0x3A: D89B3 tests admission +0x228 bit
0x10 and requests D6B20(form2, duration byte 0). The walkway drops into the existing -220 lower chamber.
The dropped-floor variant is the unchanged museum_review builder rerun with only those floors changed.
Usage: prepare_museum_long_arm.py --output scripts/lol2/museum_long_arm_source.json --asset-dir assets/lol2/generated/museum_long_arm
"""
import argparse, hashlib, json, shutil, struct, subprocess, tempfile
from pathlib import Path
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import GAME, collect_owners
from audit_game_actor_scripts import groups
from prepare_museum_key_locks import icon, REVIEW, MAP

ROOT = Path(__file__).resolve().parents[1]
ITEM = dict(identity=0x7F71F12A, name='7-Long arm', catalog_id='museum:prop153:Long_arm')
FLOORS = {197: -190, 198: -190, **{r: -210 for r in list(range(185, 197)) + list(range(199, 204)) + [166]}}
SPRITES = MAP / 'props/sprites'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True); p.add_argument('--asset-dir', type=Path, required=True)
    a = p.parse_args()
    inv = json.loads((ROOT / 'docs/game-source-inventory.json').read_text()); area = next(x for x in inv['areas'] if x['id'] == 'L3_DH')
    arc = (GAME / area['source']['file']).read_bytes(); assert hashlib.sha256(arc).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(arc) if e['key'] == area['source']['geometry_key'])
    raw = arc[entry['offset']:entry['offset'] + entry['size']]
    owners, _ = collect_owners(raw, entry['offset'], area['counts']['regions'])
    streams = []
    for of, sf in [(0x3c, 0x84), (0x44, 0x8c)]:
        _, _, blob = section(raw, of, sf, 1); streams.append({g: [b.hex() for _, b in c] for g, c in groups(blob)})
    def recs(kind, owner):
        out = []
        for o in owners:
            if o['owner_kind'] == kind and o['owner'] == owner:
                n = arc[o['archive_offset']]
                out.append(dict(kind=o['event'], value=o['value'], group=o['group'], predicate=o['predicate'],
                                raw=arc[o['archive_offset']:o['archive_offset'] + n].hex(), commands=streams[o['stream']][o['group']]))
        return out
    take = recs('prop', 153); assert len(take) == 1 and take[0]['kind'] == 4 and take[0]['predicate'] is None and take[0]['raw'][8:10] == '00'
    cmds = take[0]['commands']; assert take[0]['group'] == 2656 and len(cmds) == 28
    for region, height in FLOORS.items():
        assert 'c490%02x00%s000c00000000' % (region, struct.pack('<h', height).hex()) in cmds, region
    assert sum(c.startswith('c490') for c in cmds) == len(FLOORS)
    grant = '03010000' + struct.pack('<I', ITEM['identity']).hex() + '01000000'
    assert cmds[-4:] == ['0e036c0003000000', 'c70000002b01', grant, '090399000200']
    assert cmds[1:3] == ['090348000300', '070348000000']
    timer = recs('prop', 108); assert len(timer) == 1 and timer[0]['kind'] == 2 and timer[0]['group'] == 2052
    assert timer[0]['raw'] == '0a020408200196960096' and timer[0]['commands'] == ['020100003a00', '14036c003701ff851200', '0e036c0004000000']
    effect = recs('prop', 72); assert effect == [dict(kind=6, value=2, group=848, predicate=None, raw='060650030200', commands=['090348000200'])]
    props = {q['record']: q for q in json.loads((MAP / 'props/props.json').read_text())['props']}
    pedestal = props[153]; assert pedestal['template'] == 33 and pedestal['region'] == 197
    a.asset_dir.mkdir(parents=True, exist_ok=True)
    frames = []
    for i in range(15):
        src = SPRITES / ('%s_frame_%d.png' % (pedestal['material'], i)); dst = a.asset_dir / ('frame_%02d.png' % i)
        shutil.copyfile(src, dst); frames.append(dict(file=dst.name, sha256=hashlib.sha256(dst.read_bytes()).hexdigest()))
    floors = floor_variant(a.asset_dir / 'floors.json')
    regions, escape = region_contract(owners, streams)
    # GLOBAL definition for the grant identity (icon = its view0 world sprite, like the Sk key).
    from prepare_museum_key_locks import definitions
    blob, base, count, names = definitions()
    definition = next(i for i in range(count) if u32(blob, base + i * 91 + 24) == ITEM['identity']); assert names[definition] == ITEM['name']
    ITEM['definition'] = definition; icon(definition, a.asset_dir / 'icon.png')
    result = dict(version=1, source=area['source'], item=ITEM, take=take[0], timer=timer[0], effect=effect[0],
                  floor_targets={str(k): v for k, v in FLOORS.items()}, global_name='GV_LONG_ARM_AXE', global_index=43,
                  timer_seconds=150 / 60.0, form_request=dict(target=2, native_duration_byte=0, adapter_duration=90.0),
                  pedestal=dict(position=pedestal['position'], left=pedestal['left'], right=pedestal['right'], bottom=pedestal['bottom'],
                                top=pedestal['top'], material=pedestal['material'], frames=frames),
                  regions=regions, escape=escape,
                  floors=dict(file='floors.json', closed_faces=len(floors['closed_face_indices']), open_faces=len(floors['open_faces'])),
                  not_hosted=['op20 sounds on prop108', 'prop72 spawned effect (property3/op7, removed by its kind6 event2)',
                              'native floor movement speed (floors move immediately)', 'GV_LONG_ARM_AXE has no known predicate reader (room DLLs not scanned)',
                              'not-admitted branch 80064(0x23819, 1)', 'timer word interpretation: 0x96 = 150 ticks at 60/s is an adapter'],
                  scope='Direct source records. E reach/aim, immediate floors, 2.5 s timer and 90 s form duration are modern adapters.')
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS museum long arm: group2656 28 commands, %d floor targets, timer g2052, definition %d, floors closed %d / open %d' %
          (len(FLOORS), definition, len(floors['closed_face_indices']), len(floors['open_faces'])))


WALKWAY = sorted(r for r in FLOORS if r not in (197, 198))  # regions197/198 (pedestal floor) have no first-contact record
REARM = [171, 176]          # kind2 event1, predicate99 (GV_LUTHER_FORM != 0): op14 op3 on prop108 (timer restart)
HUMAN_RETURN = [967, 1436, 1437, 1463]  # kind2 event0: player op2 sub0x3C (human request, repeatable)
LOCK78 = {1237: 0, 1477: 0}  # control78/prop81 opcode196 targets


def region_contract(owners, streams):
    """Walkway first-contact (local25 -> prop153 property 0x0D), chamber re-arm and duct human-return regions, plus a
    static tiny-body escape path (portal midpoints) from the pedestal region to region1262 through the lock78 passage."""
    import collections, math
    g = json.loads((MAP.parents[1] / REVIEW['geometry']).read_text()); R = {r['id']: r for r in g['regions']}; V = g['vertices_fixed']
    by = collections.defaultdict(list)
    for o in owners:
        if o['owner_kind'] == 'region': by[o['owner']].append((o['event'], o['value'], o['predicate'], streams[o['stream']][o['group']]))
    for r in WALKWAY: assert by[r] == [(4, 0, 62, ['c60000001901', '090399000d00'])], r
    for r in REARM: assert by[r] == [(2, 1, 99, ['0e036c0003000000'])], r
    for r in HUMAN_RETURN: assert by[r] == [(2, 0, None, ['020100003c00'])], r
    poly = lambda r: [[V[v][0] / 65536, -V[v][1] / 65536] for v in R[r]['vertex_indices']]
    def floors(r):
        if r in FLOORS: return [FLOORS[r]] * 4
        if r in LOCK78: return [LOCK78[r]] * 4
        return R[r]['floor_corners']
    def row(r): return dict(polygon=poly(r), floor=[min(floors(r)), max(floors(r))])
    regions = dict(walkway={str(r): row(r) for r in WALKWAY}, rearm={str(r): row(r) for r in REARM}, human_return={str(r): row(r) for r in HUMAN_RETURN})
    lo = lambda r: min(floors(r)); hi = lambda r: max(floors(r)); clear = lambda r: min(c - f for c, f in zip(R[r]['ceiling_corners'], floors(r)))
    def path(start, goal, height):
        prev = {start: None}; q = collections.deque([start])
        while q:
            r = q.popleft()
            for n in R[r]['neighbors']:
                if n is None or n in prev or n not in R or lo(n) - hi(r) > 32 or clear(n) < height: continue
                prev[n] = r; q.append(n)
        if goal not in prev: return None
        out = []; r = goal
        while r is not None: out.append(r); r = prev[r]
        return out[::-1]
    tiny = path(197, 1262, 8); human = path(197, 1262, 46)
    assert tiny and human is None and 958 in tiny and 967 in tiny and 1477 in tiny
    points = []
    for a, b in zip(tiny, tiny[1:]):
        i = R[a]['neighbors'].index(b); vi = R[a]['vertex_indices']; p0, p1 = V[vi[i]], V[vi[(i + 1) % len(vi)]]
        points.append(dict(region=b, xz=[(p0[0] + p1[0]) / 131072, -(p0[1] + p1[1]) / 131072], floor=max(floors(b))))
    return regions, dict(regions=tiny, portals=points, requires=['tiny form (region958 clearance20, region967 clearance30)', 'lock78 passage open (regions1237/1477 floor0)'],
                         note='Static region-graph path (step<=32, clearance>=body height); no human/beast path exists; with lock78 closed the tiny body reaches only the 1463 side area.')


def floor_variant(out):
    lol2_out = MAP.parents[1]; shipped = ROOT / 'assets/lol2/generated/museum_review/museum.json'
    def build(geometry, arrival, folder):
        args = ['python3', '-B', str(ROOT / 'tools/build_museum_review.py'), '--game-root', str(GAME), '--geometry', str(geometry),
                '--presets', str(lol2_out / REVIEW['presets']), '--materials', str(lol2_out / REVIEW['materials']), '--arrival', str(arrival),
                '--surface-setup', str(lol2_out / REVIEW['surface_setup']), '--rotation-table', str(lol2_out / REVIEW['rotation_table']), '--out', str(folder)]
        subprocess.run(args, check=True, cwd=ROOT / 'tools', capture_output=True)
        return json.loads((folder / 'museum.json').read_text())
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp); geometry = lol2_out / REVIEW['geometry']; arrival = lol2_out / REVIEW['arrival']
        base = build(geometry, arrival, tmp / 'base')
        assert (tmp / 'base/museum.json').read_bytes() == shipped.read_bytes(), 'museum_review reproduction differs from shipped museum.json'
        g = json.loads(geometry.read_text())
        for r in g['regions']:
            if r['id'] in FLOORS:
                r['floor_base'] = FLOORS[r['id']]; r['floor_corners'] = [FLOORS[r['id']]] * len(r['floor_corners'])
        (tmp / 'geometry.json').write_text(json.dumps(g))
        arr = json.loads(arrival.read_text()); arr['geometry_sha256'] = hashlib.sha256((tmp / 'geometry.json').read_bytes()).hexdigest()
        (tmp / 'arrival.json').write_text(json.dumps(arr))
        dropped = build(tmp / 'geometry.json', tmp / 'arrival.json', tmp / 'open')
    key = lambda f: json.dumps(f, sort_keys=True)
    base_keys = [key(f) for f in base['faces']]; open_keys = {key(f) for f in dropped['faces']}; base_set = set(base_keys)
    closed = [i for i, k in enumerate(base_keys) if k not in open_keys]
    opened = [f for f in dropped['faces'] if key(f) not in base_set]
    missing = sorted({f['material'] for f in opened} - set(base['materials']) - {'shell', 'unresolved'}); assert not missing, missing
    out.write_text(json.dumps(dict(version=1, shipped_sha256=hashlib.sha256(shipped.read_bytes()).hexdigest(), regions=sorted(FLOORS),
                                   closed_face_indices=closed, closed_faces=[base['faces'][i] for i in closed], open_faces=opened), indent=1) + '\n')
    return dict(closed_face_indices=closed, open_faces=opened)


if __name__ == '__main__':
    main()
