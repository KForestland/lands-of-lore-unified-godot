extends Node3D
## STORY-092 and STORY-093 (HINTBOOK 5557-5576). Actor 75 is the only def-byte-2
## BELIAL. No horn, blue-bow, or Dark Sword opcode 3 is stored on L20.
## The three book weapons set the same flag. The chasm stays -1. No slump is stored.
## Actor 46 is the only DRARACLE row. L20 has no Dawn actor. No movie is played.
## No command was copied for what follows the last scene.
const KEY := "l20_finale"
const BELIAL := 75
const DRARACLE := 46
const WEAPONS := ["act2:L12_CM:blue_bow", "act2:L13_RC:dark_sword", "act2:L19_BC:horn"]
const CHASM := -1
const VOW := ""
const SCENE_NAME := ""
const DAWN_ON_L20 := false
const AT_75 := Vector3(-1238, -10, -3207)
const AT_46 := Vector3(-6921, -50, -4828)
const REACH := 20.0
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "started": false, "weapon": "", "chasm": -1, "slumped": false, "draracle_seen": false, "appeared": false, "vanished": false, "dawn_here": false}

static func same_weapon(id: String) -> bool:
	return id in WEAPONS

static func plays_movie() -> bool:
	return false

static func after_movie() -> bool:
	return false

static func moves_player() -> bool:
	return false

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 9: return "Invalid finale state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid finale state."
	if not (s.get("started") is bool) or not (s.get("slumped") is bool): return "Invalid finale state."
	if not (s.get("draracle_seen") is bool) or not (s.get("appeared") is bool) or not (s.get("vanished") is bool) or not (s.get("dawn_here") is bool): return "Invalid finale state."
	if s.get("slumped") != false or s.get("appeared") != false or s.get("vanished") != false or s.get("dawn_here") != false: return "Invalid finale state."
	var chasm: Variant = s.get("chasm")
	if not (chasm is int or chasm is float) or int(chasm) != -1: return "Invalid finale state."
	var weapon: Variant = s.get("weapon")
	if not weapon is String: return "Invalid finale state."
	var started: bool = bool(s.get("started"))
	if started and not same_weapon(str(weapon)): return "Invalid finale state."
	if not started and str(weapon) != "": return "Invalid finale state."
	if bool(s.get("draracle_seen")) and not started: return "Invalid finale state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l20_finale.gd").new()
	n.host = map
	n.name = "L20Finale"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var started: bool = bool(raw.get("started", false))
	var weapon: String = str(raw.get("weapon", "")) if started else ""
	if started and not same_weapon(weapon):
		started = false
		weapon = ""
	return {"version": int(raw.get("version", 1)), "started": started, "weapon": weapon, "chasm": -1, "slumped": false, "draracle_seen": bool(raw.get("draracle_seen", false)) and started, "appeared": false, "vanished": false, "dawn_here": false}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 580)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_75) < REACH and not bool(state().started):
		hint.text = "E — the blue bow, the Dark Sword, and the horn start the same flag."
	elif flat_to(AT_46) < REACH and bool(state().started):
		hint.text = "E — actor 46. No movie plays. Dawn stays off L20."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_75) < REACH:
		var id: String = str(host.equipped_item)
		if not same_weapon(id): return
		var s: Dictionary = state()
		if bool(s.started): return
		s.started = true
		s.weapon = id
		s.chasm = -1
		s.slumped = false
		host.quest_state[KEY] = s
		get_viewport().set_input_as_handled()
		return
	if flat_to(AT_46) < REACH and bool(state().started):
		var end: Dictionary = state()
		end.draracle_seen = true
		end.appeared = false
		end.vanished = false
		end.dawn_here = false
		end.chasm = -1
		host.quest_state[KEY] = end
		get_viewport().set_input_as_handled()
