#!/usr/bin/env python3
"""Pin the Huline village gate-leaf hit consumers (L4_HJ movables 78/79) and stage their original effects.

Source facts (read-only; AI_COMMS/grok_act1_mechanics_20261025/VILLAGE_ESCAPE_CONTRACT.md; Codex
gate_movable_binding.json and gate_level_binding.json in AI_COMMS/codex_act1_review_20261025):
- Leaf78 kind9 value2048 group28068 and leaf79 group28140, predicate196 (local39 Killed_Confidante==1 AND shared29
  GV_HULINE_ALERT==1). Record: mask0 0x0800, mask1 0, threshold1, mode4 (AE2C8: mask0 must meet hit-context word0;
  mode4 AE3BA admits when context +0x26 (after-durability) <= threshold). Jungle is level index4, so the [0x23331]==5
  special branch is not taken. Placement byte30 (durability) is 5 for both leaves.
- Accepted group: sound452 at control81, op9 property3 (link) control81 (leaf78) or control80 (leaf79), op9 property2
  (unlink) on the leaf.
- Controls 80/81: template74, one type0 child box (bounds -40..40 x -84..83, height 0..2; materials 514/742): the fallen
  leaf, absent at load (bit 0x1000).
- Regions 588/3895/3896/3897 (no predicate) unlink controls 80/81 and relink both leaves.
Usage: prepare_jungle_gate_leaves.py --game G --output SOURCE_JSON [--media-root FRESH_DIR]
"""
import argparse, json, struct, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from prepare_jungle_followup_gate_media import model, require, sha, ARCHIVE, GEOMETRY, TEXTURE
from build_game_atlas import parse_mix, section, u32
from audit_game_transition_owners import collect_owners
from audit_game_actor_scripts import groups
from lol2_rotation_table import rotation_table
from export_map_movables import _box_faces, _QUAD_UV, _QUAD_UV_FACE3

LEAVES = {78: dict(group=28068, control=81, commands=['14105100c401fa000a14', '091051000300', '09204e000200']),
          79: dict(group=28140, control=80, commands=['14105100c40180000a14', '091050000300', '09204f000200'])}
RELINK = {588: 738, 3895: 8242, 3896: 8334, 3897: 8426}
RELINK_COMMANDS = ['091050000200', '091051000200', '09204f000300', '09204e000300']
SOUND = 452


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--game', type=Path, required=True); p.add_argument('--output', type=Path, required=True); p.add_argument('--media-root', type=Path)
    a = p.parse_args(); game = a.game.resolve()
    arc = (game / 'DAT/L4_HJ.MIX').read_bytes(); require(sha(arc) == ARCHIVE, 'Unsupported Jungle archive')
    entries = {e['key']: e for e in parse_mix(arc)}
    ge, me = entries[3710797084], entries[3710142494]
    raw, meta = [arc[e['offset']:e['offset'] + e['size']] for e in (ge, me)]
    require(sha(raw) == GEOMETRY, 'Geometry differs')
    owners, _ = collect_owners(raw, ge['offset'], u32(raw, 0x58))
    table = section(raw, 0xbc, 0xb8, 5)[2]
    streams = [dict(groups(section(raw, of, sf, 1)[2])) for of, sf in [(0x3c, 0x84), (0x44, 0x8c)]]
    def cmds(o): return [b.hex() for _, b in streams[o['stream']][o['group']]]
    def rec(o): return arc[o['archive_offset']:o['archive_offset'] + arc[o['archive_offset']]]
    # Predicate196 = (local39==1) AND (shared29==1): leaves 195 and 85.
    for index, want in {196: '0604c30455', 195: '0003270001', 85: '00021d0001'}.items():
        require(table[index * 5:index * 5 + 5].hex() == want, f'Predicate {index} differs')
    leaves = {}
    for leaf, spec in LEAVES.items():
        rows = [o for o in owners if o['owner_kind'] == 'movable' and o['owner'] == leaf and o['event'] == 9]
        require(len(rows) == 1, f'Leaf {leaf} hit records differ')
        o = rows[0]; r = rec(o)
        require(o['group'] == spec['group'] and o['predicate'] == 196 and o['value'] == 2048 and cmds(o) == spec['commands'], f'Leaf {leaf} group differs')
        mask0, mask1 = struct.unpack_from('<HH', r, 4)
        require((mask0, mask1, r[8], r[9]) == (0x0800, 0, 1, 4), f'Leaf {leaf} hit shape differs')
        d = raw[u32(raw, 0x24) + leaf * 41:][:41]
        require(d[30] == 5, f'Leaf {leaf} durability differs')
        leaves[str(leaf)] = dict(group=o['group'], archive_offset=o['archive_offset'], record=r.hex(), mask0=mask0, mask1=mask1, threshold=r[8], mode=r[9] & 7,
                                 one_shot=bool(r[9] & 0x80), predicate=196, durability=d[30], placement_hex=d.hex(), control=spec['control'], commands=cmds(o))
    from lol2_geometry_format import slope_corners
    vertices = list(struct.iter_unpack('<ii', section(raw, 4, 0x50, 8)[2]))
    records = list(struct.iter_unpack('<22H', section(raw, 12, 0x58, 44)[2]))
    relink = {}
    for region, group in RELINK.items():
        rows = [o for o in owners if o['owner_kind'] == 'region' and o['owner'] == region and o['group'] == group]
        require(len(rows) == 1 and rows[0]['predicate'] is None and rows[0]['event'] == 2 and cmds(rows[0]) == RELINK_COMMANDS, f'Relink region {region} differs')
        relink[str(region)] = dict(group=group, commands=RELINK_COMMANDS, polygon=[[vertices[v][0] / 65536, -vertices[v][1] / 65536] for v in records[region][6:10]], floor=slope_corners(records, region))
    # Every other script command naming leaves 78/79 or controls 80/81 is an alarm/gate command owned elsewhere.
    named = set()
    for o in owners:
        for c in cmds(o):
            b = bytes.fromhex(c)
            if len(b) >= 4 and ((b[1] == 0x20 and int.from_bytes(b[2:4], 'little') in (78, 79)) or (b[1] == 0x10 and int.from_bytes(b[2:4], 'little') in (80, 81))):
                named.add((o['owner_kind'], o['owner'], o['group']))
    hosted = {('movable', 78, 28068), ('movable', 79, 28140)} | {('region', r, g) for r, g in RELINK.items()}
    others = sorted(named - hosted)
    # Controls 80/81: placement, template74 child box faces in world space.
    trig = struct.unpack('<4096i', rotation_table(game))
    to, nt = u32(meta, 12), u32(meta, 0x44); co = to + nt * 60 + 4
    controls = {}; resources = set()
    _, _, ctl_blob = section(raw, 0x18, 0x64, 33)
    for c in (80, 81):
        row = ctl_blob[c * 33:(c + 1) * 33]; x, y, heading, height = struct.unpack_from('<hhHh', row); flags = struct.unpack_from('<H', row, 8)[0]
        require(row[32] == 74 and flags & 0x1000, f'Control {c} placement differs')
        template = meta[to + 74 * 60:to + 75 * 60]; first = sum(meta[to + i * 60 + 50] for i in range(74))
        require(template[50] == 1 and list(template[47:50]) == [80, 167, 2], 'Template74 differs')
        child = meta[co + first * 60:co + (first + 1) * 60]; require(child[59] == 0, 'Unsupported control child')
        bounds = struct.unpack_from('<4b2B', child, 52); require(list(bounds) == [-40, 40, -84, 83, 0, 2], 'Control child bounds differ')
        faces = []
        for face, points in enumerate(_box_faces(bounds)):
            resource = struct.unpack_from('<h', child, face * 8)[0]
            if resource == 0: continue
            require(resource in (514, 742), 'Control material differs'); resources.add(resource)
            world = []
            for lx, lz, ly in points:
                wx, wy = model((lx << 16, ly << 16), (x << 16, y << 16), heading, trig)
                world.append([wx / 65536, lz + height, -wy / 65536])
            faces.append(dict(vertices=world, uv=[list(v) for v in (_QUAD_UV_FACE3 if face == 3 else _QUAD_UV)], material=f'material_{resource:04d}.png'))
        controls[str(c)] = dict(position=[x, height, -y], heading=heading, flags=flags, template=74, bounds=list(bounds), placement_hex=row.hex(), faces=faces)
    from prepare_creature_audio_clips import sound_bank
    bank = sound_bank(game); rcount, rtable = struct.unpack_from('<II', bank, 0x258)
    sound_name = bank[rtable + SOUND * 60 + 16:rtable + (SOUND + 1) * 60].split(b'\0')[0].decode()
    result = dict(version=1, source=dict(file='DAT/L4_HJ.MIX', sha256=ARCHIVE, geometry_sha256=GEOMETRY, texture_sha256=TEXTURE),
                  level_index=4, predicate=dict(index=196, expression='(local39 == 1) AND (shared29 == 1)', raw={'196': '0604c30455', '195': '0003270001', '85': '00021d0001'}),
                  leaves=leaves, controls=controls, relink=relink, sound=dict(request=SOUND, name=sound_name, object=81),
                  other_named=[dict(owner_kind=k, owner=o, group=g) for k, o, g in others],
                  scope='Consumer of an explicitly supplied hit context (mask0, before/after durability). The producer of the 0x0800 context is not traced; '
                        'the live owner supplies it only through the owner-approved modern "Force gate" action (2026-10-25).')
    a.output.parent.mkdir(parents=True, exist_ok=True); a.output.write_text(json.dumps(result, indent=1) + '\n')
    print(f'PASS gate leaves contract: leaves 78/79 durability5 mask0x0800 mode4, controls 80/81 {sum(len(v["faces"]) for v in controls.values())} faces, relink {sorted(relink)}, sound {SOUND} {sound_name}, other named groups {len(others)}')
    if a.media_root:
        media = a.media_root.resolve(); require(not media.exists(), 'Use a fresh media root')
        sys.path.insert(0, str(ROOT / 'tools/lol2'))
        import map_materials
        from prepare_creature_audio_clips import stage_clips
        out = media / 'assets/lol2/generated/jungle_gate_leaves'; out.mkdir(parents=True)
        with tempfile.TemporaryDirectory(prefix='jungle-gate-leaves-') as temp:
            fresh = Path(temp) / 'materials'; map_materials.export_materials(game, 'L4_HJ', fresh)
            require(sha((fresh / 'texture.bin').read_bytes()) == TEXTURE, 'Texture differs')
            for k in sorted(resources): (out / f'material_{k:04d}.png').write_bytes((fresh / f'material_{k:04d}/mip_0_palette.png').read_bytes())
        stage_clips(media, 'jungle_gate_leaves/sounds', [SOUND], {SOUND: sound_name}, game=game)
        print('media', sorted(p.name for p in out.rglob('*') if p.is_file()))


if __name__ == '__main__':
    main()
