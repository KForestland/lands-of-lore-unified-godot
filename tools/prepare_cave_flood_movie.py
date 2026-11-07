#!/usr/bin/env python3
"""Cave prop83 chain: the FLOOD movie of g146 (op21 prop614 movie 29), audit CAVE_OVERVIEW_20261028 s2.2.

  python3 tools/prepare_cave_flood_movie.py --game GAME_ROOT --output scripts/lol2/cave_flood_source.json

Source facts asserted byte for byte (GAME_ROOT holds LOLG.DAT, DAT/L1_DC.MIX and DAT/L1_DCI.MIX):
- prop83's kind-8 record value 956 (the end of sound 956) runs stream-1 group 146, whose second command is
  `150366021d00`: op21 on prop614, movie 29. The other g146 commands are pinned as they are.
- op21 (64770 -> CF2B4) plays the global movie-name table entry (ds+0xE568) as "%s.vqa"; entry 29 is "flood".
- The VQA is L1_DCI entry 14 under ww_hash_v1('SPHERE1\\L1_DC\\FLOOD.VQA').
Media: full frames decoded by tools/lol2_movie_media.py, encoded to Ogg Theora/Vorbis exactly as
tools/prepare_cave_entrance_death.py does (its encode()). Two runs give identical bytes.
"""
import argparse, hashlib, json, shutil, struct, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_game_atlas import parse_mix, section
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from lol2_movie_format import ww_hash_v1
from prepare_cave_entrance_death import encode

GEOMETRY_KEY = 2971673856
L1_SHA256 = '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
PROP = 83
GROUP = 146
G146 = ['090353000800', '150366021d00', '120100006801d62a00000508388e000a0000', '050353000200', '100353000100',
        '0903be000200', '0903d9010200', 'cc901104f6056a02', 'cc901104f5056a02', 'cc900f0413036a02', 'cc900d04f4056a02',
        'cc900d04f3056a02', '060366020100', '100353000100', '090353001500']
MOVIE = 29
NAME = 'flood'
ENTRY = 14
MEDIA_DIR = 'assets/lol2/generated/cave_flood'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def movie_name(exe, index):
    ds = exe.index(b'ss-\x00%s.vqa\x00') + 4 - 0x2C88
    return exe[ds + struct.unpack_from('<I', exe, ds + 0xE568 + 4 * index)[0]:].split(b'\0')[0].decode()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    for tool in ('ffmpeg', 'ffprobe'):
        if shutil.which(tool) is None: p.error(f'{tool} not found on PATH')
    try:
        exe = (a.game / 'LOLG.DAT').read_bytes()
        assert movie_name(exe, MOVIE) == NAME, movie_name(exe, MOVIE)
        # The three death movies the entrance producer pins come from the same table (method check).
        assert [movie_name(exe, i) for i in (74, 11, 35)] == ['luthrdie', 'bst-die', 'liz-die']
        archive = (a.game / 'DAT/L1_DC.MIX').read_bytes()
        assert sha(archive) == L1_SHA256
        entry = next(e for e in parse_mix(archive) if e['key'] == GEOMETRY_KEY)
        raw = archive[entry['offset']:entry['offset'] + entry['size']]
        _, region_count, _ = section(raw, 12, 0x58, 44)
        owners, _ = collect_owners(raw, entry['offset'], region_count)
        mine = [o for o in owners if o['owner_kind'] == 'prop' and o['owner'] == PROP and o['group'] == GROUP]
        assert [(o['stream'], o['event'], o['value']) for o in mine] == [(1, 8, 956)], mine
        _, _, blob = section(raw, 0x44, 0x8c, 1)
        parsed = {g: [b.hex() for _, b in cmds] for g, cmds in groups(blob)}
        assert parsed[GROUP] == G146, parsed[GROUP]
        op21 = bytes.fromhex(G146[1])
        assert op21[0] == 21 and op21[1] == 3 and struct.unpack_from('<H', op21, 2)[0] == 614 and op21[4] == MOVIE
        movies = (a.game / 'DAT/L1_DCI.MIX').read_bytes()
        keyed = {e['key']: (i, e) for i, e in enumerate(parse_mix(movies))}
        key = ww_hash_v1('SPHERE1\\L1_DC\\FLOOD.VQA')
        assert key in keyed and keyed[key][0] == ENTRY, key
        e = keyed[key][1]; data = movies[e['offset']:e['offset'] + e['size']]
        assert data[:4] == b'FORM' and data[8:12] == b'WVQA'
        frames = struct.unpack_from('<H', data, 24)[0]
    except (AssertionError, KeyError, StopIteration, ValueError, OSError) as error:
        print(f'refused: {error!r}', file=sys.stderr); raise SystemExit(1)
    media_root = ROOT / MEDIA_DIR
    with tempfile.TemporaryDirectory(prefix='.cave-flood-') as tmp:
        stage = Path(tmp)
        vqa = stage / 'flood.vqa'; vqa.write_bytes(data)
        info = encode(vqa, stage / 'flood', frames, stage / 'flood.ogv')
        media_root.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(stage / 'flood.ogv', media_root / 'flood.ogv')
    clip = dict(name=NAME, archive='DAT/L1_DCI.MIX', entry=ENTRY, key=key, source_sha256=sha(data),
                path=f'res://{MEDIA_DIR}/flood.ogv', **info, sha256=sha((media_root / 'flood.ogv').read_bytes()))
    result = dict(version=1, source=dict(file='DAT/L1_DC.MIX', sha256=L1_SHA256, geometry_key=GEOMETRY_KEY), prop=PROP,
                  group=GROUP, record=dict(kind=8, value=956, archive_offset=mine[0]['archive_offset']), commands=G146,
                  op21=dict(index=1, target=['prop', 614], movie=MOVIE), movie=clip,
                  scope='g146 op21 only: the full-screen FLOOD movie at the prop83 chain transition. g146 op9 property8, '
                        'op204 materials and op6 prop614 event1 are not hosted.')
    a.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS g146 op21 movie29 flood = L1_DCI entry %d, %d frames, %s' % (ENTRY, frames, clip['sha256']))


if __name__ == '__main__':
    main()
