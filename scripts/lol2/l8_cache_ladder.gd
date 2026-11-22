extends Node3D
const RESTORE_ON := ["load", "arrival"]
## L8 cache ladder. Control 69, region 678, floor -10. Opcode 18 words (-1004, 2590, height 100)
## land in region 657. Target u16 0 stays unnamed, so the player moves.
## Opcode 20 is sound 780 creaky2.aud. No movie is stored. Playback stays off.
## Opcode 18 is the hop up. The group has no return hop. E at the shelf climbs back to the
## base, and E at the base climbs up again, including after the climb has been saved.
const KEY: String = "l8_cache_ladder"
const CONTROL: int = 69
const AT := Vector3(-1034, -10, -2606)
const DEST := Vector3(-1004, 100, -2590)
## Owner r18 F10 15-30-40, body height 22, on region 678 outside the rails.
const BASE := Vector3(-1092, -10, -2627)
## Owner r17 stood at (-1087, -2638), 62 from the control, against the rails. 96 covers
## a body that the rails stop short of the old 64.
const REACH := 96.0
const SOUND_ID := 780
const SOUND_NAME := "creaky2.aud"
const OP20_PLAYED := false
var host: Node3D

static func initial() -> Dictionary:
	return {"version": 1, "climbed": false}

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid cache ladder."
	if not saved is Dictionary or saved.size() != 2 or int(saved.get("version", 0)) != 1 or not saved.get("climbed") is bool:
		return "Invalid cache ladder."
	return ""

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l8_cache_ladder.gd").new()
	node.host = map
	node.name = "L8CacheLadder"
	map.add_child(node)
	return node

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func flat_distance() -> float:
	var delta: Vector3 = host.player.global_position - AT
	return Vector2(delta.x, delta.z).length()

## Feet stay near the opcode 18 shelf after the rails push the capsule. The stored point can sit in a rung.
static func on_ledge(position: Vector3) -> bool:
	var feet: float = preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	if absf(position.y - (DEST.y + feet)) > 8.0: return false
	return Vector2(position.x - DEST.x, position.z - DEST.z).length() < 48.0

func hint_line() -> String:
	if _at_top(): return "E — Climb down"
	if _at_base(): return "E — Climb the ladder"
	return ""

func _at_top() -> bool:
	var feet: float = preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	if absf(host.player.position.y - (DEST.y + feet)) > 8.0: return false
	var flat: float = Vector2(host.player.position.x - DEST.x, host.player.position.z - DEST.z).length()
	return flat <= REACH

func _at_base() -> bool:
	if flat_distance() > REACH: return false
	var feet: float = preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	return absf(host.player.position.y - feet - AT.y) <= 24.0

func _overlaps(body: CharacterBody3D) -> bool:
	var collider := body.get_child(0) as CollisionShape3D
	if collider == null or collider.shape == null: return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = body.global_transform * Transform3D(Basis.IDENTITY, collider.position)
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _ensure_pad(body: CharacterBody3D) -> void:
	var from: Vector3 = body.global_position
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -40, 0), body.collision_mask)
	ray.exclude = [body.get_rid()]
	if not body.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return
	if get_node_or_null("Landing") != null: return
	var pad := StaticBody3D.new()
	pad.name = "Landing"
	pad.collision_layer = 1 << 8
	pad.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(48, 4, 48)
	shape.shape = box
	pad.add_child(shape)
	pad.position = Vector3(body.position.x, DEST.y - 2.0, body.position.z)
	add_child(pad)

func settle() -> void:
	var body := host.player as CharacterBody3D
	var feet: float = preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	body.velocity = Vector3.ZERO
	body.position = DEST + Vector3(0, feet, 0)
	for _step in 8:
		if not _overlaps(body): break
		var away: Vector3 = body.position - Vector3(AT.x, body.position.y, AT.z)
		away.y = 0.0
		if away.length() < 0.01: away = Vector3(1, 0, 0)
		body.position += away.normalized() * 4.0
		body.position.y = DEST.y + feet
	_ensure_pad(body)

func descend() -> void:
	var body := host.player as CharacterBody3D
	var feet: float = preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	body.velocity = Vector3.ZERO
	body.position = BASE + Vector3(0, feet, 0)
	for _step in 8:
		if not _overlaps(body): break
		var away: Vector3 = body.position - Vector3(AT.x, body.position.y, AT.z)
		away.y = 0.0
		if away.length() < 0.01: away = Vector3(-1, 0, -1)
		body.position += away.normalized() * 4.0
		body.position.y = BASE.y + feet

func use() -> bool:
	if host.get_tree().paused or bool(host.flying): return false
	if _at_top():
		descend()
		return true
	if not _at_base(): return false
	host.quest_state[KEY] = {"version": 1, "climbed": true}
	settle()
	if host.has_method("save_feedback"): host.save_feedback("You climb the ladder.")
	return true

func restore() -> void:
	pass

func _process(_delta: float) -> void:
	var text: String = hint_line()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2

func _playing() -> bool:
	if host.get_tree().paused or bool(host.flying): return false
	if is_instance_valid(host.get("inventory")): return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if not _playing(): return
	if use(): get_viewport().set_input_as_handled()
