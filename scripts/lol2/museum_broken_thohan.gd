extends Node3D
## Museum control 181. Group 11954 gives 12-Tho Broken from a null hand at owner state 0.
## Group 11984 takes that held item at owner state 1. Reach and E are the museum adapter.
const ITEM := "museum:control181:Tho_Broken"
const ROOT := "res://assets/lol2/generated/museum_broken_thohan/"
const REACH := 96.0
const AIM := 0.97
const STATE_KEY := "museum_control181"
var host: Node3D
var sword: MeshInstance3D
var catalog: Dictionary
var owner_state := 0
var sprite_mode := 0

func _ready() -> void:
	host = get_parent()
	catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "control.json"))
	assert(catalog.id == ITEM and int(catalog.control) == 181)
	assert(int(catalog.region_field) == 413 and bool(catalog.region_contains_control))
	assert(int(catalog.grant.qualifier) == 0 and catalog.grant.predicate_hex == "0005000000")
	assert(int(catalog.put_back.qualifier) == 3 and catalog.put_back.predicate_hex == "0005000001")
	assert(catalog.grant.event_hex == "0a04b22e000000000000")
	assert(catalog.put_back.event_hex == "0a04d02e03007c2ec274")
	assert(catalog.grant.commands == ["030100007c2ec27401000000", "0510b5000100", "1010b5000100"])
	assert(catalog.put_back.commands == ["020100001800", "0510b5000000", "1010b5000000"])
	assert(float(catalog.modern_adapter.reach) == REACH and float(catalog.modern_adapter.aim) == AIM)
	var row: Dictionary = catalog.sword
	var image := Image.load_from_file(ROOT + str(row.image))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.size = Vector2(float(row.right) - float(row.left), float(row.top) - float(row.bottom))
	quad.center_offset = Vector3((float(row.left) + float(row.right)) / 2.0, (float(row.bottom) + float(row.top)) / 2.0, 0)
	sword = MeshInstance3D.new()
	sword.mesh = quad
	sword.material_override = material
	var place: Array = row.position
	sword.position = Vector3(float(place[0]), float(place[1]), float(place[2]))
	add_child(sword)
	restore()

func restore() -> void:
	var saved: Dictionary = {}
	var quest = host.get("quest_state")
	if quest is Dictionary and quest.get(STATE_KEY) is Dictionary:
		saved = quest[STATE_KEY]
	if saved.has("owner_state") and saved.has("sprite_mode"):
		owner_state = int(saved.owner_state)
		sprite_mode = int(saved.sprite_mode)
	elif _carried():
		owner_state = 1
		sprite_mode = 1
		_persist()
	else:
		owner_state = int(catalog.initial_owner_state)
		sprite_mode = int(catalog.initial_sprite_mode)
	_show()

func source_group() -> String:
	if owner_state == 0 and _hand() == "":
		return "grant"
	if owner_state == 1 and _holds_broken():
		return "put_back"
	return ""

func run_source_group() -> bool:
	var group := source_group()
	if group == "" or not host.get("carried_collected") is Array:
		return false
	if group == "grant":
		if not ITEM in host.carried_collected:
			host.carried_collected.append(ITEM)
		host.hand_item = ITEM
		owner_state = int(catalog.grant.next_owner_state)
		sprite_mode = int(catalog.grant.next_sprite_mode)
	else:
		host.hand_item = ""
		host.carried_collected.erase(ITEM)
		host.carried_collected.erase(str(catalog.source_name))
		owner_state = int(catalog.put_back.next_owner_state)
		sprite_mode = int(catalog.put_back.next_sprite_mode)
	_persist()
	_show()
	return true

func use() -> bool:
	if _blocked() or not _reached():
		return false
	return run_source_group()

func interaction_hint() -> String:
	if _blocked() or not _reached(): return ""
	match source_group():
		"grant": return "E — Take Broken Thohan"
		"put_back": return "E — Return Broken Thohan"
	return ""

func aim_point() -> Vector3:
	return sword.to_global(sword.mesh.center_offset)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use():
		get_viewport().set_input_as_handled()

func _hand() -> String:
	var value = host.get("hand_item")
	return value if value is String else ""

func _holds_broken() -> bool:
	var value := _hand()
	return value == ITEM or value == str(catalog.source_name)

func _carried() -> bool:
	if _holds_broken():
		return true
	var pack = host.get("carried_collected")
	return pack is Array and (ITEM in pack or catalog.source_name in pack)

func _persist() -> void:
	var quest = host.get("quest_state")
	if quest is Dictionary:
		quest[STATE_KEY] = {"owner_state": owner_state, "sprite_mode": sprite_mode}

func _show() -> void:
	sword.visible = sprite_mode == int(catalog.sword.visible_mode)

func _blocked() -> bool:
	if host.get("flying") == true or get_tree().paused or not _mouse_ready():
		return true
	return _overlay_blocks()

func _mouse_ready() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _overlay_blocks() -> bool:
	var hud = host.get("interface_hud")
	if hud != null and is_instance_valid(hud) and hud.cursor_active:
		return true
	var inventory = host.get("inventory")
	if inventory != null and is_instance_valid(inventory):
		return true
	for node_name in ["departure", "monastery", "magic_shop", "weapon_shop", "village_dialogue", "followup_dialogue"]:
		var room = host.get(node_name)
		if room != null and is_instance_valid(room) and room.has_method("active") and room.active():
			return true
	return false

func _reached() -> bool:
	if sword == null:
		return false
	var delta: Vector3 = aim_point() - host.camera.global_position
	if delta.length() < 0.01 or delta.length() > REACH:
		return false
	if (-host.camera.global_basis.z).dot(delta.normalized()) < AIM:
		return false
	var query := PhysicsRayQueryParameters3D.create(host.camera.global_position, aim_point())
	var excluded: Array[RID] = [host.player.get_rid()]
	var exhibit = host.get_node_or_null("BrokenCase")
	if exhibit != null:
		excluded.append_array(exhibit.interaction_exclude())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func validate_checkpoint(value: Variant) -> String:
	if not value is Dictionary: return "Invalid broken sword control."
	for key in ["owner_state","sprite_mode"]:
		var n = value.get(key)
		if not (n is int or n is float) or (n != 0 and n != 1): return "Invalid broken sword control."
	return ""
