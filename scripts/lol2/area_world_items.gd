extends Node3D
## Shared controller for the original world-item rows of area_world_items_state.gd (Museum, Dark Halls, Savage Jungle): the
## Hive/Jungle world-item pickup (hive_world_items.gd / jungle_world_items.gd) with an area argument. Each row is the
## original ground sprite (definitions pack) on a modern fixed-Y billboard at the native (x, region floor, -y), its base
## settled onto the physics floor within 80 units; E takes the aimed row within 96 units (0.97 of the view centre, layer-1
## occlusion, same gates as the Jungle rows). Collected rows are saved as pickup history under the area's quest key
## (Dark Halls / Savage Jungle: host.quest_state, written only once a row is collected; Museum: the checkpoint dictionary
## through checkpoint()/restore_checkpoint()). Older saves without the key start with every row present; a row whose id is
## already carried counts as taken. Native pickup admission and item handlers are not replayed here.
const State := preload("res://scripts/lol2/area_world_items_state.gd")
const Definitions := preload("res://scripts/lol2/item_definitions.gd")
const Catalog := preload("res://scripts/lol2/item_catalog.gd")
const Act2Items := preload("res://scripts/lol2/act2_items_catalog.gd")
const REACH := 96.0
const AIM := 0.97
const SETTLE := 80.0
var area := ""
var host: Node3D
var sprites: Dictionary = {}
var settled: Dictionary = {}
var collected: Array = []
## True when the host has no E chain of its own (the jungle family): this node takes E itself.
var handles_input := true

static func assets_ready(which: String) -> bool:
	if not Definitions.ready() or not State.AREAS.has(which): return false
	var data: Dictionary = State.AREAS[which]
	for i in data.rows.size():
		if Definitions.by_identity(data.identities[i]) != data.definitions[i] or not FileAccess.file_exists(Definitions.icon(data.definitions[i])): return false
	return true

func setup(owner: Node3D, which: String) -> String:
	if not assets_ready(which): return "World items of %s are not staged." % which
	host = owner
	area = which
	name = "AreaWorldItems"
	var data: Dictionary = State.AREAS[area]
	for i in data.rows.size():
		var image := Image.load_from_file(Definitions.icon(data.definitions[i]))
		var sprite := Sprite3D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.pixel_size = 0.5
		sprite.position = data.positions[i]
		sprite.offset.y = image.get_height() / 2.0
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		add_child(sprite)
		sprites[int(data.rows[i])] = sprite
	return ""

func _ready() -> void:
	set_physics_process(true)

## First physics frame: settle each sprite base onto the floor under its native height (presentation adapter), then
## keep presence in step with the history and the carried pack (the jungle family's load paths do not call this node).
func _physics_process(_delta: float) -> void:
	if settled.size() < sprites.size() and is_inside_tree():
		var space := get_world_3d().direct_space_state
		for row in sprites:
			if settled.has(row): continue
			var base: Vector3 = sprites[row].global_position
			var query := PhysicsRayQueryParameters3D.create(base + Vector3(0, SETTLE, 0), base - Vector3(0, SETTLE, 0), 1, [host.player.get_rid()] if host.get("player") is CollisionObject3D else [])
			var hit := space.intersect_ray(query)
			settled[row] = float(hit.position.y) - base.y if not hit.is_empty() else 0.0
			if not hit.is_empty(): sprites[row].global_position = Vector3(base.x, float(hit.position.y), base.z)
	if uses_quest_state(): restore()

func uses_quest_state() -> bool: return host != null and area != "museum" and host.get("quest_state") is Dictionary

func key() -> String: return State.key(area)
func id_of(row: int) -> String: return State.id_of(area, row)
func carried() -> Array:
	var pack = host.get("carried_collected")
	return pack if pack is Array else []

## The saved history, or (when absent) a detached empty one; `create` writes the key into host.quest_state.
func history(create: bool = false) -> Dictionary:
	if not uses_quest_state(): return {"version": 1, "collected": collected}
	if State.validate(host.quest_state.get(key()), area).is_empty():
		host.quest_state[key()].collected = host.quest_state[key()].collected.map(func(r): return int(r))
		return host.quest_state[key()]
	if not create: return State.initial()
	host.quest_state[key()] = State.initial()
	return host.quest_state[key()]

## The Act2 world-item identity of the same original placement ("act2:L8_SJ:item20" for darkerjungle row 20), or "" when
## act2_items_source.json has no such row. act2_world_items.gd (astra 10f922e) staged the L8_SJ rows too; on a host with
## this controller it leaves these rows to it (hosts_twin), so one sprite and one E owner stand at each placement
## (owner F10 2026-11-02 12:25 "cant pick up the eggs": two sprites, E went to the Act2 copy, this one stayed).
func twin_of(row: int) -> String:
	var id := "act2:%s:item%d" % [str(State.AREAS[area].level), row]
	return id if Act2Items.valid(id) else ""
func hosts_twin(id: String) -> bool:
	for row in sprites:
		if twin_of(row) == id: return true
	return false
## A placement taken through its Act2 twin (saves from before the twin was left to this controller) counts as taken.
func taken_as_twin(row: int) -> bool:
	var twin := twin_of(row)
	if twin.is_empty(): return false
	if twin in carried(): return true
	var packet = host.get("quest_state").get("act2_items") if host.get("quest_state") is Dictionary else null
	return packet is Dictionary and packet.get("collected") is Array and twin in packet.collected

## Saved history decides presence; an already-carried row (older saves, or its Act2 twin) is migrated into it.
func restore(saved: Variant = null) -> void:
	if not uses_quest_state() and saved != null: collected = State.rows_of(saved, area)
	var h := history()
	for row in sprites:
		if (id_of(row) in carried() or taken_as_twin(row)) and row not in h.collected:
			h = history(true)
			h.collected.append(row)
	collected = h.collected
	for row in sprites: sprites[row].visible = row not in collected

## Museum checkpoint value (museum_walkthrough.gd checkpoint dictionary).
func checkpoint() -> Dictionary:
	var rows := collected.duplicate()
	rows.sort()
	return {"version": 1, "collected": rows}
func restore_checkpoint(saved: Variant) -> String:
	if saved == null: saved = State.initial()
	var error := State.validate(saved, area)
	if not error.is_empty(): return error
	restore(saved)
	return ""

func aim_point(row: int) -> Vector3:
	var sprite: Sprite3D = sprites[row]
	return sprite.global_position + Vector3(0, sprite.texture.get_height() * sprite.pixel_size / 2.0, 0)

## The aimed, visible, unobstructed row within reach when pickups are allowed, or -1.
func target() -> int:
	if get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or bool(host.get("flying")) or _overlay_blocks(): return -1
	return aimed_row()

## View geometry only: the visible row closest to the view centre within REACH with a clear layer-1 ray, or -1.
func aimed_row() -> int:
	var best := -1
	var best_dot := AIM
	var camera: Camera3D = host.camera
	for row in sprites:
		if not sprites[row].visible: continue
		var delta: Vector3 = aim_point(row) - camera.global_position
		if delta.length() < 0.01 or delta.length() > REACH: continue
		var dot: float = (-camera.global_basis.z).dot(delta.normalized())
		if dot < best_dot: continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, aim_point(row), 1, [host.player.get_rid()])
		query.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		best = row
		best_dot = dot
	return best

func interaction_hint() -> String:
	var row := target()
	return "" if row < 0 else "E — Take " + Definitions.label(State.definition(id_of(row)))
func hint() -> String: return interaction_hint()

## Takes the aimed row into the carried pack and the history. True when E was consumed (taken, or refused with a notice).
func collect() -> bool:
	if not host.get("carried_collected") is Array: return false
	var row := target()
	if row < 0: return false
	var id := id_of(row)
	if id in host.carried_collected or taken_as_twin(row):
		restore()
		return false
	if host.carried_collected.size() >= Catalog.MAX_CARRIED:
		notice("Inventory full.")
		return true
	host.carried_collected.append(id)
	history(true).collected.append(row)
	restore()
	notice(Definitions.label(State.definition(id)) + " taken.")
	return true
func use() -> bool: return collect()

func notice(text: String) -> void:
	if host.has_method("save_feedback"): host.save_feedback(text)

## Shared Jungle HUD prompt (jungle_harvest.gd convention) for hosts where this node takes E itself; the Museum host
## draws its own plain-item hint.
func _process(_delta: float) -> void:
	if not handles_input or host == null: return
	var hud = host.get("interface_hud")
	if hud == null or not is_instance_valid(hud) or hud.get("hint") == null: return
	var text := interaction_hint()
	if text.is_empty(): return
	hud.hint.text = text
	hud.save_notice_remaining = 0.2

func _unhandled_input(event: InputEvent) -> void:
	if handles_input and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and collect():
		get_viewport().set_input_as_handled()

## The jungle family's overlay gates (a host with its own E chain, the Museum, gates before calling use()).
func _overlay_blocks() -> bool:
	if not handles_input: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return true
	var hud = host.get("interface_hud")
	if hud != null and is_instance_valid(hud) and bool(hud.get("cursor_active")): return true
	var inventory = host.get("inventory")
	if inventory != null and is_instance_valid(inventory): return true
	for room_name in ["departure", "monastery", "magic_shop", "weapon_shop", "thieves_den", "village_dialogue", "followup_dialogue"]:
		var room = host.get(room_name)
		if room != null and is_instance_valid(room) and room.has_method("active") and room.active(): return true
	return false
