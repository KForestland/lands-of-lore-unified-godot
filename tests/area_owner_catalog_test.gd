extends SceneTree
# affected: dependency res://scripts/lol2/area_owners/
const Registry = preload("res://scripts/lol2/area_owner_registry.gd")
func _initialize() -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_d5da60a/manifest.json"))
	var merged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_415ca7b.json"))
	var pilot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_generic_l10.json"))
	var actions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_generic_l13.json"))
	var guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_generic_l19.json"))
	var fountain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_g15_fountain.json"))
	var modern:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_owner_gaps_20261114.json"))
	var rollout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_g03.json"))
	var count := 0
	for area in Registry.AREAS:
		var registry := Registry.new()
		assert(registry.prepare(area).is_empty(), area + " duplicate keys/missing scripts")
		var rows: Array = Registry.definition_for(area).get_script_constant_map().OWNERS
		var expected: Array = golden.declarations[area].duplicate(true)
		if area == merged.area:
			# This legacy capture already contains OF6. Do not add it twice.
			var present := expected.filter(func(row): return row.script == merged.declaration.script)
			assert(present.size() <= 1, area + " duplicate OF6 fixture declaration")
			if present.is_empty(): expected.insert(int(merged.index), merged.declaration)
			else: assert(present[0] == merged.declaration, area + " existing OF6 fixture differs")
		if area == pilot.area:
			var replaced := 0
			for i in expected.size():
				if expected[i].script == pilot.replace_script:
					expected[i] = pilot.declaration
					replaced += 1
			assert(replaced == 1, area + " replaces exactly one OF6 owner with GenericObjects")
		if area == actions.area: expected.append(actions.declaration)
		if area == guide.area: expected.append(guide.declaration)
		if area == fountain.area: expected.insert(int(fountain.index),fountain.declaration)
		for row:Dictionary in modern.rows:
			if row.area==area:expected.insert(int(row.index),row.declaration)
		for row in rollout.declarations.get(area,[]):
			if area in rollout.get("append_areas",[]):expected.append(row)
			else:expected.push_front(row)
		assert(rows.size() == expected.size(), area)
		for i in rows.size():
			for key in ["script", "attach", "args", "needs", "factory"]:
				assert(rows[i].get(key, "attach" if key == "attach" else null) == expected[i].get(key, "attach" if key == "attach" else null), area + " " + key + " " + str(i))
			if rows[i].script=="generic_object_world.gd" and area!="L10_DC":
				for key in ["static","collision"]:assert(rows[i].get(key)==expected[i].get(key),area+" G03 ownership "+key)
			assert(rows[i].get("phase", "late") == ("early" if expected[i].get("phase") == "early" else "late"), area + " phase")
		count += rows.size()
		registry.free()
	# 124 since 2026-11-17: + the r19o10 L12 river bank and r19o12 L19 lab ledge owners (owner_gaps rows).
	assert(count == 124+rollout.declarations.values().reduce(func(total,rows):return total+rows.size(),0))
	print("PASS area catalog:",count," independent legacy/integration/modern fixtures plus explicit G03 registrations; explicit G03 static/collision ownership, no duplicate keys")
	quit()
