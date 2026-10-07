extends Node3D
## Source route/activation boundary; authored timing, billboard and hand attachment.
## Sword index1 destination-remap pixels are omitted by the asset preparer.
signal sequence_finished
signal sequence_restarted
## Source group2022: prop107 leaves and live skeleton21 takes its place.
signal replaced_by_actor

const ROOT := "res://assets/lol2/generated/museum_sword_transfer/"
const START := Vector3(-3913, 0, -944)
const GOAL := Vector3(-4218, 0, -965)
const TABLE_SWORD := Vector3(-4222, 50, -1095)
var observer: Camera3D
var player: Node3D
var phase := "waiting"
var elapsed := 0.0
var idle_elapsed := 0.0
const IDLE_DURATION := 7.0 / 8.0
var actor: Node3D
var skeleton: Sprite3D
var held: Sprite3D
var table_sword: Sprite3D
var groups: Dictionary
var textures: Dictionary = {}
var trigger := PackedVector2Array()
var available := false
var collected := false
# Source prop107 states: complete=3, struck=4 (kind9 hit record1998), replaced=5 (group2022).
var struck := false
var replaced := false

static func assets_ready() -> bool:
	if not FileAccess.file_exists(ROOT + "sequence.json") or not FileAccess.file_exists(ROOT + "sword.png"): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "sequence.json"))
	if not data is Dictionary or not data.get("groups") is Dictionary: return false
	for key in ["1070", "1082", "1130", "1383"]:
		if not data.groups.has(key): return false
		for frame in data.groups[key]:
			if not FileAccess.file_exists(ROOT + "frame_%d.png" % int(frame)): return false
	return true

func _ready() -> void:
	if not assets_ready(): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "sequence.json"))
	if not data is Dictionary: return
	groups = data.groups
	for point in data.trigger_polygon: trigger.append(Vector2(point[0], point[1]))
	for frames in groups.values():
		for frame in frames:
			textures[int(frame)] = ImageTexture.create_from_image(Image.load_from_file(ROOT + "frame_%d.png" % int(frame)))
	actor = Node3D.new()
	actor.position = START
	add_child(actor)
	skeleton = _sprite(textures[1070])
	skeleton.position.y = 60
	skeleton.flip_h = true
	actor.add_child(skeleton)
	var sword_texture := ImageTexture.create_from_image(Image.load_from_file(ROOT + "sword.png"))
	held = _sprite(sword_texture)
	held.position = Vector3(-42, 56, 0.5)
	actor.add_child(held)
	table_sword = _sprite(sword_texture)
	table_sword.position = TABLE_SWORD
	table_sword.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	table_sword.visible = false
	add_child(table_sword)
	available = true

func _sprite(texture: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = 0.5
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test = false
	return sprite

func restart() -> void:
	if not available: return
	phase = "carrying"
	elapsed = 0
	idle_elapsed = 0
	struck = false
	replaced = false
	actor.visible = true
	skeleton.flip_h = true
	actor.position = START
	held.visible = true
	table_sword.visible = false
	_update_pose()
	sequence_restarted.emit()

func _process(delta: float) -> void:
	if not available: return
	if is_instance_valid(observer):
		var target := Vector3(observer.global_position.x, actor.global_position.y, observer.global_position.z)
		if actor.global_position.distance_squared_to(target) > 0.01:
			actor.look_at(target, Vector3.UP, true)
	if phase == "waiting" and is_instance_valid(player):
		if Geometry2D.is_point_in_polygon(Vector2(player.global_position.x, -player.global_position.z), trigger): restart()
	advance(delta)

func advance(delta: float) -> void:
	if not available or phase == "waiting": return
	if phase == "complete":
		if replaced: return
		if struck and idle_elapsed + maxf(delta, 0) >= IDLE_DURATION:
			# event3 at the current selector2 endpoint runs group2022.
			replaced = true
			actor.visible = false
			replaced_by_actor.emit()
			return
		idle_elapsed = fposmod(idle_elapsed + maxf(delta, 0), IDLE_DURATION)
		_update_idle_pose()
		return
	elapsed += maxf(delta, 0)
	if elapsed >= 7.625: idle_elapsed = fposmod(elapsed - 7.625, IDLE_DURATION)
	_update_pose()
	if phase == "complete": sequence_finished.emit()

func _update_pose() -> void:
	var frame: int
	if elapsed < 3.0:
		phase = "carrying"
		actor.position = START.lerp(GOAL, elapsed / 3.0)
		frame = int(groups["1070"][int(elapsed * 8) % 12])
		held.position = Vector3(-42, 56, 0.5)
	elif elapsed < 3.75:
		phase = "placing"
		actor.position = GOAL
		var index := mini(int((elapsed - 3.0) * 8), 5)
		frame = int(groups["1082"][index])
		var anchors := [Vector2(180,125), Vector2(175,100), Vector2(170,85), Vector2(170,100), Vector2(165,128), Vector2(172,137)]
		var hand: Vector2 = anchors[index]
		held.position = Vector3((160 - hand.x) * 0.5, (240 - hand.y) * 0.5, 0.5)
	else:
		actor.position = GOAL
		held.visible = false
		table_sword.visible = not collected
		# Source group1910: activate item11, then select skeleton animation3.
		var index := mini(int((elapsed - 3.75) * 8), 30)
		frame = int(groups["1383"][index])
		phase = "complete" if elapsed >= 7.625 else "after_transfer"
	skeleton.texture = textures[frame]
	if phase == "complete": _update_idle_pose()

## Kind9 hit record1998 (state3 only): state4; hit admission rules are an adapter.
func receive_hit() -> bool:
	if not available or phase != "complete" or struck or replaced: return false
	struck = true
	return true

func hit_point() -> Vector3:
	return actor.global_position + Vector3(0, 45, 0)

func checkpoint() -> Dictionary:
	return {"started": phase != "waiting", "elapsed": minf(elapsed, 7.625), "collected": collected, "idle_elapsed": idle_elapsed, "struck": struck, "replaced": replaced}

func restore_checkpoint(state: Dictionary) -> void:
	if not available: return
	collected = bool(state.get("collected", false))
	struck = bool(state.get("struck", false))
	replaced = bool(state.get("replaced", false))
	actor.visible = not replaced
	idle_elapsed = clampf(float(state.get("idle_elapsed", 0)), 0, IDLE_DURATION - 0.0001)
	skeleton.flip_h = true
	elapsed = clampf(float(state.get("elapsed", 0)), 0, 7.625)
	held.visible = true
	table_sword.visible = false
	actor.position = START
	if not state.get("started", false):
		elapsed = 0
		phase = "waiting"
		skeleton.texture = textures[1070]
		return
	# Restore visual state without emitting replay/open/reset signals.
	_update_pose()

func collect() -> void:
	collected = true
	if available: table_sword.visible = false

func _update_idle_pose() -> void:
	# Source selector2/view0 has no mirror flag. Quiet subset and timing authored.
	skeleton.flip_h = false
	skeleton.texture = textures[1130 + mini(int(idle_elapsed * 8), 6)]
