#!/usr/bin/env python3
"""Prepare the Cave scenery pack: undrawn ambient L1_DC props and the Cave-arrival positional sound emitters.

Evidence: AI_COMMS/grok_backlog_20261028/G44_cave_props (225 scenery rows) and G45_cave_ambient (20 owner records,
27 opcode-20 commands). Props: the generic map exporter (lol2/map_props, also used by prepare_ambient_prop_media.py)
gives each placement's selector, material, native bounds (region-height rule applied) and indexed frames. A row is
hosted only when it is ambient: no owner record of its own except an event6 value9 group whose only commands are its
own opcode-20 sound, and no command anywhere targets it except that sound. Torch template73 state0 has state byte11
bit0 set, the F1A94 chain also drawn by museum_torches.gd: state1 (descriptor222) is drawn at the same anchor.
Emitters: event6 value9 owner records (native caller not traced: trigger UNKNOWN, G45) whose group holds an
opcode-20 command (14 <kind> <id16> <sound16> <volume> <flags> <inner/16> <(inner+outer)/16>) that targets the owner
itself. Commands naming another object (prop383 -> prop380, prop343's eight children) are listed as not hosted.
Usage: prepare_cave_scenery.py --game ~/lol2_runtime_root --output-root FRESH_DIR
Writes FRESH_DIR/scripts/lol2/cave_scenery_source.json and FRESH_DIR/assets/lol2/generated/cave_scenery/.
"""
import argparse, hashlib, json, shutil, struct, sys, tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS)); sys.path.insert(0, str(TOOLS / 'lol2'))
ARCHIVE_SHA = '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
GROUPS = {73: 'wall torch', 48: 'meat (hanging)', 90: 'jungle mist', 81: 'waterfall', 0: 'water pillar',
          2: 'big water pillar', 3: 'water pillar', 65: 'shrinktofit'}
# Records of those templates hosted elsewhere or with behaviour of their own (see NOT_HOSTED).
EXCLUDED = {139, 140, 141, 142, 143, 473, 19, 484, 486}
NOT_HOSTED = [
    dict(records=[139, 140, 141, 142, 143], reason='already hosted by cave_side_chamber.gd'),
    dict(records=[473], reason='already hosted by cave_stalactites.gd (prop473)'),
    dict(records=[19], reason='torch moved by op18 (to -525, 11204) in groups 8478/8556; not static scenery'),
    dict(records=[484, 486], reason='own event groups (484: event9 value1, event4 predicate207; 486: event2 value560, '
                                    'event6 value20 predicates 207-214); behaviour not decoded'),
    dict(records=[1208, 1209, 1210, 1211], reason='Small/Medium Oil: tar-fire rows; need cave_tar_fires.gd ignition, not ambient'),
    dict(records=[536, 537, 539, 540, 541, 542], reason='meat drawn; their event4 (E use, predicate206) groups '
                                                          '(op16 state1 + sound) are not hosted'),
    dict(emitters=['prop383 -> prop380 sound760', 'prop343 group3008: eight opcode-20 children naming props 84/206/936/638/751/873 and control139'],
         reason='the command targets another object; which position the handler uses is UNKNOWN (G45 handler_argument)'),
]
ADAPTERS = [
    'frame_seconds 0.1: every row animates at the rate the other Cave hosts use (owner trial 2026-10-29; native rate UNKNOWN, G67)',
    'the torch flame (chained state1) quad is offset 0.05 units toward the camera so it draws over its coplanar holder',
    'frame flag 0x10 (additive overlay, mist) and 0x20 (waterfall) are not rendered differently; 0x40/0x80 flips are',
    'emitters loop (AudioStreamWAV LOOP_FORWARD): the native loop bit is undecoded (G45); name is the LOCALLNG sound-bank '
    'row label of the selector (prepare_creature_audio_clips), not a filename read from the command',
    'emitter gain/range use the port 3D defaults (unit_size 64, volume 0 dB); the stored native volume byte and the '
    '+0x18/+0x1c dwords are kept in the contract, their audible use is UNKNOWN (G45)',
    'emitters start once the Cave walkthrough is ready and are not saved: the native trigger of these event6 value9 '
    'groups is UNKNOWN (no runtime caller entered, G45)',
]


def sha(b): return hashlib.sha256(b).hexdigest()


def require(c, m):
    if not c: raise ValueError(m)


def prepare(game, output):
    from lol2 import map_materials, map_props
    from lol2_source_format import u32, parse_mix
    from verify_actor_item_grants import source_area
    from build_game_atlas import section
    from prepare_creature_audio_clips import stage_clips
    require(not output.exists(), 'Output must be a fresh directory')
    require(sha((game / 'DAT/L1_DC.MIX').read_bytes()) == ARCHIVE_SHA, 'Unsupported L1_DC.MIX')
    area, archive, item, raw, owners, streams = source_area('L1_DC', game)
    with tempfile.TemporaryDirectory(prefix='cave-scenery-') as scratch:
        root = Path(scratch) / 'L1'
        map_materials.export_materials(game, 'L1_DC', root / 'materials')
        map_props.export_props(game, 'L1_DC', root / 'props', root / 'materials')
        exported = {p['record']: p for p in json.loads((root / 'props/props.json').read_text())['props']}
        texture = (root / 'materials/texture.bin').read_bytes()
        sections = map_props.mm.sections(texture)
        palette = map_props.mm.rgb_palette(texture[u32(texture, 4):][:768], 6)
        meta = next(archive[e['offset']:e['offset'] + e['size']] for e in parse_mix(archive) if e['key'] == 2971019266)
        templates = map_props.load_templates(meta)['templates']
        out = Path(scratch) / 'pack'; out.mkdir()
        art = {}

        def frames_of(material, image=None):
            if material in art: return art[material]
            names = []
            if image is None:
                plain = root / 'props/sprites' / f'{material}_index.png'
                if plain.exists(): sources = [plain]
                else:
                    sources = []
                    while (root / 'props/sprites' / f'{material}_frame_{len(sources)}_index.png').exists():
                        sources.append(root / 'props/sprites' / f'{material}_frame_{len(sources)}_index.png')
            else:
                sources = [Path(scratch) / 'chain' / f for f in image.get('index_frames', [image['index']])]
            require(sources, 'No frames for ' + material)
            for i, s in enumerate(sources):
                name = f'{material}_{i}_index.png'; shutil.copyfile(s, out / name); names.append(name)
            art[material] = names
            return names

        # Ambient test (the prepare_cave_lava_flames.py rule): owner records and targeting commands per record.
        own = {}
        for o in owners:
            if o['owner_kind'] == 'prop': own.setdefault(o['owner'], []).append(o)
        targeted = {}
        for s in streams:
            for cmds in s.values():
                for c in cmds:
                    h = c['raw_hex']
                    if len(h) >= 8 and h[2:4] == '03': targeted.setdefault(int.from_bytes(bytes.fromhex(h[4:8]), 'little'), []).append(h)

        def own_sound_only(r):
            for o in own.get(r, []):
                if not (o['event'] == 6 and o['value'] == 9 and o['predicate'] is None): return False
                for c in streams[o['stream']].get(o['group'], []):
                    h = c['raw_hex']
                    if h[:2] != '14': return False  # opcode-20 sound only (prop383's names prop380)
            for h in targeted.get(r, []):
                if not h.startswith('14'): return False
            return True

        props = {}
        for r in sorted(exported):
            q = exported[r]
            if q['template'] not in GROUPS or r in EXCLUDED: continue
            meat_use = q['template'] == 48 and all(o['event'] == 4 for o in own.get(r, [])) and \
                all(h[:2] in ('10', '14') for h in targeted.get(r, []))
            require(own_sound_only(r) or meat_use, f'record {r} is not ambient')
            require(q['selector'] == 0, f'record {r} starts on selector {q["selector"]}')
            row = dict(template=q['template'], group=GROUPS[q['template']], position=q['position'], region=q['region'],
                       material=q['material'], frames=frames_of(q['material']), left=q['left'], right=q['right'],
                       bottom=q['bottom'], top=q['top'], frame_flags=q['frame_flags'],
                       placement_offset=q['placement_offset'])
            states = templates[q['template']]['selectors']
            if states[0]['state_hex'][22:24] != '00' and int(states[0]['state_hex'][22:24], 16) & 1:
                # F1A94: state byte11 bit0 draws the next state at the same anchor.
                nxt = states[1]; f = nxt['frames'][0]
                require(len(nxt['frames']) == 1 and q['template'] == 73, 'Unexpected chain')
                work = Path(scratch) / 'chain'; (work / 'sprites').mkdir(parents=True, exist_ok=True)
                image = map_props.build_image(f['descriptor'], texture, sections, palette, work / 'sprites', work, {})
                material = 'prop_%d' % f['descriptor']
                row['chain'] = dict(material=material, frames=frames_of(material, image), left=f['left'], right=f['right'],
                                    bottom=f['bottom'], top=nxt['state_height'] - f['top_trim'], frame_flags=f['frame_flags'])
            props[str(r)] = row
        require(len(props) == 58, 'Scenery row count changed: %d' % len(props))

        _, _, controls = section(raw, 0x18, 0x64, 33)
        def control_position(n):
            x, y, _, h = struct.unpack_from('<hhHh', controls, n * 33)
            return [x, h, -y]
        emitters, sounds = {}, set()
        for o in owners:
            if not (o['event'] == 6 and o['value'] == 9 and o['predicate'] is None): continue
            kind = {'prop': '03', 'control': '10'}.get(o['owner_kind'])
            for c in streams[o['stream']].get(o['group'], []):
                h = c['raw_hex']
                if not h.startswith('14'): continue
                b = bytes.fromhex(h)
                target = int.from_bytes(b[2:4], 'little')
                if not (h[2:4] == kind and target == o['owner']): continue
                sound = int.from_bytes(b[4:6], 'little')
                position = exported[o['owner']]['position'] if o['owner_kind'] == 'prop' else control_position(o['owner'])
                emitters['%s%d' % (o['owner_kind'], o['owner'])] = dict(
                    owner_kind=o['owner_kind'], owner=o['owner'], position=position, sound=sound, file=f'{sound}.wav',
                    volume=b[6], flags=b[7], inner=b[8] << 4, outer=(b[8] + b[9]) << 4, group=o['group'],
                    command_offset=c['archive_offset'])
                sounds.add(sound)
        require(len(emitters) == 18, 'Emitter count changed: %d' % len(emitters))
        staged = Path(scratch) / 'audio'
        clips = stage_clips(staged, 'cave_scenery', sorted(sounds), game=game)
        for s in sorted(sounds):
            shutil.copyfile(staged / 'assets/lol2/generated/cave_scenery' / f'{s}.wav', out / f'{s}.wav')
        names = {str(k): v['name'] for k, v in clips.items()} if isinstance(clips, dict) else {}
        for e in emitters.values(): e['name'] = names.get(str(e['sound']), '')
        files = {p.name: sha(p.read_bytes()) for p in sorted(out.iterdir())}
        contract = dict(version=1, source=dict(area='L1_DC', archive_sha256=ARCHIVE_SHA, geometry_key=2971673856,
                                               metadata_key=2971019266, evidence=['G44_cave_props', 'G45_cave_ambient']),
                        frame_seconds=0.1, art=art, props=props, emitters=emitters, files=files,
                        not_hosted=NOT_HOSTED, adapters=ADAPTERS,
                        scope='Ambient Cave scenery and arrival sound emitters; nothing is saved; no collision '
                              '(blocking UNKNOWN on every row, G44).')
        target = output / 'assets/lol2/generated/cave_scenery'; target.parent.mkdir(parents=True)
        shutil.copytree(out, target)
        (output / 'scripts/lol2').mkdir(parents=True)
        (output / 'scripts/lol2/cave_scenery_source.json').write_text(json.dumps(contract, indent=1) + '\n')
    return dict(props=len(props), emitters=len(emitters), files=len(files))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output-root', type=Path, required=True)
    a = p.parse_args()
    try:
        print(json.dumps(prepare(a.game.resolve(), a.output_root.resolve())))
    except (ValueError, OSError, KeyError, StopIteration) as error:
        p.error(str(error))


if __name__ == '__main__':
    main()
