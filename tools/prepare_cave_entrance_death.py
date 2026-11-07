#!/usr/bin/env python3
"""Cave entrance death plate: L1_DC control135 and its three form death movies (report 2026-10-17 10:45:34).

  python3 tools/prepare_cave_entrance_death.py --game GAME_ROOT --output scripts/lol2/cave_entrance_death_source.json

Source facts asserted byte for byte (GAME_ROOT holds LOLG.DAT and DAT/L1_DC.MIX, DAT/L1_DCI.MIX):
- control135 is a template21 zero-height support plate (same template as control89/104/109) at native (-1453, 83, -3144),
  heading 19114. Its polygon uses the same exact rotation model as cave_support_controls_source.json; the producer
  recomputes plate89 and refuses unless it matches that published polygon exactly.
- It owns three descriptor-type-5 records, predicate206 (owner state == 0): events 7/8/9. ADA30 (called from D26B0 on a
  support-owner change) admits event 7 only for form2 (lizard), 8 for form0 (human), 9 for form1 (beast); jump table
  0x549E8 is decoded from its nine relocation records.
- Groups: event7 g10608 [op2 player 0x39, op21 movie35, op16 control135 state1]; event9 g10632 [op16, op2 0x39, op21 movie11];
  event8 g10656 [op16, op2 0x39, op21 movie74]. op2 sub0x39 (D7893) sets the dying flag and calls D8D48(player, 1):
  immediate death without the 30-tick countdown. op21 (64770 -> CF2B4) plays the global movie-name table entry
  (ds+0xE568) as "%s.vqa": 74 luthrdie, 11 bst-die, 35 liz-die.
- The VQA files are L1_DCI entries 1/35/16 under ww_hash_v1('SPHERE1\\L1_DC\\<NAME>.VQA').
Media: full frames are decoded by tools/lol2_movie_media.py and encoded to Ogg Theora/Vorbis for VideoStreamTheora.
"""
import argparse, hashlib, json, math, shutil, struct, subprocess, sys, tempfile, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_game_atlas import parse_mix, section
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from prepare_jungle_exit_encounter import predicate
from prepare_jungle_followup_gate_media import model
import export_map_movables
from export_map_movables import load_movable_templates
from lol2_movie_format import ww_hash_v1
from lol2_rotation_table import rotation_table
import lol2_movie_media

GEOMETRY_KEY = 2971673856
CONTROL = 135
TEMPLATE = 21
CONTROL_HEX = '53fa480caa4a53008104eb03501818830000000001000000000000001400300015'
PREDICATE_HEX = '0005000000'
GROUPS = {
    7: (10608, ['020100003900', '151087002300', '101087000100']),
    9: (10632, ['101087000100', '020100003900', '151087000b00']),
    8: (10656, ['101087000100', '020100003900', '151087004a00']),
}
FORMS = {7: 2, 8: 0, 9: 1}
MOVIES = {74: ('LUTHRDIE', 1, 'luthrdie', 48), 11: ('BST-DIE', 35, 'bst_die', 322), 35: ('LIZ-DIE', 16, 'liz_die', 100)}
NATIVE_NAMES = {74: 'luthrdie', 11: 'bst-die', 35: 'liz-die'}
# ADA30 jump table 0x549E8 (events 4..12): relocated code targets, and the decoded admission each target loads.
JUMP_TABLE = {4: 0xADA88, 5: 0xADABE, 6: 0xADABE, 7: 0xADA8F, 8: 0xADA97, 9: 0xADA9E, 10: 0xADAA6, 11: 0xADAAE, 12: 0xADAB6}
MEDIA_DIR = 'assets/lol2/generated/cave_entrance_death'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def _require(condition, message):
    if not condition: raise ValueError(message)


# The template parser's checks are bound at import time by its own CLI; bind them for library use.
export_map_movables.require = _require


def native_checks(exe):
    ds = exe.index(b'ss-\x00%s.vqa\x00') + 4 - 0x2C88
    name = lambda i: exe[ds + struct.unpack_from('<I', exe, ds + 0xE568 + 4 * i)[0]:].split(b'\0')[0].decode()
    for index, expected in NATIVE_NAMES.items():
        assert name(index) == expected, (index, name(index))
    # Relocation records "07 10 <src16> 02 <target32>": VA = target + 0x59024; table entry e at source 0x9E8 + 4*(e-4).
    found = {}
    cursor = 0
    while True:
        cursor = exe.find(b'\x07\x10', cursor)
        if cursor < 0: break
        src = struct.unpack_from('<H', exe, cursor + 2)[0]
        if exe[cursor + 4] == 2 and 0x9E8 <= src <= 0xA08 and (src - 0x9E8) % 4 == 0:
            target = struct.unpack_from('<I', exe, cursor + 5)[0] + 0x59024
            if 0xADA80 <= target <= 0xADAC2: found[4 + (src - 0x9E8) // 4] = target
        cursor += 2
    assert found == JUMP_TABLE, found
    # ADA30 case bodies: mov eax,1 | mov al,[esp+N] where N selects the form flag computed in the prologue.
    code = lambda va, n: exe[va + 0x37000:va + 0x37000 + n]
    # 4 always; 7 [esp+0c]; 8 [esp]; 9 [esp+14]; 10 [esp+10]; 11 [esp+4]; 12 [esp+8]; 5/6 fall to ADABE (xor eax,eax).
    assert code(0xADA88, 0x3A).hex() == ('b801000000eb4b' '31c08a44240ceb43' '31c08a0424eb3c' '31c08a442414eb34'
                                          '31c08a442410eb2c' '31c08a442404eb24' '31c08a442408eb1c' '31c0eb18'), code(0xADA88, 0x3A).hex()
    # Prologue flag setup: [esp+0c]=form==2, [esp]=form==0, [esp+14]=form==1, [esp+10]=!=2, [esp+4]=!=0, [esp+8]=!=1.
    prologue = code(0xADA4B, 0x29).hex()
    assert prologue == '3c020f9444240c84c00f9404243c010f944424143c020f9544241084c00f954424043c010f95442408', prologue
    return True


def plate(raw, index, template, templates, table):
    _, _, records = section(raw, 0x18, 0x64, 33)
    record = records[index * 33:(index + 1) * 33]
    assert record[32] == template
    x, y, heading, h = struct.unpack_from('<hhHh', record)
    t = templates[template]; assert len(t['children']) == 1
    child = t['children'][0]; assert child['type_byte'] == 0 and child['mask'] == 0xffffffff and child['bounds'][4:] == [0, 0]
    xmin, xmax, ymin, ymax, _, _ = child['bounds']
    polygon = []
    for lx, ly in [(xmin, ymin), (xmax, ymin), (xmax, ymax), (xmin, ymax)]:
        wx, wy = model((lx << 16, ly << 16), (x << 16, y << 16), heading, table)
        polygon.append([wx / 65536, -wy / 65536])
    return record, dict(position=[x, h, -y], heading=heading, height=h, polygon=polygon, child_raw=child['raw_hex'])


def encode(vqa, folder, frames, ogv):
    folder.mkdir(parents=True, exist_ok=True)
    data = vqa.read_bytes()
    width, height = struct.unpack_from('<HH', data, 26)
    assert struct.unpack_from('<H', data, 24)[0] == frames and data[32] == 15, vqa
    lol2_movie_media.decode(vqa, folder / 'frames', frames, (width, height))
    wav = folder / 'audio.wav'
    subprocess.run(['ffmpeg', '-v', 'quiet', '-y', '-i', str(vqa), '-vn', '-ac', '1', '-c:a', 'pcm_s16le', str(wav)], check=True)
    with wave.open(str(wav)) as w:
        rate, samples = w.getframerate(), w.getnframes()
    # bst-die carries 0.5 s more audio than video (484364 samples vs 322 frames); samples are recorded as decoded.
    assert rate == 22050 and abs(samples / rate - frames / 15) < 1.0, (vqa, samples)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-fflags', '+bitexact', '-framerate', '15', '-i', str(folder / 'frames/%04d.png'),
                    '-i', str(wav), '-map', '0:v:0', '-map', '1:a:0', '-c:v', 'libtheora', '-g', '1', '-q:v', '7',
                    '-c:a', 'libvorbis', '-q:a', '5', '-flags:v', '+bitexact', '-flags:a', '+bitexact', '-fflags', '+bitexact',
                    '-serial_offset', '1', str(ogv)], check=True)
    probe = json.loads(subprocess.run(['ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-of', 'json', str(ogv)],
                                      capture_output=True, text=True, check=True).stdout)
    video = next(s for s in probe['streams'] if s['codec_type'] == 'video')
    assert int(video['nb_read_frames']) == frames and (video['width'], video['height']) == (width, height), probe
    return dict(width=width, height=height, frames=frames, fps=15, seconds=round(frames / 15, 4), samples=samples, rate=rate)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    for tool in ('ffmpeg', 'ffprobe'):
        if shutil.which(tool) is None: p.error(f'{tool} not found on PATH')
    try:
        exe = (a.game / 'LOLG.DAT').read_bytes()
        table = struct.unpack('<4096i', rotation_table(a.game))
        native_checks(exe)
        archive = (a.game / 'DAT/L1_DC.MIX').read_bytes()
        movies = (a.game / 'DAT/L1_DCI.MIX').read_bytes()
        support = json.loads((ROOT / 'scripts/lol2/cave_support_controls_source.json').read_text())
        assert sha(archive) == support['source']['sha256']
        entry = next(e for e in parse_mix(archive) if e['key'] == GEOMETRY_KEY)
        raw = archive[entry['offset']:entry['offset'] + entry['size']]
        assert sha(raw) == support['source']['geometry_sha256']
        metas = [e for e in parse_mix(archive) if archive[e['offset']:e['offset'] + 8] == struct.pack('<II', 18, 516)]
        assert len(metas) == 1
        meta = archive[metas[0]['offset']:metas[0]['offset'] + metas[0]['size']]
        assert sha(meta) == support['metadata_sha256']
        templates = load_movable_templates(meta)['templates']
        # Method check: the published plate89 polygon is reproduced exactly.
        published89 = next(q for q in support['plates'] if q['id'] == 89)
        _, check89 = plate(raw, 89, 21, templates, table)
        assert check89['polygon'] == published89['polygon'], 'plate89 polygon method mismatch'
        record, geometry = plate(raw, CONTROL, TEMPLATE, templates, table)
        assert record.hex() == CONTROL_HEX
        _, region_count, _ = section(raw, 12, 0x58, 44)
        owners, _ = collect_owners(raw, entry['offset'], region_count)
        mine = [o for o in owners if o['owner_kind'] == 'control' and o['owner'] == CONTROL]
        assert sorted((o['event'], o['value'], o['predicate'], o['stream'], o['group']) for o in mine) == \
            sorted((5, v, 206, 1, g) for v, (g, _) in GROUPS.items()), mine
        _, _, ptable = section(raw, 0xbc, 0xb8, 5)
        assert predicate(ptable, 206)['raw'] == PREDICATE_HEX
        _, _, blob = section(raw, 0x44, 0x8c, 1)
        parsed = {g: [b.hex() for _, b in cmds] for g, cmds in groups(blob)}
        keyed = {e['key']: (i, e) for i, e in enumerate(parse_mix(movies))}
        records = []
        for value, (group, commands) in sorted(GROUPS.items()):
            assert parsed[group] == commands, group
            movie = next(int(c[8:10], 16) for c in commands if c.startswith('15'))
            owner = next(o for o in mine if o['value'] == value)
            records.append(dict(value=value, form=FORMS[value], group=group, predicate=206, movie=movie,
                                archive_offset=owner['archive_offset'], commands=commands))
    except (AssertionError, KeyError, StopIteration, ValueError, OSError) as error:
        print(f'refused: {error!r}', file=sys.stderr); raise SystemExit(1)
    media_root = ROOT / MEDIA_DIR
    clips = {}
    with tempfile.TemporaryDirectory(prefix='.entrance-death-') as tmp:
        stage = Path(tmp)
        for index, (name, entry_index, file, frames) in sorted(MOVIES.items()):
            key = ww_hash_v1('SPHERE1\\L1_DC\\%s.VQA' % name)
            assert key in keyed and keyed[key][0] == entry_index, name
            e = keyed[key][1]; data = movies[e['offset']:e['offset'] + e['size']]
            assert data[:4] == b'FORM' and data[8:12] == b'WVQA'
            vqa = stage / f'{file}.vqa'; vqa.write_bytes(data)
            info = encode(vqa, stage / file, frames, stage / f'{file}.ogv')
            clips[str(index)] = dict(name=NATIVE_NAMES[index], archive='DAT/L1_DCI.MIX', entry=entry_index, key=key,
                                     source_sha256=sha(data), path=f'res://{MEDIA_DIR}/{file}.ogv', **info)
        media_root.mkdir(parents=True, exist_ok=True)
        for index, (_, _, file, _) in MOVIES.items():
            shutil.copyfile(stage / f'{file}.ogv', media_root / f'{file}.ogv')
            clips[str(index)]['sha256'] = sha((media_root / f'{file}.ogv').read_bytes())
    result = dict(version=1, source=support['source'], metadata_sha256=support['metadata_sha256'],
                  rotation_sha256=support['rotation_sha256'], control=CONTROL, template=TEMPLATE, raw_hex=CONTROL_HEX,
                  position=geometry['position'], heading=geometry['heading'], height=geometry['height'],
                  polygon=geometry['polygon'], child_raw=geometry['child_raw'], records=records, movies=clips,
                  scope='Native ADA30 support-owner entry admission per form; owner state0 one-shot; op2 sub0x39 '
                        'immediate death; op21 full-screen movie. Grounded foot tolerance and polygon admission are '
                        'the same explicit adapters as source_control_contact.gd.')
    a.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS cave entrance death: control135 plate, events 7/8/9, movies luthrdie/bst-die/liz-die (48/322/100 frames)')


if __name__ == '__main__':
    main()
