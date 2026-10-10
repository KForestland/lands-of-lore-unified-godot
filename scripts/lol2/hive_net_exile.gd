extends Node3D
## Hive prop214 bone-and-branch pile (hive_net_exile_source.json). Saved as quests.hive_net_exile {version, state}.
## E with the pile aimed and in reach grants "26-Net of Exile" once (source kind4 mode0 at state0, then state1);
## the pile itself stays. The Net's handler104 on-hit hold lives in net_exile_hold.gd.
const ITEM := "hive:prop214:Net_of_Exile"
const SOURCE := "res://scripts/lol2/hive_net_exile_source.json"
const ROOT := "res://assets/lol2/generated/hive_net_exile/"
const REACH := 110.0
var host: Node3D
var source: Dictionary
var state := initial()
var sprite: Sprite3D

static func assets_ready() -> bool: return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "pile.png") and FileAccess.file_exists(ROOT + "net.png")
static func initial() -> Dictionary: return {"version":1,"state":0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or value.get("version") != 1: return "Invalid Net of Exile state."
	var s = value.get("state")
	if not (s is int or s is float) or not (s == 0 or s == 1): return "Invalid Net of Exile state."
	return ""
## A taken Net must still be accounted for: state1 is required while it is carried (no free second copy).
static func transport_error(inventory: Dictionary, quests: Dictionary) -> String:
	if ITEM in inventory.get("collected", []) and int(quests.get("hive_net_exile", initial()).get("state", 0)) != 1: return "Carried Net of Exile lacks its pickup history."
	return ""
func checkpoint() -> Dictionary: return state.duplicate(true)

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "HiveNetExile"
	host = owner
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1: return "Invalid Net of Exile source."
	var image := Image.load_from_file(ROOT + "pile.png")
	sprite = Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = (float(source.sprite.right) - float(source.sprite.left)) / float(image.get_width())
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.offset.y = image.get_height() / 2.0
	sprite.position = Vector3(float(source.position[0]), float(source.position[1]), float(source.position[2]))
	add_child(sprite)
	return restore(saved)

func restore(saved: Variant) -> String:
	var value = initial() if saved == null else saved
	var error := validate(value)
	if not error.is_empty(): return error
	state = {"version":1,"state":int(value.state)}
	return ""

func aim_point() -> Vector3:
	return sprite.global_position + Vector3.UP * (sprite.texture.get_height() * sprite.pixel_size * 0.4)

func target() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.get("flying") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	if is_instance_valid(host.get("interface_hud")) and host.interface_hud.cursor_active: return false
	if host.has_node("Warriors") and host.get_node("Warriors").health == 0: return false
	var offset: Vector3 = aim_point() - host.camera.global_position
	if offset.length() < 0.01 or offset.length() > REACH or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.95: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, aim_point(), 1, [host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func interaction_hint() -> String:
	if not target(): return ""
	return "E — Search the pile" if int(state.state) == 0 else "Nothing else in the pile."

func _feedback(text: String) -> void:
	if not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 2.5

func use() -> bool:
	if not target(): return false
	var collected: Array = host.carried_inventory.collected
	if int(state.state) != 0: _feedback("Nothing else in the pile."); return true
	if collected.size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED or ITEM in collected: _feedback("You cannot carry more."); return true
	collected.append(ITEM)
	state.state = 1
	_feedback("Net of Exile added to inventory.")
	return true

func _process(_delta: float) -> void:
	var text := interaction_hint()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")) or host.interface_hud.save_notice_remaining > 0.2: return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2
