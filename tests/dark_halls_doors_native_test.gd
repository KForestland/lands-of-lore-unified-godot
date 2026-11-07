extends SceneTree
## Headless checks of the Dark Halls door binding to the native script host (dark_halls_doors.gd): E-use fires kind 4
## (context = the door, arg_c = 0), the leaf follows the travel word (21845 -> about 120 degrees), the doors' native
## fields survive a JSON save, an older save without them maps open -> +0x25 1 + full word, and door 57's trap/unlock
## adapters keep working. A minimal stand-in host replaces the Dark Halls scene (no rendering).
const Doors := preload("res://scripts/lol2/dark_halls_doors.gd")
const HOST_SOURCE := "extends Node3D\nconst TINT := Color(0.55, 0.47, 0.40)\nvar geometry_file := \"res://assets/lol2/generated/dark_halls/area.json\"\nvar quest_state := {}\nvar player: CharacterBody3D\nvar camera: Camera3D\nvar ready_for_review := false\nvar flying := false\n"

var failed := false


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func field(doors: Node, id: String, name: String) -> int:
	return int((doors.get("native") as RefCounted).call("field", "movable:" + id, name, -1))


func swing(doors: Node, frames: int) -> void:
	for i in frames:
		doors.call("_physics_process", 1.0 / 60.0)


func leaf_degrees(doors: Node, id: String) -> float:
	var leaves: Dictionary = doors.get("leaves")
	return absf(rad_to_deg(((leaves[id] as Dictionary)["hinge"] as Node3D).rotation.y))


func make_host() -> Node3D:
	var script := GDScript.new()
	script.source_code = HOST_SOURCE
	script.reload()
	var host := Node3D.new()
	host.set_script(script)
	var player := CharacterBody3D.new()
	var camera := Camera3D.new()
	host.add_child(player)
	host.add_child(camera)
	host.set("player", player)
	host.set("camera", camera)
	root.add_child(host)
	return host


func _initialize() -> void:
	var host: Node3D = make_host()
	var doors: Node = Doors.new()
	host.add_child(doors)
	var error: String = str(doors.call("setup", host))
	check(error == "", "setup: " + error)
	check((doors.get("leaves") as Dictionary).size() == 2 and doors.get("native") != null, "both doors and the native host")
	check(field(doors, "57", "byte_0x25") == 0 and field(doors, "57", "travel_0x50") == -1 and field(doors, "57", "byte_0x26") == 50, "door 57 native constructor state %d %d %d" % [field(doors, "57", "byte_0x25"), field(doors, "57", "travel_0x50"), field(doors, "57", "byte_0x26")])
	host.set("ready_for_review", true)
	var src: Dictionary = doors.get("source")

	# E-use: kind 4 -> predicate 206 -> group 13702 (opcode 1 percent 100, +0x25 = 1).
	check(bool(doors.call("use", "57")) and bool(doors.call("is_open", "57")), "use did not open door 57")
	check(field(doors, "57", "travel_0x50") == 21845 and field(doors, "57", "byte_0x25") == 1, "door 57 native fields after open")
	swing(doors, 30)
	check(leaf_degrees(doors, "57") > 50.0 and leaf_degrees(doors, "57") < 70.0, "half a second swings about 60 degrees, got %.2f" % leaf_degrees(doors, "57"))
	swing(doors, 40)
	check(absf(leaf_degrees(doors, "57") - 21845.0 * 360.0 / 65536.0) < 0.01, "door 57 leaf at %.3f, expected 119.998" % leaf_degrees(doors, "57"))
	var quests: Dictionary = host.get("quest_state")
	check(str(Doors.validate(quests.dark_halls_doors, src)) == "", "saved doors with native fields must validate")

	# JSON round trip and restore.
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(quests)) as Dictionary
	check(str(Doors.validate(reloaded.dark_halls_doors, src)) == "", "reloaded doors must validate")
	host.set("quest_state", reloaded)
	doors.call("restore_from_quests")
	check(field(doors, "57", "travel_0x50") == 21845 and field(doors, "57", "byte_0x25") == 1 and absf(leaf_degrees(doors, "57") - 119.998) < 0.01, "restore lost door 57")
	# Second use: predicate 207 -> group 13720 closes it (+0x25 = 0).
	doors.call("use", "57")
	check(not bool(doors.call("is_open", "57")) and field(doors, "57", "travel_0x50") == 0 and field(doors, "57", "byte_0x25") == 0, "second use must close door 57")
	swing(doors, 70)
	check(leaf_degrees(doors, "57") < 0.01, "door 57 leaf did not close")

	# An older save without native fields: open -> +0x25 1 and the full word.
	host.set("quest_state", {"dark_halls_doors": {"56": {"open": true, "locked": false}, "57": {"open": false, "locked": false}, "trap": false}})
	check(str(Doors.validate((host.get("quest_state") as Dictionary).dark_halls_doors, src)) == "", "old save must validate")
	doors.call("restore_from_quests")
	check(field(doors, "56", "byte_0x25") == 1 and field(doors, "56", "travel_0x50") == 21845 and absf(leaf_degrees(doors, "56") - 119.998) < 0.01, "old open save must map to +0x25 1 and 21845")
	check(field(doors, "57", "byte_0x25") == 0 and field(doors, "57", "travel_0x50") == -1 and leaf_degrees(doors, "57") < 0.01, "old shut save must be the constructor state (travel word not stated)")
	doors.call("use", "56")
	check(field(doors, "56", "travel_0x50") == 0 and field(doors, "56", "byte_0x25") == 0, "old-save door 56 must close on use")

	# Door 57 trap: closes and locks; E on the locked door changes nothing; SHADE 73's end runs group 15750.
	doors.call("use", "57")
	check(field(doors, "57", "travel_0x50") == 21845, "door 57 open before the trap")
	check(bool(doors.call("spring_trap")) and bool(doors.call("is_locked", "57")) and field(doors, "57", "travel_0x50") == 0, "trap must close and lock door 57")
	doors.call("use", "57")
	check(field(doors, "57", "travel_0x50") == 0 and field(doors, "57", "byte_0x25") == 1, "a locked use must not fire kind 4")
	doors.call("_check_unlock")
	check(not bool(doors.call("is_locked", "57")) and field(doors, "57", "byte_0x25") == 0, "SHADE end must unlock and run group 15750 (+0x25 = 0)")
	doors.call("use", "57")
	check(bool(doors.call("is_open", "57")) and field(doors, "57", "travel_0x50") == 21845, "door 57 must open after the unlock")
	check(str(Doors.validate((host.get("quest_state") as Dictionary).dark_halls_doors, src)) == "", "trap state must validate")
	check((doors.get("sound_log") as Array).is_empty(), "the door 57 open/close groups have no sound request")

	# A malformed native save is refused.
	var bad: Dictionary = ((host.get("quest_state") as Dictionary).dark_halls_doors as Dictionary).duplicate(true)
	(bad.native["movable:57"] as Dictionary)["travel_0x50"] = 1.5
	check(str(Doors.validate(bad, src)) != "", "fractional native field must be refused")
	if not failed:
		print("PASS dark_halls_doors_native_test: kind-4 use through the native host, travel word 21845 -> 119.998 degrees at the earlier speed, JSON save/restore, old-save mapping, trap lock and SHADE unlock group 15750")
	host.queue_free()
	quit(1 if failed else 0)
