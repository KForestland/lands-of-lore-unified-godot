#!/usr/bin/env python3
"""Pin the Draracle-wing bars (region1174) and the control79 use cues as a source contract (owner report 11:08).

Every record, command group and predicate is read from the hash-checked L3_DH archive and asserted byte for byte.
- Region1174 (the hall east of the bar line, x -3672..-3223, port z -1152..-1024) event2 = grounded entry, predicate45
  local17 == 0, group1364. Hosted commands: op1 kind32 movables 71-74 -> 100 (the four bars rise), op198 local17 = 1,
  op1 kind32 movable77 -> 0 (gate77 closes). The other g1364 commands (op206, op210, control82 op6/op8/op9 and
  props 136-139 op6/op9) have no port owner and are listed as not hosted.
- Movables 71-74 (template55): 41-byte placement records from geometry section 0x24/0x70. Native constructor field
  offsets as replayed by cave_kenneth/verify_encounter_movables.py (0x63004/0x63FCB/0x63C2A): byte34 = vertical mode
  (0 raises by the target), byte36 = travel, byte37 = speed byte, byte38 = initial travel; op1 target = travel*percent//100.
  All four: mode0, travel100, speed40, initial0, height -120 (top flush with the floor at y=0).
- Control79 (template65, at the pedestal's east edge) kind4 mode0 (empty-hand use) under predicate55 local19 == 2:
  op20 sound394 ("chain4.aud"), op198 local19 = 3. Its event8 value394 record plays sound312 ("0202424e.aud").
- Faces/textures come from the pinned historical L3_DH movable export (movables.json sha256 below); each face is checked
  against the record's placement (x, -y, height .. height+120).
Usage: prepare_museum_draracle_bars.py --game GAME --map L3_DH_EXPORT --output scripts/lol2/museum_draracle_bars_source.json
       [--assets-root PROJECT]   (assets go to PROJECT/assets/lol2/generated/museum_draracle_bars; default: this project)
"""
import argparse, hashlib, json, shutil, struct, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = {'file': 'DAT/L3_DH.MIX', 'sha256': 'bd85c12d4a2cff0cc200309e72a7771745ce5c78f1a83da4d60cba81d831ccac', 'geometry_key': 3106551060,
          'geometry_sha256': 'd2e74dc68ca4a1c4532e548ee7e214537fa74edaf590e518bf341a00748076b7'}
MOVABLES_SHA = '6c2938f8d659c21e49ba66d7cfb404c84edae1d78a10d43b2d9ffe54b52cc0ae'
REGION = 1174
RECORD = '080c540596040200'
GROUP = 1364
COMMANDS = ['ce00000000ff', 'd20000000800', '061052000200', '090388001000', '091052001000', '090389001000', '09038b001000', '09038a001000',
            '012047006400', '012048006400', '012049006400', '01204a006400', '06038a000200', '060389000200', '060388000200', '06038b000200',
            'c60000001101', '0810520001000000', '01204d000000']
HOSTED = {8, 9, 10, 11, 16, 18}
BARS = [71, 72, 73, 74]
GATE = 77
CONTROL = 79
CONTROL_GROUPS = {6976: ['14104f008a0180000a14', 'c60000001303'], 6998: ['14104f003801ff811200']}
SOUNDS = {394: 'chain4.aud', 312: '0202424e.aud'}
FOLDER = 'museum_draracle_bars'

def sha(raw): return hashlib.sha256(raw).hexdigest()

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--map', type=Path, required=True, help='Historical L3_DH map export (movables/movables.json, material_*)')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--assets-root', type=Path, default=ROOT)
    a = p.parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from build_game_atlas import parse_mix, section
    from audit_game_transition_owners import collect_owners
    from audit_game_actor_scripts import groups
    from prepare_jungle_exit_encounter import predicate
    from prepare_creature_audio_clips import sound_bank, stage_clips
    archive = (a.game / SOURCE['file']).read_bytes()
    if sha(archive) != SOURCE['sha256']: raise SystemExit('Wrong L3_DH archive')
    entry = next(e for e in parse_mix(archive) if e['key'] == SOURCE['geometry_key'])
    raw = archive[entry['offset']:entry['offset'] + entry['size']]
    if sha(raw) != SOURCE['geometry_sha256']: raise SystemExit('Wrong L3_DH geometry')
    movables_path = a.map / 'movables/movables.json'
    if sha(movables_path.read_bytes()) != MOVABLES_SHA: raise SystemExit('Wrong L3_DH movable export')
    _, region_count, regions = section(raw, 12, 0x58, 44)
    owners, _ = collect_owners(raw, entry['offset'], region_count)
    _, _, table = section(raw, 0xbc, 0xb8, 5)
    parsed = {}
    for stream, (of, sf) in enumerate([(0x3c, 0x84), (0x44, 0x8c)]):
        _, _, blob = section(raw, of, sf, 1)
        for offset, commands in groups(blob): parsed[(stream, offset)] = [body.hex() for _, body in commands]
    # Region1174: one grounded-entry record, predicate45 local17 == 0.
    mine = [o for o in owners if o['owner_kind'] == 'region' and o['owner'] == REGION]
    assert len(mine) == 1 and mine[0]['event'] == 2 and mine[0]['group'] == GROUP and mine[0]['predicate'] == 45, mine
    assert archive[mine[0]['archive_offset']:mine[0]['archive_offset'] + 8].hex() == RECORD, archive[mine[0]['archive_offset']:mine[0]['archive_offset'] + 8].hex()
    assert parsed[(0, GROUP)] == COMMANDS, parsed[(0, GROUP)]
    pred = predicate(table, 45)
    assert (pred['op'], pred['left'], pred['right']) == ('==', {'local': 17}, {'immediate': 0})
    # Every group that moves the bars or gate77 (gate77 is opened by the prop107 sword groups; museum_gate owns those).
    movers = {}
    for key, commands in parsed.items():
        for c in commands:
            b = bytes.fromhex(c)
            if b[0] == 1 and b[1] == 0x20 and b[2] in BARS + [GATE]: movers.setdefault(b[2], []).append([key[0], key[1], c])
    assert sorted(movers) == BARS + [GATE] and all(len(movers[i]) == 1 and movers[i][0][1] == GROUP for i in BARS), movers
    _, _, vertices = section(raw, 4, 0x50, 8)
    r = regions[REGION * 44:(REGION + 1) * 44]
    polygon = []
    for k in range(4):
        v = struct.unpack_from('<H', r, 12 + 2 * k)[0]
        x, z = struct.unpack_from('<ii', vertices, v * 8)
        polygon.append([x / 65536.0, -z / 65536.0])
    floor, ceiling = struct.unpack_from('<hh', r, 20)
    assert sorted(polygon) == sorted([[-3672.0, -1152.0], [-3223.0, -1152.0], [-3223.0, -1024.0], [-3672.0, -1024.0]]) and (floor, ceiling) == (0, 120), (polygon, floor, ceiling)
    # Bars: placement records and native constructor fields.
    records_offset, _, records = section(raw, 0x24, 0x70, 41)
    export = json.loads(movables_path.read_text())
    assert export['source']['sha256'] == SOURCE['sha256']
    faces_by = {}
    for f in export['faces']: faces_by.setdefault(f['placement'], []).append(f)
    out_dir = a.assets_root / 'assets/lol2/generated' / FOLDER
    out_dir.mkdir(parents=True, exist_ok=True)
    materials = {}
    rows = []
    for index in BARS:
        rec = records[index * 41:(index + 1) * 41]
        x, y = struct.unpack_from('<hh', rec, 0)
        height = struct.unpack_from('<h', rec, 6)[0]
        heading = struct.unpack_from('<H', rec, 4)[0]
        motion = dict(index=index, archive_offset=entry['offset'] + records_offset + index * 41, raw_hex=rec.hex(), template=rec[32], mode=rec[34], height=height,
                      travel=rec[36], speed_byte=rec[37], initial_travel=rec[38])
        assert (motion['template'], motion['mode'], motion['travel'], motion['speed_byte'], motion['initial_travel'], height) == (55, 0, 100, 40, 0, -120), motion
        placement = [pl for pl in export['placements'] if pl['index'] == index][0]
        assert placement['placement_hex'] == rec.hex() and (placement['x'], placement['y'], placement['height'], placement['heading']) == (x, y, height, heading)
        faces = []
        for f in sorted(faces_by[index], key=lambda f: f['face']):
            for pt in f['points']:
                assert abs(pt[0] - x) <= 3 and abs(pt[2] + y) <= 3 and height <= pt[1] <= height + 120, (index, pt)
            name = f['material'].split('/')[0]
            src = a.map / f['material']
            target = out_dir / (name + '.png')
            if not target.exists() or target.read_bytes() != src.read_bytes(): shutil.copyfile(src, target)
            res = 'res://assets/lol2/generated/%s/%s.png' % (FOLDER, name)
            materials[res] = sha(target.read_bytes())
            faces.append(dict(face=f['face'], points=f['points'], uv=f['uv'], material=res))
        assert len(faces) == 6
        rows.append(dict(motion=motion, placement=dict(index=index, x=x, y=y, height=height, heading=heading), faces=faces))
    gate = records[GATE * 41:(GATE + 1) * 41]
    assert gate[32] == 58 and gate[34] == 6 and gate[36] == 54 and gate[38] == 0
    # Control79 use and its sound-end record.
    ctl = [o for o in owners if o['owner_kind'] == 'control' and o['owner'] == CONTROL]
    assert sorted((o['group'], o['event'], o['value'], o['predicate']) for o in ctl) == [(6976, 4, 0, 55), (6998, 8, 394, None)], ctl
    for g, expected in CONTROL_GROUPS.items(): assert parsed[(1, g)] == expected, (g, parsed[(1, g)])
    pred55 = predicate(table, 55)
    assert (pred55['op'], pred55['left'], pred55['right']) == ('==', {'local': 19}, {'immediate': 2})
    _, _, controls = section(raw, 0x18, 0x64, 33)
    c = controls[CONTROL * 33:(CONTROL + 1) * 33]
    cx, cz, cheading, cy = struct.unpack_from('<hhHh', c)
    assert (cx, cz, cy, c[32]) == (-3625, 372, 0, 65)
    bank = sound_bank(a.game)
    count, stable = struct.unpack_from('<II', bank, 0x258)
    names = {n: bank[stable + n * 60 + 16:stable + (n + 1) * 60].split(b'\0')[0].decode() for n in SOUNDS}
    assert names == SOUNDS, names
    clips = stage_clips(a.assets_root, FOLDER, list(SOUNDS), SOUNDS, game=a.game)
    result = dict(version=1, source=SOURCE, movable_export_sha256=MOVABLES_SHA, region=REGION, record=RECORD, group=GROUP, commands=COMMANDS,
                  hosted_command_indices=sorted(HOSTED), polygon=polygon, floor=floor, ceiling=ceiling, local=17,
                  bars=dict(ids=BARS, percent=100), gate=dict(id=GATE, percent=0, template=58, mode=6, travel=54, owner='museum_gate.gd (modern hinge)'),
                  movables=rows, materials=materials,
                  control=dict(id=CONTROL, position=[cx, cy, -cz], heading=cheading, template=c[32], use_local19=2, next_local19=3,
                               groups={str(k): v for k, v in CONTROL_GROUPS.items()}, first_sound=394, follow_sound=312),
                  audio={str(k): dict(name=v['name'], path=v['path'], samples=v['samples'], rate=v['rate'], wav_sha256=v['wav_sha256']) for k, v in clips.items()},
                  not_hosted=['g1364 op206 ce00000000ff, op210 d20000000800 (music)', 'g1364 control82 op6/op8/op9 and props136-139 op6 sub2/op9 property16',
                              'op20 bytes after the sound id (0x80 0x00 0x0a 0x14 / 0xff 0x81 0x12 0x00) are not interpreted (volume/priority)'],
                  adapters=['grounded entry = foot on floor 0 (+3 tolerance) inside the region1174 polygon, as region1220',
                            'bar travel clock = cave_guard_movement_state (speed_byte*10/4 units per 60 ticks); native speed clock not replayed',
                            'gate77 percent0 = museum_gate close (its modern 1.2 s hinge)',
                            'control79 has no visual: E aims at its placement 40 units above the floor (host can_reach_item)',
                            'event8 value394 = sound394 playback finished: sound312 then starts; neither sound clock is saved',
                            'saves without the field restore bars down and local17 0'])
    a.output.write_text(json.dumps(result, indent=1) + '\n')
    print('PASS museum draracle bars: region1174 g1364, bars %s rise to 100, gate77 -> 0, control79 sounds %s' % (BARS, list(SOUNDS)))

if __name__ == '__main__':
    main()
