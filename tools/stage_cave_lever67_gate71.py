#!/usr/bin/env python3
"""Add Kenneth-room lever 67 and gate 71 to the Cave encounter movables and their L1 command groups.

Inputs (explicit, hash-pinned): the lead's fresh movable export (cave_kenneth/fresh_movables/movables.json, made by
tools/export_map_movables.py from DAT/L1_DC.MIX) and the original L1_DC.MIX (stream-1 groups 12490/12514/12556/12562
read through the same owner/group readers as the lead's diagnosis). No RE tree, no Ghidra.

Motion fields come from the 41-byte placement exactly as the native constructor copies them (A 0x63004..0x63036 and
0x6306F..0x63082: mode = byte 34, travel = byte 36, speed = byte 37, initial travel = byte 38, height = s16 @6) and the
command target arithmetic (0x63FCB: travel*percent//100; 0x63C2A: mode 0 raises, mode 1 lowers). The tool first
rebuilds the eight committed rows from their bytes and refuses unless every field matches, then adds 67 and 71.
The native replay for all ten placements is evidence beside the build report (replay10.json).

Writes scripts/lol2/cave_guard_sequence_movables.json and the four groups into cave_guard_sequence_source.json.
Run twice: the outputs are byte-identical.
"""
import argparse, hashlib, json, struct, sys
from pathlib import Path

EXPORT_SHA256 = 'd34b596475008405c7623f9b8d61c33ea9a8b35921f0995b6379e9f56786a563'
L1_SHA256 = '6384ec4d4d78f1aadfc1f154d924e1e20636af037cf5af68fe35af8478854345'
NEW = (67, 71)
GROUPS = {12490: ('movable', 67), 12514: ('movable', 67), 12556: ('movable', 71), 12562: ('movable', 71)}


def motion(index, raw_hex, archive_offset):
	raw = bytes.fromhex(raw_hex)
	assert len(raw) == 41
	mode, travel = raw[34], raw[36]
	assert mode in (0, 1)
	samples = []
	for percent in (0, 25, 50, 75, 100):
		target = travel * percent // 100
		samples.append(dict(percent=percent, target=target, vertical_delta=float(target if mode == 0 else -target)))
	return dict(index=index, archive_offset=archive_offset, raw_hex=raw_hex, template=raw[32], mode=mode,
		height=struct.unpack_from('<h', raw, 6)[0], travel=travel, speed_byte=raw[37], initial_travel=raw[38], samples=samples)


def main():
	ap = argparse.ArgumentParser(description=__doc__)
	ap.add_argument('--project', type=Path, required=True)
	ap.add_argument('--export', type=Path, required=True, help='cave_kenneth/fresh_movables/movables.json')
	ap.add_argument('--game-root', type=Path, required=True, help='folder with DAT/L1_DC.MIX')
	ap.add_argument('--inventory', type=Path, required=True, help='docs/game-source-inventory.json of the lead tree')
	a = ap.parse_args()
	sys.path.insert(0, str(a.project / 'tools'))
	from lol2_source_format import parse_mix
	from build_game_atlas import section
	from audit_game_transition_owners import collect_owners
	from audit_game_actor_scripts import groups as read_groups
	from prepare_jungle_exit_encounter import predicate

	assert hashlib.sha256(a.export.read_bytes()).hexdigest() == EXPORT_SHA256, 'export hash differs'
	export = json.loads(a.export.read_text())
	movables_path = a.project / 'scripts/lol2/cave_guard_sequence_movables.json'
	source_path = a.project / 'scripts/lol2/cave_guard_sequence_source.json'
	current = json.loads(movables_path.read_text())
	assert export['source'] == current['source'], 'export is not the committed L1_DC source'
	rows = {int(r['motion']['index']): r for r in current['movables']}
	if set(rows) == {64, 65, 66, 67, 68, 69, 70, 71, 72, 73}:
		for i in NEW: rows.pop(i)
	assert set(rows) == {64, 65, 66, 68, 69, 70, 72, 73}, sorted(rows)
	area_offset = rows[64]['motion']['archive_offset'] - 64 * 41
	for index, row in rows.items():
		assert motion(index, row['motion']['raw_hex'], row['motion']['archive_offset']) == row['motion'], f'row {index} differs'
		assert area_offset + index * 41 == row['motion']['archive_offset']
	materials = dict(current['materials']); indexed = dict(current['indexed_materials'])
	prefix = 'res://assets/lol2/generated/cave_guard_sequence/movables/'
	for index in NEW:
		placement = next(dict(p) for p in export['placements'] if p['index'] == index)
		faces = [dict(f) for f in export['faces'] if f['placement'] == index]
		assert faces and placement['placement_kind'] == 'movable'
		for face in faces:
			face['material'] = prefix + face['material']
			assert face['material'] in materials, 'material not staged: ' + face['material']
		rows[index] = dict(motion=motion(index, placement['placement_hex'], area_offset + index * 41), placement=placement, faces=faces)
	result = dict(current)
	result['movables'] = [rows[i] for i in sorted(rows)]
	result['materials'] = materials; result['indexed_materials'] = indexed
	result['scope'] = ('Fresh original ten movable geometries (levers 64-67/72, gates and doors 68-71/73), original texture assets '
		'and native-proven vertical endpoint motion. No host motion/collision/timing claim.')

	inv = json.loads(a.inventory.read_text()); area = next(r for r in inv['areas'] if r['id'] == 'L1_DC')
	mix = (a.game_root / area['source']['file']).read_bytes()
	assert hashlib.sha256(mix).hexdigest() == L1_SHA256 == area['source']['sha256']
	entry = next(e for e in parse_mix(mix) if e['key'] == area['source']['geometry_key'])
	raw = mix[entry['offset']:entry['offset'] + entry['size']]
	owners, _ = collect_owners(raw, entry['offset'], area['counts']['regions'])
	_, _, table = section(raw, 0xbc, 0xb8, 5)
	of = 0x44; _, _, blob = section(raw, of, 0x8c, 1)
	stream1 = {g: [{'archive_offset': entry['offset'] + int.from_bytes(raw[of:of + 4], 'little') + off, 'raw': b.hex()} for off, b in cmds]
		for g, cmds in read_groups(blob)}
	source = json.loads(source_path.read_text())
	for group, (kind, owner) in GROUPS.items():
		found = [o for o in owners if o['stream'] == 1 and o['group'] == group and o['owner_kind'] == kind and o['owner'] == owner]
		assert found, group
		# Lever 67's group 12490 has two owner records (kind 4 use and kind 6 value 20); keep the use record, the one the port runs.
		o = dict(sorted(found, key=lambda r: r['event'])[0])
		o['commands'] = stream1[group]
		o['predicate_expression'] = predicate(table, o['predicate']) if o['predicate'] is not None else None
		o = {k: o[k] for k in ('stream', 'group', 'owner_kind', 'owner', 'event', 'value', 'predicate', 'archive_offset', 'commands', 'predicate_expression')}
		source['groups'][str(group)] = o
	movables_path.write_text(json.dumps(result, indent=2) + '\n')
	source_path.write_text(json.dumps(source, indent=2) + '\n')
	print('PASS eight committed rows rebuilt from bytes; added movables', NEW, 'and groups', sorted(GROUPS))
	for p in (movables_path, source_path): print(hashlib.sha256(p.read_bytes()).hexdigest(), p.relative_to(a.project))


if __name__ == '__main__':
	main()
