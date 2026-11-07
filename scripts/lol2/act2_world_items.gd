extends Node3D
const Source = preload("res://scripts/lol2/act2_items_catalog.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
var host: Node3D
var area_id := ""
var sprites: Dictionary = {}
var rows: Dictionary = {}
static func attach(map: Node3D, area: String) -> Node3D:
	var owner = load("res://scripts/lol2/act2_world_items.gd").new()
	owner.host = map
	owner.area_id = area
	owner.name = "Act2WorldItems"
	map.add_child(owner)
	var error := Source.restore(map)
	if not error.is_empty(): push_error(error)
	return owner
func _ready() -> void:
	var shared = host.get("area_world_items")
	var placements: Array = Source.source().areas[area_id].items.duplicate()
	if area_id=="L9_DR": placements.append(Source.tower_blank())
	if area_id=="L13_RC":placements.append_array(Source.basin_items())
	if area_id=="L14_HT":placements.append(Source.temple_machine_statue())
	if area_id=="L16_CA":
		var bow: Dictionary = Source.dark_bow()
		if not bow.is_empty(): placements.append(bow)
	for row in placements:
		var id := str(row.id)
		# Placements also hosted by area_world_items.gd (L8_SJ eggs / Manafoil) are left to that controller: one sprite and
		# one E owner per placement (owner F10 2026-11-02 12:25 "cant pick up the eggs").
		if shared != null and is_instance_valid(shared) and shared.has_method("hosts_twin") and shared.hosts_twin(id): continue
		var image := Image.load_from_file(str(row.icon))
		var sprite := Sprite3D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.pixel_size = 0.5
		sprite.position = Vector3(row.position[0],row.position[1],row.position[2])
		sprite.offset.y = image.get_height()/2.0
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(sprite)
		sprites[id] = sprite
		rows[id] = row
	restore()
func restore() -> void:
	var collected: Array = host.quest_state.get("act2_items",Source.initial()).collected
	for id in sprites:
		sprites[id].visible = id not in collected and id!="act2:L9_DR:item0"
		if id=="act2:L14_HT:item67":sprites[id].visible=sprites[id].visible and host.quest_state.get("l14_niche",{}).get("raised",0)>=2
		if id=="act2:L14_HT:item65":sprites[id].visible=sprites[id].visible and host.quest_state.get("l14_machines",{}).get("phase")=="formed"
		if id=="act2:L16_CA:item24":sprites[id].visible=sprites[id].visible and bool(host.quest_state.get("l16_se_oil",{}).get("burned",false))
		if id in ["act2:L13_RC:item145","act2:L13_RC:item146","act2:L13_RC:item147"]:sprites[id].visible=sprites[id].visible and float(host.quest_state.get("l13_eggs",{}).get("drain",0))>=2.0
func aim_point(id: String) -> Vector3:
	return sprites[id].global_position + Vector3.UP * sprites[id].texture.get_height() * 0.25
func available(id: String) -> bool:
	if id=="act2:L14_HT:item67" and host.quest_state.get("l14_niche",{}).get("raised",0)<2:return false
	if id=="act2:L14_HT:item65" and host.quest_state.get("l14_machines",{}).get("phase")!="formed":return false
	if get_tree().paused: return false
	if id in preload("res://scripts/lol2/l8_clubhouse.gd").STONES and not host.quest_state.get("l8_clubhouse",{}).get("opened",false):return false
	if id=="act2:L9_DR:item0":return false # Original full urn is produced only by the pyre Kit transaction.
	if id=="act2:L9_DR:item55" and host.has_node("L9DeadBracers") and not host.get_node("L9DeadBracers").released(): return false
	if not sprites.has(id) or not sprites[id].visible: return false
	var delta: Vector3 = aim_point(id) - host.camera.global_position
	if delta.length()<0.01 or delta.length()>96.0 or (-host.camera.global_basis.z).dot(delta.normalized())<0.97: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, aim_point(id), 1, [host.player.get_rid()])
	ray.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func target() -> String:
	for id in sprites:
		if available(id): return id
	return ""
func take(id: String) -> bool:
	if not available(id) or id in host.carried_collected: return false
	if host.carried_collected.size() >= Catalog.MAX_CARRIED:
		host.save_feedback("Inventory full.")
		return false
	var packet: Dictionary = host.quest_state.get("act2_items",Source.initial()).duplicate(true)
	packet.collected.append(id)
	host.carried_collected.append(id)
	packet.carried = host.carried_collected.filter(func(item): return Source.valid(item))
	host.quest_state.act2_items = packet
	if id=="act2:L14_HT:item65" and host.has_node("L14Machines"):host.get_node("L14Machines").note_pickup()
	restore()
	host.save_feedback(Catalog.label(id) + " taken.")
	return true
func _unhandled_input(event: InputEvent) -> void:
	if host.flying or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if is_instance_valid(host.inventory) or (is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active): return
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E:
		var id := target()
		if not id.is_empty() and take(id): get_viewport().set_input_as_handled()
