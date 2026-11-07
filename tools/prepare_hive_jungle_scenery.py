#!/usr/bin/env python3
"""Prepare the Hive + Jungle scenery pack: the ambient L5_HC / L4_HJ prop records the port does not draw yet.

Evidence: AI_COMMS/grok_backlog_20261028/G58_hive_jungle_props (the 1179 unplaced records) and G71_hive_jungle_props_ready
(the build-ready subset: 850 rows, of which 157 use the all-zero descriptor 0 and stay out). Everything here is rebuilt
from the original archives with the published readers; the G58/G71 JSON files are not inputs.

Per area the generic map exporter (lol2/map_props, also behind prepare_jungle_props.py and prepare_cave_scenery.py) gives
each placement its selector, material, native box (left/right/bottom/top, the region-height rule applied) and RGBA frames.
A record becomes a scenery row only when all of these hold:
- it is visual (descriptor != 0; the exporter's nonvisual_props are the descriptor-0 slots);
- no port host draws it already: the PLACED records below (feature packs and *_source.json contracts), and in the Jungle
  every record jungle_props.gd instances (prepare_jungle_props.py rule: no owner record and not named by any kind-3 command);
- it is ambient (the prepare_cave_scenery.py test): no owner record except an event6 value9 predicate-none group whose
  commands are all opcode 20 (sound), and no command with target kind 3 names it except opcode 20;
- its first frame has at least one opaque pixel (descriptor 267 'Inviso Light' is a fully transparent 24x24 slot);
- its region word is bound: Hive 615/685/767 and Jungle 560 carry region word 65535 and record heights -9036, -12242, +12054
  and +15251, far outside their maps; how the native draw treats a null-region placement is not traced.
Records failing the ambient test are listed in the contract's left_out with the byte reason; the others in not_hosted.
Only the FIRST frame is shown by the host (frame_seconds null): no Hive or Jungle frame rate is proven (G58/G67). All frames
are still staged so a later rate can be applied without a new producer run.
The 90 sound-only owner groups (opcode 20 on the owner itself) are decoded into the contract (sound_groups) and NOT hosted:
sound is the owner's last priority and no runtime caller of these groups is traced.
Usage: prepare_hive_jungle_scenery.py --game ~/lol2_runtime_root --output-root FRESH_DIR
Writes FRESH_DIR/scripts/lol2/hive_jungle_scenery_source.json and FRESH_DIR/assets/lol2/generated/hive_jungle_scenery/.
Two runs are byte-identical.
"""
import argparse, hashlib, json, shutil, sys, tempfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS)); sys.path.insert(0, str(TOOLS / 'lol2'))
AREAS = {
    'L5_HC': dict(archive='DAT/L5_HC.MIX', sha='a1979e60d401ae308e430f69a7163ff07a7f704aeb233769add85e7cc0960bf8',
                  geometry_key=3776990464, metadata_key=3776335874, name='Hive Caves'),
    'L4_HJ': dict(archive='DAT/L4_HJ.MIX', sha='517afe6d59a4a06212bf4aea7eb42dfbb07826a4677fb77a4032674e64657e8f',
                  geometry_key=3710797084, metadata_key=3710142494, name='Huline Jungle'),
}
# Records another port host already draws (G71 recount at r12p 961949d; placement hex found in the named pack/contract).
PLACED = {
    'L5_HC': {**{r: 'hive_chasm/chasm.json' for r in range(188, 199)}, 233: 'hive_chasm/chasm.json', 215: 'hive_pillar/pillar.json',
              316: 'hive_ambush/ambush.json', 317: 'hive_ambush/ambush.json', 318: 'hive_ambush/ambush.json', 363: 'hive_ambush/ambush.json',
              327: 'hive_rune_entry/entry.json', 377: 'hive_rune_light/light.json',
              401: 'hive_reaver_pillars_source.json', 426: 'hive_reaver_pillars_source.json',
              676: 'hive_reaver_pillars_source.json', 725: 'hive_reaver_pillars_source.json'},
    'L4_HJ': {64: 'jungle_kityara_source.json', 65: 'jungle_kityara_source.json', 66: 'jungle_kityara_source.json',
              67: 'jungle_kityara_source.json', 68: 'jungle_confidante_source.json', 492: 'jungle_confidante_source.json',
              1465: 'jungle_confidante_source.json', 484: 'jungle_drunk_source.json', 485: 'jungle_drunk_source.json',
              552: 'jungle_exit_encounter_source.json', 427: 'jungle_chief_hut', 1486: 'jungle_chief_hut',
              **{r: 'jungle_chief_hut' for r in range(561, 573)},
              **{r: 'jungle_causeway' for r in (506, 507, 508, 509, 4160, 4161, 4162, 4181)},
              **{r: 'jungle_bridge_break' for r in range(961, 966)}},
}
EXPECTED_ROWS = {'L5_HC': 666, 'L4_HJ': 16}  # G71 build-ready (736/114) minus descriptor 0 (60/97), minus the two not_hosted rules below (7+3 / 1)
ADAPTERS = [
    'frame_seconds null: every row shows its FIRST frame and never animates (no Hive or Jungle frame rate is proven, G58/G67; '
    'the Cave 0.1 s owner trial is not copied)',
    'rows are drawn as fixed-Y billboards (BILLBOARD_FIXED_Y, the jungle_props.gd adapter) at the native box; the native '
    'sprite projection is the untraced column plotter',
    'frame flags 0x40/0x80 flip columns/rows (native 129AC8 setup); 0x10 (additive) and 0x20 are not rendered differently',
    'no collision: blocks_movement is UNKNOWN on every row (G58, the 0x1721CC test is for 60-byte assemblies, not 37-byte props)',
    'nothing is saved; the rows have no state',
]


def sha(b): return hashlib.sha256(b).hexdigest()


def require(c, m):
    if not c: raise ValueError(m)


def template_names(meta, count):
    """The 38-byte name table that ends at u32(meta, 0x0c) (G58 names_and_templates)."""
    from lol2_source_format import u32
    require(u32(meta, 0) == 18 and u32(meta, 4) == 516 and u32(meta, 0x40) == count, 'metadata marker or template count')
    end = u32(meta, 0x0c); start = end - count * 38
    require(start >= 0, 'name table span')
    names = []
    for i in range(count):
        slot = meta[start + i * 38:start + (i + 1) * 38]
        require(b'\0' in slot, 'name slot')
        name = slot.split(b'\0', 1)[0]
        require(name and all(32 <= b <= 126 for b in name), 'name bytes')
        names.append(name.decode('ascii'))
    return names


def opaque_pixels(path):
    from PIL import Image
    with Image.open(path) as image:
        require(image.mode == 'RGBA', 'exporter frames are RGBA')
        return sum(1 for a in image.getchannel('A').getdata() if a > 0)


def prepare_area(area_id, game, scratch, out):
    from lol2 import map_materials, map_props
    from lol2_source_format import parse_mix
    from verify_actor_item_grants import source_area
    spec = AREAS[area_id]
    archive = (game / spec['archive']).read_bytes()
    require(sha(archive) == spec['sha'], 'Unsupported ' + spec['archive'])
    root = scratch / area_id
    map_materials.export_materials(game, area_id, root / 'materials')
    report = map_props.export_props(game, area_id, root / 'props', root / 'materials')
    require(report['materials_cross_check']['byte_identical'], 'texture blob cross-check')
    exported = {p['record']: p for p in report['props']}
    nonvisual = {p['record'] for p in report['nonvisual_props']}
    meta = next(archive[e['offset']:e['offset'] + e['size']] for e in parse_mix(archive) if e['key'] == spec['metadata_key'])
    templates = map_props.load_templates(meta)['templates']
    names = template_names(meta, len(templates))
    _, _, _, _, owners, streams = source_area(area_id, game)

    own = {}
    for o in owners:
        if o['owner_kind'] == 'prop': own.setdefault(o['owner'], []).append(o)
    targeted = {}
    for s in streams:
        for cmds in s.values():
            for c in cmds:
                h = c['raw_hex']
                if len(h) >= 8 and h[2:4] == '03':
                    targeted.setdefault(int.from_bytes(bytes.fromhex(h[4:8]), 'little'), []).append(c)

    def ambient_reason(r):
        """None when ambient, else the byte reason (prepare_cave_scenery.py test)."""
        for o in own.get(r, []):
            if not (o['event'] == 6 and o['value'] == 9 and o['predicate'] is None):
                return 'owner event %d value %d predicate %s is not the sound-only case' % (o['event'], o['value'], o['predicate'])
            for c in streams[o['stream']].get(o['group'], []):
                if c['raw_hex'][:2] != '14': return 'sound-only group %d holds opcode 0x%s' % (o['group'], c['raw_hex'][:2])
        for c in targeted.get(r, []):
            if not c['raw_hex'].startswith('14'): return 'named by opcode 0x%s command at %d' % (c['raw_hex'][:2], c['archive_offset'])
        return None

    def sound_groups_of(r):
        groups = []
        for o in own.get(r, []):
            for c in streams[o['stream']].get(o['group'], []):
                b = bytes.fromhex(c['raw_hex'])
                if b[0] == 0x14 and len(b) >= 10:
                    groups.append(dict(group=o['group'], command_offset=c['archive_offset'], target_kind=b[1],
                                       target=int.from_bytes(b[2:4], 'little'), sound=int.from_bytes(b[4:6], 'little'),
                                       volume=b[6], flags=b[7], inner=b[8] << 4, outer=(b[8] + b[9]) << 4,
                                       names_owner=b[1] == 3 and int.from_bytes(b[2:4], 'little') == r))
        return groups

    jungle_props_kept = {r for r in exported if r not in own and r not in targeted} if area_id == 'L4_HJ' else set()
    unplaced = sorted(r for r in exported if r not in PLACED[area_id] and r not in jungle_props_kept)
    rows, left_out, not_hosted, sound_groups, art = {}, [], [], {}, {}
    frames_dir = root / 'props'

    def frames_of(material):
        if material in art: return art[material]
        sources = report['animations'][material]['frames'] if material in report['animations'] else [report['materials'][material]]
        names_out = []
        for i, f in enumerate(sources):
            name = f'{area_id}_{material}_{i}.png'
            shutil.copyfile(frames_dir / f, out / name); names_out.append(name)
        art[material] = names_out
        return names_out

    for r in unplaced:
        q = exported[r]
        reason = ambient_reason(r)
        if reason is not None:
            left_out.append(dict(record=r, template=q['template'], name=names[q['template']], reason=reason)); continue
        require(q['selector'] == 0, f'record {r} starts on selector {q["selector"]}')
        first = report['animations'][q['material']]['frames'][0] if q['material'] in report['animations'] else report['materials'][q['material']]
        if opaque_pixels(frames_dir / first) == 0:
            not_hosted.append(dict(record=r, template=q['template'], name=names[q['template']], descriptor=int(q['material'].split('_')[1]),
                                   reason='first frame has no opaque pixel: nothing to draw')); continue
        if q['region'] is None:
            not_hosted.append(dict(record=r, template=q['template'], name=names[q['template']], position=q['position'],
                                   reason='region word 65535 (unbound) and record height %d, outside the map: the native draw of a '
                                          'null-region placement is not traced' % q['position'][1])); continue
        groups = sound_groups_of(r)
        if groups: sound_groups[str(r)] = groups
        rows[str(r)] = dict(template=q['template'], name=names[q['template']], position=q['position'], region=q['region'],
                            material=q['material'], frames=frames_of(q['material']), left=q['left'], right=q['right'],
                            bottom=q['bottom'], top=q['top'], frame_flags=q['frame_flags'], placement_offset=q['placement_offset'],
                            sound_group=bool(groups))
    require(len(rows) == EXPECTED_ROWS[area_id], f'{area_id} row count changed: {len(rows)}')
    require(all(any(g['names_owner'] for g in gs) for gs in sound_groups.values()), 'sound-only group that names another object')

    # Batches for the host: one MultiMesh per material, box and flip pair.
    batches = {}
    for r in sorted(rows, key=int):
        row = rows[r]
        key = (row['material'], row['left'], row['right'], row['bottom'], row['top'], row['frame_flags'] & 0xC0)
        batches.setdefault(key, []).append([row['position'][0], row['position'][1], row['position'][2], int(r)])
    groups_out = [dict(material=k[0], left=k[1], right=k[2], bottom=k[3], top=k[4], flip=k[5], instances=v)
                  for k, v in sorted(batches.items())]
    return dict(name=spec['name'], source=dict(archive=spec['archive'], archive_sha256=spec['sha'], geometry_key=spec['geometry_key'],
                                               metadata_key=spec['metadata_key'], texture_key=report['identity']['texture_entry']['key']),
                exported_visual=len(exported), exported_nonvisual=len(nonvisual), placed_elsewhere={str(k): v for k, v in sorted(PLACED[area_id].items())},
                jungle_props_instances=len(jungle_props_kept), unplaced=len(unplaced), rows=rows, groups=groups_out, art=art,
                left_out=left_out, not_hosted=not_hosted, sound_groups=sound_groups,
                summary=dict(rows=len(rows), groups=len(groups_out), left_out_scripted=len(left_out), not_hosted=len(not_hosted),
                             sound_only_owners=len(sound_groups)))


def prepare(game, output):
    require(not output.exists(), 'Output must be a fresh directory')
    require(output != game and output not in game.parents and game not in output.parents, 'Output overlaps the game root')
    with tempfile.TemporaryDirectory(prefix='hive-jungle-scenery-') as scratch:
        scratch = Path(scratch)
        out = scratch / 'pack'; out.mkdir()
        areas = {a: prepare_area(a, game, scratch, out) for a in AREAS}
        files = {p.name: sha(p.read_bytes()) for p in sorted(out.iterdir())}
        contract = dict(version=1, areas=areas, frame_seconds=None, files=files, adapters=ADAPTERS,
                        evidence=['G58_hive_jungle_props', 'G71_hive_jungle_props_ready'],
                        scope='Ambient Hive and Jungle scenery props the port did not draw: native placement, selector-0 box and art, '
                              'first frame only; no collision (blocking UNKNOWN), nothing saved; sound-only owner groups decoded, not hosted.')
        target = output / 'assets/lol2/generated/hive_jungle_scenery'; target.parent.mkdir(parents=True)
        shutil.copytree(out, target)
        (output / 'scripts/lol2').mkdir(parents=True)
        (output / 'scripts/lol2/hive_jungle_scenery_source.json').write_text(json.dumps(contract, indent=1, sort_keys=True) + '\n')
    return {a: areas[a]['summary'] for a in areas} | dict(files=len(files))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--output-root', type=Path, required=True)
    a = p.parse_args()
    try:
        print(json.dumps(prepare(a.game.resolve(), a.output_root.resolve())))
    except (ValueError, OSError, KeyError, StopIteration) as error:
        p.error(str(error))


if __name__ == '__main__':
    main()
