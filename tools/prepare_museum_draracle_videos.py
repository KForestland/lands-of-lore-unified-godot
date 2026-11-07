#!/usr/bin/env python3
"""Pin the Museum arrival heading and the Draracle pedestal videos (region1220) as a source contract.

Every record, command group and predicate is read from the hash-checked L3_DH archive and asserted byte for byte.
- Arrival index1 (selector1, region1226; the Cave -> Museum arrival) is (-3796, -369) with heading 49152. The port
  convention (cave_walkthrough.gd arrival, hive_rune_entry.gd return pose) is yaw = -heading * TAU / 65536, so the
  player starts facing +PI/2 (native -X, away from the pedestal).
- Region1220 (the floor between the four template1 columns 132-135) event2 = grounded entry (jungle_bacatta57_state.gd).
  g1486, predicate48 local19 == 0: op21 prop135 movie 24, op198 local19 = 1, op18 player -> (-3751, -371) heading 49152.
  g1522, predicate49 local19 == 1: op21 prop134 movie 25, op198 local19 = 2, the same op18 return.
  No other L3_DH command plays a movie (the only two op21 commands) and no region event is attached to the arrival.
- op21 (opcode table 0x5C878 slot20 -> B5AB5) calls CF2B4(byte4, byte5): the global movie-name table (ds+0xE568) entry
  byte4 is played as "%s.vqa" (names starting "ss-" are not movies). Entries 24/25 are e032e/e033e; their archive keys
  (ww_hash_v1 of SPHERE1\\L3_DH\\E03xE.VQA) are L3_DHI entries 5 and 6, the clips the port had played automatically.
  With --native-exe the name table is read from LOLG.DAT (data segment = file offset of "%s.vqa" - 0x2C88).
- Not hosted (reported): control79 event4 at local19 == 2 (sound394, local19 = 3, then sound312) and region1174
  (predicate45 local17 == 0) closing bars 71-74 and gate77; the bar movables are not rendered by the port.
Usage: prepare_museum_draracle_videos.py --output scripts/lol2/museum_draracle_source.json [--native-exe LOLG.DAT]
"""
import argparse, hashlib, json, math, struct, sys
from pathlib import Path
from build_game_atlas import parse_mix, section
from audit_game_transition_owners import GAME, collect_owners
from audit_game_actor_scripts import groups
from prepare_jungle_exit_encounter import predicate
from lol2_movie_format import ww_hash_v1
ROOT = Path(__file__).resolve().parents[1]
REGION = 1220
SOURCE = {'file': 'DAT/L3_DH.MIX', 'sha256': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac', 'geometry_key': 3106551060,
          'geometry_sha256': 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'}
RECORDS = {48: '080cce05c4040200', 49: '080cf205c4040200'}
EXPECTED_GROUPS = {1486: ['150387001800', 'c60000001301', '1201000059f173010000050800c0000a0000'],
                   1522: ['150386001900', 'c60000001302', '1201000057f175010000050800c0000a0000']}
MOVIES = {24: 'e032e', 25: 'e033e'}
CLIPS = {'e032e': 4, 'e033e': 5}  # cave_video_overlay story clip indices (museum_introduction_a/b)
ENTRIES = {'e032e': (5, 2902008005), 'e033e': (6, 2902008517)}

def native_names(path):
    data = path.read_bytes()
    ds = data.index(b'ss-\x00%s.vqa\x00') + 4 - 0x2C88
    assert data[ds + 0x2C84:ds + 0x2C88] == b'ss-\x00'
    name = lambda i: data[ds + struct.unpack_from('<I', data, ds + 0xE568 + 4 * i)[0]:].split(b'\0')[0].decode()
    return {i: name(i) for i in MOVIES}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--native-exe', type=Path)
    a = p.parse_args()
    area = dict(source=SOURCE)
    archive = (GAME / area['source']['file']).read_bytes(); assert hashlib.sha256(archive).hexdigest() == area['source']['sha256']
    entry = next(e for e in parse_mix(archive) if e['key'] == area['source']['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]; assert hashlib.sha256(raw).hexdigest() == area['source']['geometry_sha256']
    _, region_count, _ = section(raw, 12, 0x58, 44)
    owners, _ = collect_owners(raw, entry['offset'], region_count)
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    parsed = {}
    for stream, (of, sf) in enumerate([(0x3c, 0x84), (0x44, 0x8c)]):
        _, _, blob = section(raw, of, sf, 1)
        for offset, commands in groups(blob): parsed[(stream, offset)] = [body.hex() for _, body in commands]
    mine = [o for o in owners if o['owner_kind'] == 'region' and o['owner'] == REGION]
    rows = {o['predicate']: archive[o['archive_offset']:o['archive_offset'] + 8].hex() for o in mine}
    assert rows == {k: v for k, v in RECORDS.items()}, rows
    assert {o['predicate']: o['group'] for o in mine} == {48: 1486, 49: 1522} and all(o['event'] == 2 for o in mine)
    for g, expected in EXPECTED_GROUPS.items(): assert parsed[(0, g)] == expected, (g, parsed[(0, g)])
    played = [c for cs in parsed.values() for c in cs if c.startswith('15')]
    assert sorted(played) == ['150386001900', '150387001800'], played
    arrival_regions = {o['owner'] for o in owners if o['owner_kind'] == 'region'}
    assert 1226 not in arrival_regions and 1228 not in arrival_regions
    preds = {n: predicate(table, n) for n in (48, 49)}
    assert [(p['op'], p['left'], p['right']) for p in preds.values()] == [('==', {'local': 19}, {'immediate': 0}), ('==', {'local': 19}, {'immediate': 1})]
    # Region polygon (native x, z; port Z = -z) and the op18 return pose.
    _, _, regions = section(raw, 12, 0x58, 44)
    _, _, vertices = section(raw, 4, 0x50, 8)
    r = regions[REGION * 44:(REGION + 1) * 44]
    polygon = []
    for k in range(4):
        v = struct.unpack_from('<H', r, 12 + 2 * k)[0]
        x, z = struct.unpack_from('<ii', vertices, v * 8)
        polygon.append([x / 65536.0, -z / 65536.0])
    assert sorted(polygon) == sorted([[-3622.0, -418.0], [-3622.0, -328.0], [-3718.0, -328.0], [-3718.0, -418.0]]), polygon
    op18 = bytes.fromhex(EXPECTED_GROUPS[1486][2]); op18b = bytes.fromhex(EXPECTED_GROUPS[1522][2])
    returns = [dict(x=struct.unpack_from('<h', c, 4)[0], z=-struct.unpack_from('<h', c, 6)[0], heading=struct.unpack_from('<H', c, 12)[0]) for c in (op18, op18b)]
    assert returns == [dict(x=-3751, z=-371, heading=49152), dict(x=-3753, z=-373, heading=49152)], returns
    names = native_names(a.native_exe) if a.native_exe else None
    if names is not None: assert names == MOVIES, names
    movie_archive = (GAME / 'DAT/L3_DHI.MIX').read_bytes()
    keyed = {e['key']: i for i, e in enumerate(parse_mix(movie_archive))}
    for name, (index, key) in ENTRIES.items():
        assert ww_hash_v1('SPHERE1\\L3_DH\\%s.VQA' % name.upper()) == key and keyed[key] == index, name
    steps = []
    for (pred, group), ret in zip(((48, 1486), (49, 1522)), returns):
        movie = MOVIES[int(EXPECTED_GROUPS[group][0][8:10], 16)]
        steps.append(dict(predicate=pred, local19=pred - 48, group=group, movie=movie, l3_dhi_entry=ENTRIES[movie][0],
                          clip=CLIPS[movie], next_local19=pred - 47, return_pose=dict(position=[ret['x'], ret['z']], heading=ret['heading'],
                          yaw=round(math.remainder(-ret["heading"] * math.tau / 65536.0, math.tau), 12))))
    result = dict(version=1, source=area['source'], region=REGION, polygon=polygon, floor=0, records=RECORDS, groups={str(k): v for k, v in EXPECTED_GROUPS.items()},
                  arrival=dict(index=1, region=1226, position=[-3796, -369], heading=49152, yaw_rule='yaw = wrap(-heading * TAU / 65536)'),
                  steps=steps, movie_names_from_native=names is not None,
                  not_hosted=['control79 event4 at local19 == 2: op20 sound394, op198 local19 = 3; event8 value394: op20 sound312',
                              'region1174 g1364 (predicate45 local17 == 0): bars 71-74 and gate77 close, props136-139/control82 events, music'],
                  adapters=['grounded entry = player on floor with the foot inside the polygon (floor 0, +3 tolerance)',
                            'op18 places the player at the return XY at the arrival standing height; camera pitch reset',
                            'legacy checkpoints/saves without the field already played both clips (auto introduction): local19 = 2'])
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS museum draracle videos: region1220 2 steps, movies %s, native names %s' % (list(MOVIES.values()), 'checked' if names else 'not read'))

if __name__ == '__main__':
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    main()
