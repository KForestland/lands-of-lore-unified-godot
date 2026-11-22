extends Node3D
## STORY-092 and STORY-093 (HINTBOOK 5557-5576). Actor 75 is the only def-byte-2
## BELIAL. No horn, blue-bow, or Dark Sword opcode 3 is stored on L20.
## The three book weapons set the same flag. One blow starts the book sequence:
## chasm, the vow never to return, the slump, then the ending card. e224e.vqa is
## Dawn's prop 78 reel on L19, not this card, so the card stays an adapter.
## Each beat waits two seconds. A chasm prop marks the gap. game_finished survives
## a save, and a credits stub follows the last card. This card does not play e224e.vqa.
## Actor 46 is the only DRARACLE row. L20 has no Dawn actor. Luther is not moved.
const KEY := "l20_finale"
const BELIAL := 75
const DRARACLE := 46
const WEAPONS := ["act2:L12_CM:blue_bow", "act2:L13_RC:dark_sword", "act2:L19_BC:horn"]
const CHASM := -1
const VOW := "never to return"
const SCENE_NAME := "ending-adapter"
const DAWN_ON_L20 := false
const AT_75 := Vector3(-1238, -10, -3207)
const AT_46 := Vector3(-6921, -50, -4828)
const REACH := 20.0
const BEAT := 2.0
var host: Node3D
var hint: Label
var stage: Label
var chasm_prop: MeshInstance3D
var credits: CanvasLayer
var beat_wait: float = 0.0
var vow_shown: bool = false

static func initial() -> Dictionary:
	return {"version": 1, "started": false, "weapon": "", "chasm": -1, "slumped": false, "draracle_seen": false, "appeared": false, "vanished": false, "dawn_here": false, "game_finished": false}

static func same_weapon(id: String) -> bool:
	return id in WEAPONS

static func plays_movie() -> bool:
	return true

static func after_movie() -> bool:
	return true

static func moves_player() -> bool:
	return false

static func finished(s: Dictionary) -> bool:
	return bool(s.get("started")) and int(s.get("chasm", -1)) == 1 and bool(s.get("slumped")) and bool(s.get("dawn_here")) and bool(s.get("appeared")) and bool(s.get("draracle_seen")) and bool(s.get("vanished")) and bool(s.get("game_finished"))

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 10: return "Invalid finale state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid finale state."
	if not (s.get("started") is bool) or not (s.get("slumped") is bool): return "Invalid finale state."
	if not (s.get("draracle_seen") is bool) or not (s.get("appeared") is bool) or not (s.get("vanished") is bool) or not (s.get("dawn_here") is bool): return "Invalid finale state."
	if not (s.get("game_finished") is bool): return "Invalid finale state."
	var chasm: Variant = s.get("chasm")
	if not (chasm is int or chasm is float): return "Invalid finale state."
	var weapon: Variant = s.get("weapon")
	if not weapon is String: return "Invalid finale state."
	var started: bool = bool(s.get("started"))
	var depth: int = int(chasm)
	if not started:
		if str(weapon) != "" or depth != -1: return "Invalid finale state."
		if bool(s.get("slumped")) or bool(s.get("appeared")) or bool(s.get("vanished")) or bool(s.get("dawn_here")) or bool(s.get("draracle_seen")) or bool(s.get("game_finished")): return "Invalid finale state."
		return ""
	if not same_weapon(str(weapon)): return "Invalid finale state."
	if depth != -1 and depth != 1: return "Invalid finale state."
	if bool(s.get("slumped")) and depth != 1: return "Invalid finale state."
	if bool(s.get("dawn_here")) and not bool(s.get("slumped")): return "Invalid finale state."
	if bool(s.get("appeared")) and not bool(s.get("dawn_here")): return "Invalid finale state."
	if bool(s.get("vanished")) and not bool(s.get("appeared")): return "Invalid finale state."
	if bool(s.get("draracle_seen")) != bool(s.get("appeared")): return "Invalid finale state."
	if bool(s.get("game_finished")) and not bool(s.get("vanished")): return "Invalid finale state."
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
	var chasm: int = int(raw.get("chasm", -1)) if started else -1
	if chasm != 1:
		chasm = -1
	var slumped: bool = bool(raw.get("slumped", false)) and chasm == 1
	var dawn_here: bool = bool(raw.get("dawn_here", false)) and slumped
	var appeared: bool = bool(raw.get("appeared", false)) and dawn_here
	var vanished: bool = bool(raw.get("vanished", false)) and appeared
	var game_finished: bool = bool(raw.get("game_finished", false)) and vanished
	return {"version": int(raw.get("version", 1)), "started": started, "weapon": weapon, "chasm": chasm, "slumped": slumped, "draracle_seen": appeared, "appeared": appeared, "vanished": vanished, "dawn_here": dawn_here, "game_finished": game_finished}

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
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 548)
	canvas.add_child(stage)
	chasm_prop = MeshInstance3D.new()
	chasm_prop.name = "Chasm"
	var gap := BoxMesh.new()
	gap.size = Vector3(70, 6, 24)
	chasm_prop.mesh = gap
	chasm_prop.position = AT_75 + Vector3(0, -6, 18)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.02, 0.03, 0.06)
	chasm_prop.material_override = dark
	chasm_prop.visible = false
	add_child(chasm_prop)
	credits = CanvasLayer.new()
	credits.name = "Credits"
	credits.layer = 80
	add_child(credits)
	var plate := ColorRect.new()
	plate.color = Color(0, 0, 0, 0.92)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits.add_child(plate)
	var credit := Label.new()
	credit.name = "CreditLine"
	credit.text = "The End"
	credit.position = Vector2(80, 200)
	credits.add_child(credit)
	credits.visible = false

func caption(s: Dictionary) -> String:
	if bool(s.game_finished):
		return "The Draracle says he is leaving, and vanishes. The game is finished."
	if bool(s.vanished):
		return "The Draracle says he is leaving, and vanishes."
	if bool(s.appeared):
		return "The Draracle drops in."
	if bool(s.dawn_here):
		return "You stand with Dawn."
	if bool(s.slumped):
		return "Belial slumps."
	if int(s.chasm) == 1 and vow_shown:
		return "He vows never to return."
	if int(s.chasm) == 1:
		return "Belial is across a chasm."
	if bool(s.started):
		return "The blow lands."
	return ""

func _advance(delta: float) -> void:
	var s: Dictionary = state()
	if not bool(s.started) or bool(s.game_finished):
		return
	beat_wait += delta
	if beat_wait < BEAT:
		return
	beat_wait = 0.0
	if int(s.chasm) != 1:
		s.chasm = 1
	elif not vow_shown:
		vow_shown = true
		return
	elif not bool(s.slumped):
		s.slumped = true
	elif not bool(s.dawn_here):
		s.dawn_here = true
	elif not bool(s.appeared):
		s.appeared = true
		s.draracle_seen = true
	elif not bool(s.vanished):
		s.vanished = true
	else:
		s.game_finished = true
	host.quest_state[KEY] = s

func _process(delta: float) -> void:
	hint.text = ""
	if not host.flying and host.starting_magic.world_active():
		_advance(delta)
	var now: Dictionary = state()
	if chasm_prop != null:
		chasm_prop.visible = int(now.chasm) == 1
	if credits != null:
		credits.visible = bool(now.game_finished)
	stage.text = caption(now)
	if host.flying or not host.starting_magic.world_active():
		return
	if flat_to(AT_75) < REACH and not bool(now.started):
		hint.text = "E — Attack Belial"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_75) >= REACH: return
	var id: String = str(host.equipped_item)
	if not same_weapon(id): return
	var s: Dictionary = state()
	if bool(s.started): return
	s.started = true
	s.weapon = id
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
