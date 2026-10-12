extends Node3D
## Live owner for the renewable Jungle harvests (jungle_harvest_state.gd). Saved as quest_state.jungle_harvest.
## Empty-hand E at an aimed, reachable, unoccluded plant/tree/barrel harvests one item into the hand (kind4 mode0);
## an armed melee strike is the kind9 producer (context masks 2/4, damage 1: opens a closed sap tree, breaks the
## barrel). Timers run on the active Jungle world clock.
const State = preload("res://scripts/lol2/jungle_harvest_state.gd")
const Items = preload("res://scripts/lol2/jungle_harvest_items.gd")
const SOURCE := "res://scripts/lol2/jungle_harvest_source.json"
const ROOT := "res://assets/lol2/generated/jungle_harvest/"
const REACH := 110.0
const MELEE := {"mask0":2,"mask2":4,"damage":1}
var host: Node3D
var source: Dictionary
var state: Dictionary = State.initial()
var sprites := {}
var kinds := {}
var textures := {}

static func assets_ready() -> bool:
	if not FileAccess.file_exists(SOURCE): return false
	for name in ["plant_0","plant_3","tree_0","tree_1","single_0","single_1","aloe","sap"]:
		if not FileAccess.file_exists(ROOT + name + ".png"): return false
	return true

func initial() -> Dictionary: return State.initial()
func checkpoint() -> Dictionary: return state.duplicate(true)

func origin() -> Vector3:
	var value = host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "JungleHarvest"
	host = owner
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1 or source.plants.size() != State.PLANTS.size() or source.trees.size() != State.TREES.size(): return "Invalid harvest source."
	for art in ["plant","tree","single"]:
		textures[art] = []
		for row in source.art[art]: textures[art].append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(row.image))))
	for id in State.PLANTS: _sprite(id, "plant", source.plants[id].position, source.art.plant[0])
	for id in State.TREES: _sprite(id, "tree", source.trees[id].position, source.art.tree[0])
	_sprite(State.BARREL, "barrel", source.single[State.BARREL].position, source.art.single[0])
	return restore(saved)

func _sprite(id: String, kind: String, p: Array, first: Dictionary) -> void:
	var art := "single" if kind == "barrel" else kind
	var tex: ImageTexture = textures[art][0]
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.pixel_size = (float(first.right) - float(first.left)) / float(tex.get_width())
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.centered = true
	sprite.offset.y = tex.get_height() / 2.0
	sprite.position = Vector3(float(p[0]), float(p[1]), float(p[2])) + origin()
	add_child(sprite)
	sprites[id] = sprite
	kinds[id] = kind

func restore(saved: Variant) -> String:
	var value = State.initial() if saved == null else saved
	var error := State.validate(value)
	if not error.is_empty(): return error
	state = State.canonical(value)
	present()
	return ""

## Aim at the lower part of the sprite (plant leaves, tree trunk tap, barrel body).
func aim_point(id: String) -> Vector3:
	var s: Sprite3D = sprites[id]
	var art := "single" if kinds[id] == "barrel" else str(kinds[id])
	var t: ImageTexture = textures[art][0]
	return s.global_position + Vector3.UP * (t.get_height() * s.pixel_size * (0.2 if kinds[id] == "tree" else 0.4))

func _active() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.get("flying") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	if host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.get("cursor_active"): return false
	return host.get("starting_magic") == null or host.starting_magic.world_active()

func _reaches(point: Vector3) -> bool:
	var offset: Vector3 = point - host.camera.global_position
	if offset.length() < 0.01 or offset.length() > REACH: return false
	if (-host.camera.global_basis.z).dot(offset.normalized()) < 0.95: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, point, 1, [host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Closest aimed source in reach.
func target() -> String:
	if not _active(): return ""
	var best := ""; var distance := INF
	for id in sprites:
		var p := aim_point(id)
		if _reaches(p) and p.distance_to(host.camera.global_position) < distance:
			best = id; distance = p.distance_to(host.camera.global_position)
	return best

func interaction_hint() -> String:
	var id := target()
	if id.is_empty(): return ""
	var kind: String = kinds[id]
	if State.harvestable(state, kind, id):
		if host.hand_item != "": return ""
		return "E — Take sap" if kind == "tree" else "E — Take aloe"
	if kind == "tree": return "The tree is dry." if int(state.trees[id].state) == 4 else "Strike the tree to tap its sap."
	if kind == "plant": return "No aloe left on the plant."
	return "The barrel is broken." if int(state.barrel.state) == 4 else "The barrel is empty."

func _feedback(text: String) -> void:
	if host.has_method("save_feedback"): host.save_feedback(text)

func use() -> bool:
	var id := target()
	if id.is_empty() or host.hand_item != "": return false
	var kind: String = kinds[id]
	if not State.harvestable(state, kind, id):
		_feedback(interaction_hint())
		return true
	var spent: Array = host.item_effects.state().spent if is_instance_valid(host.get("item_effects")) else []
	var inventory := {"collected":host.carried_collected,"hand":host.hand_item,"spent":spent}
	var item := State.harvest(state, kind, id, inventory)
	if item.is_empty():
		_feedback("You cannot carry more.")
		return true
	host.hand_item = inventory.hand
	present()
	_feedback(Items.info(item).label + " added to inventory.")
	return true

func can_strike() -> bool:
	return not (int(host.get("player_form")) == 0 and str(host.get("equipped_item")) == "")

## Armed melee strike at the aimed source (kind9 producer). Returns true when it changed a source.
func strike() -> bool:
	var id := target()
	if id.is_empty() or kinds[id] == "plant" or not can_strike(): return false
	if not State.hit(state, kinds[id], id, MELEE): return false
	present()
	_feedback("The tree splits; sap wells up." if kinds[id] == "tree" else "The barrel breaks.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use():
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and strike():
		get_viewport().set_input_as_handled()

## Shared Jungle HUD prompt (same convention as the beehives/Kelsrick loot).
func _process(_delta: float) -> void:
	var text := interaction_hint()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2

func _physics_process(delta: float) -> void:
	if not _active(): return
	if State.advance(state, delta): present()

func present() -> void:
	for id in sprites:
		var art := "single" if kinds[id] == "barrel" else str(kinds[id])
		var tex: ImageTexture = textures[art][State.selector(state, kinds[id], id)]
		if sprites[id].texture == tex: continue
		var row: Dictionary = source.art[art][State.selector(state, kinds[id], id)]
		sprites[id].texture = tex
		# Selector frames differ in width (the broken barrel); keep each frame's source extent.
		sprites[id].pixel_size = (float(row.right) - float(row.left)) / float(tex.get_width())
		sprites[id].offset.y = tex.get_height() / 2.0
