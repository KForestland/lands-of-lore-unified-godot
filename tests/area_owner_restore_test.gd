extends SceneTree
# affected: dependency res://scripts/lol2/area_owners/
## Real catalog declarations drive spies; expected calls come from unchanged hosts.
const Registry = preload("res://scripts/lol2/area_owner_registry.gd")
const FIXTURES := "res://tests/fixtures/area_owners_d5da60a/"
class Spy extends Node:
	var calls: Array
	func restore(value: Variant = null) -> void:
		calls.append({"name": str(name), "args": [] if value == null else [value]})
func _initialize() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "legacy_restore_order.json"))
	var merged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_415ca7b.json"))
	var pilot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_generic_l10.json"))
	var actions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_generic_l13.json"))
	var guide: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_generic_l19.json"))
	# Sol c437c8d: the L16 source626 fountain owner (declaration pinned apart; child L16FountainFreeze; no restore hook).
	var fountain: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_g15_fountain.json"))
	var modern:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_owner_gaps_20261114.json"))
	var g03:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/area_owners_g03.json"))
	var load_count := 0
	var arrival_count := 0
	for area in Registry.AREAS:
		var parent := Node.new()
		var registry := Registry.new()
		parent.add_child(registry)
		assert(registry.prepare(area).is_empty())
		assert(registry.restore_all("load").is_empty(), "pre-attachment resume is a no-op")
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + area + ".json"))
		var names := {}
		for child in baseline.children: names[child.script.get_file()] = child.name
		if area == merged.area: names[merged.declaration.script] = merged.node_name
		if area == pilot.area:
			names.erase(pilot.replace_script)
			names[pilot.declaration.script] = pilot.node_name
		if area == actions.area: names[actions.declaration.script] = actions.node_name
		if area == guide.area: names[guide.declaration.script] = guide.node_name
		if area == fountain.area: names[fountain.declaration.script] = "L16FountainFreeze"
		for row:Dictionary in modern.rows:
			if row.area==area:names[row.declaration.script]=row.node_name
		if g03.declarations.has(area):names["generic_object_world.gd"]="GenericWorld" if area in g03.append_areas else "GenericObjects"
		var rows: Array = Registry.definition_for(area).get_script_constant_map().OWNERS
		var calls := []
		for i in rows.size():
			var spy := Spy.new()
			spy.name = names[rows[i].script]
			spy.calls = calls
			parent.add_child(spy)
			registry._attached[i] = spy
		var host := "darker_jungle.gd" if area == "L8_SJ" else "dragon_level.gd" if area == "L9_DR" else "act2_map.gd"
		for reason in ["load", "arrival", "other"]:
			calls.clear()
			var expected := []
			for row in legacy[host].get(reason, []):
				if row.name in names.values(): expected.append(row)
			if area == pilot.area and reason in pilot.restore_on: expected.append({"name":pilot.node_name,"args":[]})
			if area == actions.area and reason in actions.restore_on: expected.append({"name":actions.node_name,"args":[]})
			if area == guide.area and reason in guide.restore_on: expected.append({"name":guide.node_name,"args":[]})
			if g03.declarations.has(area) and reason in ["load","arrival"]:expected.append({"name":names["generic_object_world.gd"],"args":[]})
			for row:Dictionary in modern.rows:
				if row.area==area and reason in row.restore_on:expected.append({"name":row.node_name,"args":[]})
			assert(registry.restore_all(reason).is_empty())
			assert(calls == expected, area + " " + reason + " restore order/arguments: " + str(calls))
			if reason == "load": load_count += calls.size()
			if reason == "arrival": arrival_count += calls.size()
		parent.free()
	assert(load_count == 27+g03.declarations.size() and arrival_count == 11+g03.declarations.size(), "Only explicit generic and owner-approved replacement restores are added")
	print("PASS catalog restore schedules: legacy21load/7arrival unchanged plus explicit generic/replacement projections plus declared G03 owners; pre-attach/unknown no-op")
	quit()
