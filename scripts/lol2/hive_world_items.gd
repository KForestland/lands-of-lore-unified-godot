extends Node3D
## Hive original item rows 5-9 (hive_world_items_state.gd). Same E, 96-unit reach, 0.97 aim, mask-1 occlusion and
## overlay guards as the Hive wax pickup; each sprite is the original ground sprite (definitions pack) on a modern
## fixed-Y billboard at the wax's half-pixel scale. Saved history quests.hive_world_items.collected (rows) is written
## only once a row is collected, so older saves keep their exact quest state and start with every row present.
## Native pickup admission and item handlers are not replayed; no item use is enabled here.
const State = preload("res://scripts/lol2/hive_world_items_state.gd")
const Definitions = preload("res://scripts/lol2/item_definitions.gd")
const REACH := 96.0
const AIM := 0.97
var host: Node3D
var sprites: Dictionary = {}
var collected: Array = []

static func assets_ready() -> bool:
	if not Definitions.ready(): return false
	for i in State.ROWS.size():
		if Definitions.by_identity(State.IDENTITIES[i]) != State.DEFINITIONS[i] or not FileAccess.file_exists(Definitions.icon(State.DEFINITIONS[i])): return false
	return true

func _ready() -> void:
	host = get_parent()
	for i in State.ROWS.size():
		var image := Image.load_from_file(Definitions.icon(State.DEFINITIONS[i]))
		var sprite := Sprite3D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.pixel_size = 0.5
		sprite.position = State.POSITIONS[i]
		sprite.offset.y = image.get_height()/2.0
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(sprite)
		sprites[State.ROWS[i]] = sprite

func id_of(row: int) -> String: return State.IDS[State.ROWS.find(row)]

## Saved rows decide presence; a row whose item is already carried (hand-edited or migrated packs) counts as taken.
func restore(saved: Variant, carried: Array) -> void:
	collected = State.rows_of(saved)
	for row in State.ROWS:
		if id_of(row) in carried and row not in collected: collected.append(row)
	for row in sprites: sprites[row].visible = row not in collected

## Quest value to save, or null when nothing was ever collected (the key stays absent).
func checkpoint() -> Variant:
	if collected.is_empty(): return null
	var rows := collected.duplicate()
	rows.sort()
	return {"version":1,"collected":rows}

func aim_point(row: int) -> Vector3:
	var sprite: Sprite3D = sprites[row]
	return sprite.global_position + Vector3(0,sprite.texture.get_height()*sprite.pixel_size/2.0,0)

## The aimed, visible, unobstructed row within reach when pickups are allowed (same gates as the Hive wax), or -1.
func target() -> int:
	if host.flying or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return -1
	if host.get_node("Warriors").health == 0 or host.interface_hud.cursor_active: return -1
	var actor = host.get_node("ConversationReview")
	if actor.started and not actor.completed: return -1
	return aimed_row()

## The aimed, visible, unobstructed row within reach (closest to the view centre), or -1; view geometry only.
func aimed_row() -> int:
	var best := -1
	var best_dot := AIM
	for row in sprites:
		if not sprites[row].visible: continue
		var delta: Vector3 = aim_point(row)-host.camera.global_position
		if delta.length() < 0.01 or delta.length() > REACH: continue
		var dot: float = (-host.camera.global_basis.z).dot(delta.normalized())
		if dot < best_dot: continue
		var query := PhysicsRayQueryParameters3D.create(host.camera.global_position,aim_point(row),1,[host.player.get_rid()])
		query.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		best = row
		best_dot = dot
	return best

func hint() -> String:
	var row := target()
	return "" if row < 0 else "E — Take " + Definitions.label(State.DEFINITIONS[State.ROWS.find(row)])

func collect() -> bool:
	var row := target()
	if row < 0: return false
	var id := id_of(row)
	var carried: Array = host.carried_inventory.collected
	if id in carried: return false
	if carried.size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED:
		notice("Inventory full.")
		return true
	carried.append(id)
	collected.append(row)
	sprites[row].visible = false
	notice(Definitions.label(State.DEFINITIONS[State.ROWS.find(row)]) + " taken.")
	return true

## Same timed hint-line notice as the Hive flute (hive_review.use_inventory_item).
func notice(text: String) -> void:
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 3.0
