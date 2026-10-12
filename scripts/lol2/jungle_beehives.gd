extends Node3D
## Live owner for the Jungle beehives (props251-253). Saved as quest_state.jungle_beehives. Empty-hand E at an aimed,
## reachable, unoccluded hive harvests one Wax (source kind4 mode0 at fullness 0/1) into the hand; regrowth runs on
## the active world clock. The empty hive's op15 swarm (player status 0x27) is not hosted: E is refused with a hint.
const State = preload("res://scripts/lol2/jungle_beehives_state.gd")
const SOURCE := "res://scripts/lol2/jungle_beehives_source.json"
const ROOT := "res://assets/lol2/generated/jungle_beehives/"
const REACH := 110.0
var host: Node3D
var source: Dictionary
var state: Dictionary = State.initial()
var sprites := {}
var textures: Array[ImageTexture] = []

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "hive_0.png") and FileAccess.file_exists(ROOT + "wax.png")

func initial() -> Dictionary: return State.initial()
func checkpoint() -> Dictionary: return state.duplicate(true)

func origin() -> Vector3:
	var value = host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "JungleBeehives"
	host = owner
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1 or source.hives.size() != 3: return "Invalid beehive source."
	for row in source.selectors: textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(row.image))))
	var first: Dictionary = source.selectors[0]
	for id in State.HIVES:
		var sprite := Sprite3D.new()
		sprite.texture = textures[0]
		sprite.pixel_size = (float(first.right) - float(first.left)) / float(textures[0].get_width())
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.offset.y = textures[0].get_height() / 2.0
		var p: Array = source.hives[id].position
		sprite.position = Vector3(float(p[0]), float(p[1]), float(p[2])) + origin()
		add_child(sprite)
		sprites[id] = sprite
	return restore(saved)

func restore(saved: Variant) -> String:
	var value = State.initial() if saved == null else saved
	var error := State.validate(value)
	if not error.is_empty(): return error
	state = State.canonical(value)
	present()
	return ""

## The hive trunk/nest point: the source nest sits low on the trunk (lower third of the sprite).
func aim_point(id: String) -> Vector3:
	var s: Sprite3D = sprites[id]
	return s.global_position + Vector3.UP * (textures[0].get_height() * s.pixel_size * 0.3)

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

func target() -> String:
	if not _active(): return ""
	for id in State.HIVES:
		if _reaches(aim_point(id)): return id
	return ""

func interaction_hint() -> String:
	var id := target()
	if id.is_empty(): return ""
	if int(state.hives[id].fullness) >= 2: return "The hive is empty."
	return "E — Take wax" if host.hand_item == "" else ""

func use() -> bool:
	var id := target()
	if id.is_empty() or host.hand_item != "": return false
	if int(state.hives[id].fullness) >= 2:
		if host.has_method("save_feedback"): host.save_feedback("The hive is empty.")
		return true
	var inventory := {"collected":host.carried_collected,"hand":host.hand_item}
	if State.harvest(state, id, inventory).is_empty():
		if host.has_method("save_feedback"): host.save_feedback("You cannot carry more wax.")
		return true
	host.hand_item = inventory.hand
	present()
	if host.has_method("save_feedback"): host.save_feedback("Wax added to inventory.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use():
		get_viewport().set_input_as_handled()

## Shared Jungle HUD prompt (same convention as the Kelsrick loot): refreshed while a hive is targeted.
func _process(_delta: float) -> void:
	var text := interaction_hint()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2

func _physics_process(delta: float) -> void:
	if not _active(): return
	if State.advance(state, delta): present()

func present() -> void:
	for id in State.HIVES:
		var tex: ImageTexture = textures[mini(int(state.hives[id].fullness), textures.size() - 1)]
		if sprites[id].texture != tex: sprites[id].texture = tex
