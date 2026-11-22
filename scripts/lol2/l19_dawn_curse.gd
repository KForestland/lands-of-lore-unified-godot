extends Node3D
const Grants=preload("res://scripts/lol2/item_grants.gd")
## STORY-086 and STORY-087 (HINTBOOK 5474-5491). Prop 78 is Dawn good, region 1461.
## Actor 39 is region 2182. No click count is stored. The second E records the curse
## sentence. The third E records the ruby offer and does not grant definition 69.
## Prop 242 is Frank's Placenta, region 262. Belial Birthed has zero placements.
## No curse command is stored. The level is the constant 5. placenta.vqa is prop 242's
## reel and is not in the movie table. Group 770's opcode 21 plays movie 65 bb_brth.
## The curse module does not place Luther. The opcode-18 consumer applies the words.
## The player does not kill the
## mother. She dies after the birth, and the creatures of this area stay gone.
## The demons are the kills. The ruby is definition 69 and lands in the pack.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY := "l19_dawn_curse"
const PROP := 78
const ACTOR := 39
const DAWN_REGION := 1461
const ACTOR_REGION := 2182
const MOTHER := 242
const MOTHER_REGION := 262
const RUBY_DEFINITION := 69
const RUBY_IDENTITY := 4227368151
const RUBY_HANDLER := 101
const RUBY_ID := "act2:L19_BC:ruby_of_truth"
const CURSE_AT := 2
const RUBY_AT := 3
const ANCIENT_LEVEL := 5
const CURSE_LINE := "Expel the curse into the mother beast."
const RUBY_COMMENT := "Dawn gives Luther the Ruby of Truth and vanishes."
const SCENE_NAME := "placenta.vqa"
const SCENE_OFFSET := 5066703
const IN_MOVIE_TABLE := false
const BIRTHED_PLACEMENTS := 0
const DEMONS := -1
const DOOR := -1
const PLAYER_KILLS_MOTHER := false
const BIRTH_HOLD := 2.0
const BIRTH_PROP := 87
const BIRTH_CALLER := 20
const BIRTH_MOVIE := 65
const BIRTH_NAME := "bb_brth"
const BIRTH_X := -1382
const BIRTH_Y := 3213
const BIRTH_HEADING := 0x4000
const BIRTH_FLAGS := 0x0085
const BIRTH_REEL := "res://assets/lol2/generated/l20_bb_brth/movie.json"
const DAWN_AT := Vector3(2802, -1000, -882)
const ACTOR_AT := Vector3(1939, -125, -891)
const MOTHER_AT := Vector3(-1160, -20, -4258)
const REACH := 30.0
var host: Node3D
var hint: Label
var stage: Label
var mother_body: MeshInstance3D
var demons: MeshInstance3D
var birth_door: MeshInstance3D
var cast_level: int = 5
var birth_elapsed: float = 0.0
var birth_plays: int = 0
var birth_reel_started: bool = false
var overlay: CanvasLayer

static func initial() -> Dictionary:
	return {"version": 1, "clicks": 0, "curse_said": false, "ruby_offered": false, "line": "", "glob_entered": false, "demons_killed": false, "mother_dead": false, "creatures_cleared": false}

static func accepts_level(level: int) -> bool:
	return level == ANCIENT_LEVEL

static func grants_ruby() -> bool:
	return true

static func plays_movie() -> bool:
	return true

static func relocates_player() -> bool:
	return false

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 9: return "Invalid dawn curse state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid dawn curse state."
	var clicks: Variant = s.get("clicks")
	if not (clicks is int or clicks is float) or int(clicks) < 0 or int(clicks) > RUBY_AT: return "Invalid dawn curse state."
	if not (s.get("curse_said") is bool) or not (s.get("ruby_offered") is bool): return "Invalid dawn curse state."
	if not (s.get("glob_entered") is bool) or not (s.get("demons_killed") is bool): return "Invalid dawn curse state."
	if not (s.get("mother_dead") is bool) or not (s.get("creatures_cleared") is bool): return "Invalid dawn curse state."
	if bool(s.get("demons_killed")) and not bool(s.get("glob_entered")): return "Invalid dawn curse state."
	if bool(s.get("mother_dead")) and not bool(s.get("demons_killed")): return "Invalid dawn curse state."
	if bool(s.get("creatures_cleared")) and not bool(s.get("mother_dead")): return "Invalid dawn curse state."
	var line: Variant = s.get("line")
	if not line is String: return "Invalid dawn curse state."
	var n: int = int(clicks)
	var said: bool = bool(s.get("curse_said"))
	var offered: bool = bool(s.get("ruby_offered"))
	if said != (n >= CURSE_AT): return "Invalid dawn curse state."
	if offered != (n >= RUBY_AT): return "Invalid dawn curse state."
	if said and str(line) != CURSE_LINE: return "Invalid dawn curse state."
	if not said and str(line) != "": return "Invalid dawn curse state."
	if bool(s.get("glob_entered")) and not said: return "Invalid dawn curse state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_dawn_curse.gd").new()
	n.host = map
	var label: String = "L19DawnCurse" if str(map.area_id) == "L19_BC" else "L20MotherCurse"
	n.name = label
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var clicks: int = int(raw.get("clicks", 0))
	var said: bool = bool(raw.get("curse_said", false))
	var line: String = CURSE_LINE if said else ""
	var glob: bool = bool(raw.get("glob_entered", false)) and said
	var demon_flag: bool = bool(raw.get("demons_killed", false)) and glob
	var dead: bool = bool(raw.get("mother_dead", false)) and demon_flag
	return {"version": int(raw.get("version", 1)), "clicks": clicks, "curse_said": said, "ruby_offered": bool(raw.get("ruby_offered", false)) and clicks >= RUBY_AT, "line": line, "glob_entered": glob, "demons_killed": demon_flag, "mother_dead": dead, "creatures_cleared": bool(raw.get("creatures_cleared", false)) and dead}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 516)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 484)
	canvas.add_child(stage)
	# L19 hosts Dawn. The mother, the demons, and the birth door belong to L20 only.
	if str(host.area_id) != "L20_BB":
		return
	mother_body = _box("MotherBody", MOTHER_AT, Color(0.35, 0.55, 0.3))
	demons = _box("DemonWave", MOTHER_AT + Vector3(30, 0, 0), Color(0.6, 0.1, 0.1))
	birth_door = _box("BirthDoor", MOTHER_AT + Vector3(-30, 0, 0), Color(0.4, 0.35, 0.2))
	var native: Object = host.progression.native
	if native != null:
		native.connect("movie_request", _on_birth_movie)

func _box(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(16, 28, 16)
	mesh_node.mesh = box
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func _show() -> void:
	var s: Dictionary = state()
	if mother_body == null:
		if str(host.area_id) == "L19_BC" and bool(s.ruby_offered):
			stage.text = "Dawn gives Luther the Ruby of Truth."
		return
	mother_body.visible = not bool(s.mother_dead)
	demons.visible = not bool(s.demons_killed)
	birth_door.position.y = MOTHER_AT.y + (4.0 if bool(s.demons_killed) else 0.0)
	if bool(s.mother_dead):
		stage.text = "The mother beast dies after the birth."
	elif bool(s.demons_killed):
		stage.text = "The demons fall. The birth door opens."
	elif bool(s.glob_entered):
		stage.text = "Belial is born."
	elif str(host.area_id) == "L19_BC" and bool(s.ruby_offered):
		stage.text = "Dawn gives Luther the Ruby of Truth."

func _clear_area() -> void:
	var population: Node = host.get("act2_creatures")
	if population == null or not is_instance_valid(population): return
	if not population.has_method("_birth_area_quiet"): return
	population._birth_area_quiet()

func _process(delta: float) -> void:
	hint.text = ""
	if is_instance_valid(overlay):
		return
	if str(host.area_id) == "L20_BB" and bool(state().demons_killed) and not bool(state().mother_dead) and not PLAYER_KILLS_MOTHER:
		birth_elapsed += delta
		if birth_elapsed >= BIRTH_HOLD:
			var done: Dictionary = state()
			done.mother_dead = true
			done.creatures_cleared = true
			host.quest_state[KEY] = done
			_clear_area()
	_show()
	if bool(state().creatures_cleared):
		_clear_area()
	if host.flying or not host.starting_magic.world_active(): return
	if str(host.area_id) == "L19_BC" and flat_to(DAWN_AT) < REACH:
		hint.text = "E — Speak with Dawn"
	elif str(host.area_id) == "L20_BB" and bool(state().curse_said) and not bool(state().demons_killed):
		if not bool(state().glob_entered) and flat_to(MOTHER_AT) < REACH:
			hint.text = "Curse · Shift+Q — Expel the curse into the mother"
		elif bool(state().glob_entered):
			hint.text = "E — The demons fall"

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(overlay):
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE):
			skip_birth()
			get_viewport().set_input_as_handled()
		return
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if str(host.area_id) == "L19_BC":
		_click_dawn()
	elif str(host.area_id) == "L20_BB":
		_cast_curse()

func generic_target() -> Dictionary:
	if str(host.area_id)!="L19_BC" or host.flying or not host.starting_magic.world_active() or is_instance_valid(overlay):return {}
	if flat_to(DAWN_AT)>=REACH or int(state().clicks)>=RUBY_AT:return {}
	return {"point":DAWN_AT}
func try_use() -> bool:
	if generic_target().is_empty():return false
	_click_dawn()
	return true

func _click_dawn() -> void:
	if flat_to(DAWN_AT) >= REACH: return
	var s: Dictionary = state()
	if int(s.clicks) >= RUBY_AT: return
	s.clicks = int(s.clicks) + 1
	if int(s.clicks) >= CURSE_AT:
		s.curse_said = true
		s.line = CURSE_LINE
	if int(s.clicks) >= RUBY_AT:
		s.ruby_offered = true
		_grant_ruby()
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()

func _grant_ruby() -> void:
	if RUBY_ID in host.carried_collected: return
	if host.carried_collected.size() >= 64: return
	var collected: Variant = host.quest_state.get("act2_items", Items.initial()).get("collected")
	if not collected is Array: return
	Grants.grant(host,RUBY_ID,{"cap":false,"duplicate":"allow","history":"act2_once","sync":true})

func _cast_curse() -> void:
	var s: Dictionary = state()
	# E is only the later demons-fall beat. Expel belongs to the spell owner.
	if not bool(s.glob_entered) or bool(s.demons_killed): return
	if not bool(s.curse_said) or not Forms.can_cast(int(host.player_form)) or not accepts_level(cast_level):
		stage.text = "The mother shoots a fireball back. She does not die."
		get_viewport().set_input_as_handled()
		return
	s.demons_killed = true
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()

func accepts_player_spell(id: String) -> bool:
	return id == "curse5" and str(host.area_id) == "L20_BB" and not bool(state().glob_entered) and flat_to(MOTHER_AT) < REACH

func receive_player_spell(id: String) -> bool:
	if not accepts_player_spell(id): return false
	var s: Dictionary = state()
	if not bool(s.curse_said) or not Forms.can_cast(int(host.player_form)) or not accepts_level(cast_level):
		host.save_feedback("The mother shoots a fireball back. She does not die.")
		return false
	s.glob_entered = true
	host.quest_state[KEY] = s
	# The cast into the mother is the port's prop-242 beat (kind 6 caller 21, group 7704): commit its store of
	# [0x26E58] cell 52 = 1 (the group itself stops on undecoded opcode-2 arms), so the L19 door later leads to
	# L20 arrival 2 (act2_progression _l20_door_cell, lead 2026-11-14, DEVIATIONS 0661).
	var pr: Node = host.get("progression") as Node
	if pr != null and pr.get("native") != null: pr.native.call("set_local_e58", 52, 1)
	_show()
	_birth_relocation()
	host.save_feedback("The curse enters the mother.")
	return true

## Prop 87's byte +0x25 starts unknown, and the kind-2 expiry that would walk it to 13 was not entered.
## The level-5 cast is the birth the book shows. It stores 13 so caller 20 matches, then group 770 runs.
## Opcode 18 moves Luther through the player consumer. This function does not place him.
func _birth_relocation() -> void:
	var progression: Node = host.get("progression") as Node
	if progression == null:
		return
	var native: Object = progression.get("native")
	if native == null:
		return
	native.call("set_field", "prop:%d" % BIRTH_PROP, "byte_0x25", 13)
	progression.call("fire", "prop:%d" % BIRTH_PROP, 6, {"caller_byte": BIRTH_CALLER, "context": "prop:%d" % BIRTH_PROP})

static func birth_reel_ready() -> bool:
	if not FileAccess.file_exists(BIRTH_REEL):
		return false
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIRTH_REEL))
	if not info is Dictionary:
		return false
	var row: Dictionary = info
	return int(row.get("index", -1)) == BIRTH_MOVIE and str(row.get("name", "")) == BIRTH_NAME and FileAccess.file_exists(str(row.get("path", "")))

func _on_birth_movie(index: int, movie_name: String, _byte5: int) -> void:
	if index != BIRTH_MOVIE or movie_name != BIRTH_NAME or is_instance_valid(overlay):
		return
	birth_plays += 1
	if not birth_reel_ready():
		return
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BIRTH_REEL))
	overlay = CanvasLayer.new()
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(black)
	var video := VideoStreamPlayer.new()
	video.name = "Video"
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.expand = true
	var stream := VideoStreamTheora.new()
	stream.file = str(info.get("path", ""))
	video.stream = stream
	video.finished.connect(skip_birth)
	overlay.add_child(video)
	add_child(overlay)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	birth_reel_started = true
	video.play()

func skip_birth() -> void:
	if is_instance_valid(overlay):
		var video: VideoStreamPlayer = overlay.get_node("Video")
		video.stop()
		overlay.queue_free()
	overlay = null
	process_mode = Node.PROCESS_MODE_INHERIT
	if get_tree() != null:
		get_tree().paused = false
