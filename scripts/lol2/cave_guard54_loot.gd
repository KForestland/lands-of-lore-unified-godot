extends Node3D
## Guard54 holds TWO separate source Short Swords (identity 0xe29a1126, "5-Short swd"), both granted on cave arrival:
## prop1013 kind6 tail[9,0] -> group8804 (op3 actor54, item property 4) and actor54's own kind6 tail[9,0] -> group14398
## (op3 actor54, item property 1). Native ADF34 selects both without a predicate; AE990 links absent actors, so actor54
## is scanned before region969 spawns it (opus/guard54_loot_20261009/grant_replay.json). Property is an item byte,
## not a quantity; 95B68 allocates one item per op3. Native retirement drains the whole actor inventory, so both drop.
## Modern adapter: five active seconds then hide the corpse and expose both swords; each is picked up individually.
const ITEMS := {"prop1013":"cave:guard54:prop1013:Short_Sword","actor54":"cave:guard54:actor54:Short_Sword"}
const ORDER := ["prop1013","actor54"]
const DELAY := 5.0
const SPREAD := 7.0 # Presentation: the two drops lie side by side.
var host: Node3D
var state := {"elapsed":0.0,"taken":{"prop1013":false,"actor54":false}}
var sprites := {}

static func eligible(guards: Variant) -> bool:
	if not guards is Dictionary: return false
	var actor = guards.get("actors",{}).get("54",{})
	return actor is Dictionary and actor.get("present",false) and int(actor.get("health",1)) == 0

static func validate(packet: Variant, guards: Variant) -> String:
	if packet == null: return ""
	if not packet is Dictionary or packet.size() != 2 or not packet.get("taken") is Dictionary or packet.taken.size() != 2: return "Invalid guard54 loot."
	for key in ORDER:
		if not packet.taken.get(key) is bool: return "Invalid guard54 loot receipt."
	var elapsed = packet.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0 or elapsed > DELAY: return "Invalid guard54 loot clock."
	var any_taken: bool = packet.taken.prop1013 or packet.taken.actor54
	if not eligible(guards) or (any_taken and elapsed != DELAY): return "Guard54 loot lacks a dead, present actor54."
	return ""

static func carried(packet: Dictionary) -> Array:
	var out: Array = []
	for key in ORDER:
		if packet.get("taken",{}).get(key,false): out.append(ITEMS[key])
	return out

func setup(owner: Node3D) -> void:
	host = owner
	var path := "res://assets/lol2/generated/cave_captain_items/Short_Sword_indices.png"
	var image := Image.load_from_file(path)
	for key in ORDER:
		var sprite := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(image.get_width(), image.get_height()) * 0.5
		sprite.mesh = quad; sprite.layers = 2
		sprite.material_override = host._indexed_material(path)
		sprite.material_override.set_shader_parameter("sprite",true)
		add_child(sprite); host._copy_occluders(sprite)
		sprites[key] = sprite
	present()

func checkpoint() -> Variant:
	return state.duplicate(true) if state.elapsed > 0 or state.taken.prop1013 or state.taken.actor54 else null

func restore(packet: Variant) -> void:
	state = {"elapsed":0.0,"taken":{"prop1013":false,"actor54":false}} if packet == null else packet.duplicate(true)
	present()

func active() -> bool:
	return not host.flying and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and host.starting_magic != null and host.starting_magic.world_active()

func _physics_process(delta: float) -> void:
	advance(delta)

func _process(_delta: float) -> void:
	present()

func advance(delta: float) -> void:
	if not active() or not is_finite(delta) or delta <= 0: return
	if eligible(host.guard_population.state): state.elapsed = minf(DELAY, float(state.elapsed) + delta)
	present()

func present() -> void:
	if sprites.is_empty(): return
	var body: Node3D = host.guard_population.bodies["54"]
	var dead := eligible(host.guard_population.state)
	var retired := dead and float(state.elapsed) >= DELAY
	if dead: body.visible = host.guard_population.state.actors["54"].present and not retired
	var across: Vector3 = body.global_basis.x.normalized() if body.global_basis.x.length() > 0.01 else Vector3.RIGHT
	for i in ORDER.size():
		var key: String = ORDER[i]
		var sprite: MeshInstance3D = sprites[key]
		sprite.visible = retired and not state.taken[key]
		sprite.global_position = body.global_position + Vector3.UP * 8 + across * SPREAD * (-1.0 if i == 0 else 1.0)
	for pair in host.occluder_pairs + host.light_pairs:
		if pair[0] == host.guard_population.meshes["54"]: pair[1].visible = pair[0].is_visible_in_tree()
		else:
			for sprite in sprites.values():
				if pair[0] == sprite:
					pair[1].global_transform = sprite.global_transform
					pair[1].visible = sprite.visible

## The aimed, unobstructed visible drop (closest to the view centre), or "".
func aimed() -> String:
	if not active(): return ""
	var best := ""
	var best_dot := 0.96
	for key in ORDER:
		var sprite: MeshInstance3D = sprites[key]
		if not sprite.visible: continue
		var offset: Vector3 = sprite.global_position - host.camera.global_position
		if offset.length() < 0.01 or offset.length() > 96: continue
		var dot: float = (-host.camera.global_basis.z).dot(offset.normalized())
		if dot < best_dot: continue
		var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position,sprite.global_position,1,[host.player.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = key; best_dot = dot
	return best

func collect() -> bool:
	var key := aimed()
	if key.is_empty(): return false
	state.taken[key] = true; present(); host._save_feedback("Short Sword taken.")
	return true
