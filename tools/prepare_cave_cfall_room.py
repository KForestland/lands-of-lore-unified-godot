#!/usr/bin/env python3
"""Cave waterfall room CFALL (room 32, `cfall_`): the source contract and its local original media.

  python3 tools/prepare_cave_cfall_room.py --game GAME_ROOT --output scripts/lol2/cave_cfall_source.json

GAME_ROOT holds LOLG.DAT, LOCALLNG.MIX, DAT/L1_DC.MIX and DAT/CFALL.MIX. Every fact is asserted from bytes; nothing
is written unless all hold. Report: AI_COMMS/act1_completion_20261017/CAVE_CFALL_BUILD_20261028.md.

Level side (L1_DC stream 0):
- regions 1815/1817/1818, event 2 (grounded entry), groups 2040/2070/2100: `0c03ca002000` (op12 -> ED6D0(0x20): the room
  loader; indices >= 46 are refused) then an op18 player placement (flags 0x0885) per region.
- room 32 is `cfall_` in the LOLG.DAT room-name list (string order from `pool_`; the proven anchors chut_ 14 and text_ 44
  are asserted).
Room side (CFALL_.WOM, the 13-entry callback dispatcher at module offset 0; host slots as THIEVES_DEN_DECODE s2):
- 1 setup 0x47C: hotspot(0, 334,301, 639,399), hotspot(1, 158,350, 349,399) (the pool).
- 2 teardown 0x4C0: remove both hotspots, ambient_stop(handle, 344).
- 4 click 0x4F5: hotspot 0 or 1 -> slot 0x58(5) = D6A08(player, 5) (the heal Morgan's orb uses), movie(2,55,24),
  movie(2,20,24), set_flag(6). Every click, no latch.
- 8 leave 0x538: exit_room (the level group's op18 then places the player).
- 9 first update 0x541: ambient_start(344, 130); if flag5 == 0: set_flag(5), movie(2,26,24).
- 10 timer: cancel_timer. 3/5/6/7: nothing (return 0). 11/12: return 1.
- Flags 5 and 6 are read or written by no other room DLL (all 47 scanned).
Media (assets/lol2/generated/cave_cfall/, local only): CFALL_.VQA (30 frames, 640x400, no audio) decoded by
tools/lol2_movie_media.py and encoded to Theora; the three speaker-2 sound-bank cues 2:20, 2:26, 2:55 (trailer index
line + 141, as tools/verify_thieves_den_sources.bank_cue) as wav. Two runs give identical bytes.
"""
import argparse, hashlib, json, math, shutil, struct, subprocess, sys, tempfile, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_game_atlas import parse_mix, section
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from lol2_geometry_format import slope_corners
from lol2_movie_format import ww_hash_v1
import lol2_movie_media

L1_SHA256 = '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
GEOMETRY_KEY = 2971673856
CFALL_SHA256 = 'a8f0b12bd82585a51f017daa4a558de136ef7fa2450ff508b003282d55746acc'
LOCALLNG_SHA256 = '113a35353cac0344db298616ea4eff9fd254ab83494079ce7777560b655ee2d8'
SOUND_BANK = (1570429112, 'e2d6df9a11a3d5bf6746911eac464c7f90efceaf7535e32a0f582dcea6afc3f6')
SPEAKER2_BIAS = 141
REGIONS = {1815: (2040, '120100001802922b000085081151000a0000'),
           1817: (2070, '120100001302952b000085081151000a0000'),
           1818: (2100, '120100000f02962b000085081151000a0000')}
OP12 = '0c03ca002000'
ROOM = 32
HOTSPOTS = [[0, 334, 301, 639, 399], [1, 158, 350, 349, 399]]
CUES = [20, 26, 55]
AMBIENT = [344, 130]
HEAL = 5
# Module bytes of the callbacks this contract depends on (offsets are module offsets after the 48-byte header).
CODE = {
    0x47C: '688f010000687f020000682d010000684e0100006a00ff15ac05000083c414688f010000684d010000685e010000689e0000006a01ff15ac05000083c414b801000000c3',
    0x4F5: '8b54240485d27405' '83fa0175f0' '6a05ff15f005000083c404' '6a186a376a02ff15e805000083c40c' '6a186a146a02ff15e805000083c40c' '6a06ff15dc05000083c404eb82',
    0x538: 'ff150006000031c0c3',
    0x541: '68820000006858010000ff15d006000083c408a3d80600006a05ff15e405000083c40485c075206a05ff15dc05000083c4046a186a1a6a02ff15e805000083c40cb801000000c331c0c3',
}
# Host slot 0x58 (EF3AC, VA B6388): push player 0x22574, call 0x9D9E4 (A D6A08: hit points + n, capped at the maximum;
# no change when dead or player+0x229 bit 1). Slot 0x54 = EE784 movie, 0x48 = EF32C set_flag, 0x50 = EF380 get_flag.
SLOT58 = '8b5424045268742502' '00e84d76feff83c408c3'
MEDIA_DIR = 'assets/lol2/generated/cave_cfall'


def sha(data): return hashlib.sha256(data).hexdigest()
def u32(b, o): return struct.unpack_from('<I', b, o)[0]


def room_names(exe):
    start = exe.index(b'\x00pool_\x00cave_\x00') + 1
    names = []
    for raw in exe[start:start + 600].split(b'\x00'):
        if not raw: break
        names.append(raw.decode())
    return names


def bank_cue(bank, line):
    request = struct.unpack_from('<H', bank, len(bank) - 808 + (line + SPEAKER2_BIAS) * 2)[0]; assert request < u32(bank, 0x258)
    row = bank[u32(bank, 0x25c) + request * 60:][:60]; audio = bank[u32(row, 0):][:u32(row, 4)]
    rate, packed, decoded, flags, codec = struct.unpack_from('<HIIBB', audio); assert len(audio) == packed + 12 and codec == 99
    return audio, dict(request=request, trailer_index=line + SPEAKER2_BIAS, source_name=row[16:].split(b'\0')[0].decode(), audio_sha256=sha(audio), rate=rate, decoded=decoded)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    for tool in ('ffmpeg', 'ffprobe'):
        if shutil.which(tool) is None: p.error(f'{tool} not found on PATH')
    try:
        exe = (a.game / 'LOLG.DAT').read_bytes()
        names = room_names(exe)
        assert names[14] == 'chut_' and names[44] == 'text_' and names[ROOM] == 'cfall_', names
        slot = exe[0xEF3AC + 0x37000:0xEF3AC + 0x37000 + 19]
        assert slot.hex() == SLOT58, slot.hex()
        assert struct.unpack_from('<i', slot, 11)[0] + 0xB6388 + 15 == 0x9D9E4
        archive = (a.game / 'DAT/L1_DC.MIX').read_bytes(); assert sha(archive) == L1_SHA256
        entry = next(e for e in parse_mix(archive) if e['key'] == GEOMETRY_KEY)
        raw = archive[entry['offset']:entry['offset'] + entry['size']]
        _, region_count, region_bytes = section(raw, 12, 0x58, 44)
        _, _, vertex_bytes = section(raw, 4, 0x50, 8)
        owners, _ = collect_owners(raw, entry['offset'], region_count)
        _, _, blob = section(raw, 0x3c, 0x84, 1)
        parsed = {g: [b.hex() for _, b in cmds] for g, cmds in groups(blob)}
        records = list(struct.iter_unpack('<22H', region_bytes)); vertices = list(struct.iter_unpack('<ii', vertex_bytes))
        regions = []
        for region, (group, op18_hex) in sorted(REGIONS.items()):
            mine = [o for o in owners if o['owner_kind'] == 'region' and o['owner'] == region]
            assert [(o['stream'], o['event'], o['group'], o['predicate']) for o in mine] == [(0, 2, group, None)], mine
            assert parsed[group] == [OP12, op18_hex], parsed[group]
            op18 = bytes.fromhex(op18_hex)
            assert op18[:4] == bytes.fromhex('12010000') and struct.unpack_from('<H', op18, 10)[0] == 0x0885
            x, y, h, heading = struct.unpack_from('<hhh', op18, 4) + (struct.unpack_from('<H', op18, 12)[0],)
            heights = slope_corners(records, region)
            regions.append(dict(region=region, group=group, archive_offset=mine[0]['archive_offset'], commands=parsed[group],
                                polygon=[[vertices[i][0] / 65536, -vertices[i][1] / 65536] for i in records[region][6:10]],
                                floor_min=min(heights), floor_max=max(heights),
                                place=dict(x=x, y=y, h=h, flags=0x0885, heading=heading,
                                           yaw=round(math.remainder(-heading * math.tau / 65536.0, math.tau), 12))))
        mix = (a.game / 'DAT/CFALL.MIX').read_bytes(); assert sha(mix) == CFALL_SHA256
        keyed = {e['key']: e for e in parse_mix(mix)}
        dll = keyed[ww_hash_v1('WOMS\\CFALL_.WOM')]; dll = mix[dll['offset']:dll['offset'] + dll['size']]
        assert dll[:32] == b'This is a linear executable dll\n'
        module = dll[48:48 + u32(dll, 36)]
        for offset, code in CODE.items():
            assert module[offset:offset + len(code) // 2].hex() == code, hex(offset)
        table = [u32(module, 4 * i) for i in range(13)]
        assert table == [0x51, 0x5F, 0x69, 0x73, 0x87, 0x95, 0xA3, 0xAD, 0xB7, 0xC1, 0xCB, 0xD5, 0xE2], [hex(t) for t in table]
        vqa_row = keyed[ww_hash_v1('WOMS\\CFALL\\CFALL_.VQA')]
        vqa = mix[vqa_row['offset']:vqa_row['offset'] + vqa_row['size']]
        assert vqa[8:12] == b'WVQA'
        frames, width, height = struct.unpack_from('<HHH', vqa, 24)
        assert (frames, width, height, vqa[32]) == (30, 640, 400, 15), (frames, width, height)
        locallng = (a.game / 'LOCALLNG.MIX').read_bytes(); assert sha(locallng) == LOCALLNG_SHA256
        bank_row = next(e for e in parse_mix(locallng) if e['key'] == SOUND_BANK[0]); bank = locallng[bank_row['offset']:][:bank_row['size']]
        assert sha(bank) == SOUND_BANK[1]
        cues = {line: bank_cue(bank, line) for line in CUES}
    except (AssertionError, KeyError, StopIteration, ValueError, OSError) as error:
        print(f'refused: {error!r}', file=sys.stderr); raise SystemExit(1)
    media_root = ROOT / MEDIA_DIR
    clips = {}
    with tempfile.TemporaryDirectory(prefix='.cave-cfall-') as tmp:
        stage = Path(tmp)
        source = stage / 'CFALL_.VQA'; source.write_bytes(vqa)
        lol2_movie_media.decode(source, stage / 'frames', frames, (width, height))
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-fflags', '+bitexact', '-framerate', '15', '-i', str(stage / 'frames/%04d.png'),
                        '-map', '0:v:0', '-c:v', 'libtheora', '-g', '1', '-q:v', '7', '-flags:v', '+bitexact', '-fflags', '+bitexact', '-serial_offset', '1',
                        str(stage / 'cfall_.ogv')], check=True)
        probe = json.loads(subprocess.run(['ffprobe', '-v', 'error', '-count_frames', '-show_streams', '-of', 'json', str(stage / 'cfall_.ogv')],
                                          capture_output=True, text=True, check=True).stdout)
        assert int(probe['streams'][0]['nb_read_frames']) == frames
        for line, (audio, info) in cues.items():
            aud = stage / f'2_{line}.aud'; aud.write_bytes(audio); wav = stage / f'cue_2_{line}.wav'
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(aud), '-ac', '1', '-c:a', 'pcm_s16le', '-fflags', '+bitexact', '-flags:a', '+bitexact', str(wav)], check=True)
            with wave.open(str(wav)) as w: samples, rate = w.getnframes(), w.getframerate()
            assert rate == info['rate'] and samples * 2 == info['decoded'], 'AUD samples'
            clips['2:%d' % line] = dict(info, path=f'res://{MEDIA_DIR}/cue_2_{line}.wav', samples=samples, duration=samples / rate)
        media_root.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(stage / 'cfall_.ogv', media_root / 'cfall_.ogv')
        for line in CUES: shutil.copyfile(stage / f'cue_2_{line}.wav', media_root / f'cue_2_{line}.wav')
    for key, clip in clips.items(): clip['wav_sha256'] = sha((media_root / Path(clip['path']).name).read_bytes())
    background = dict(path=f'res://{MEDIA_DIR}/cfall_.ogv', frames=frames, width=width, height=height, fps=15,
                      source_sha256=sha(vqa), sha256=sha((media_root / 'cfall_.ogv').read_bytes()))
    result = dict(version=1, source=dict(file='DAT/L1_DC.MIX', sha256=L1_SHA256, geometry_key=GEOMETRY_KEY), room=ROOM, room_name='cfall_',
                  archive=dict(file='DAT/CFALL.MIX', sha256=CFALL_SHA256, dll_sha256=sha(dll)), regions=regions,
                  hotspots=HOTSPOTS, heal=HEAL, flags=[5, 6], ambient=AMBIENT, cues=clips, background=background,
                  scope='CFALL_.WOM callbacks 1/2/4/8/9 and the three entry regions. Ambient 344 is not hosted (no staged ambient bank).')
    a.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS cave CFALL: room32 cfall_, regions', sorted(REGIONS), 'hotspots 2, heal', HEAL, 'cues', sorted(clips), 'background', background['sha256'][:16])


if __name__ == '__main__':
    main()
