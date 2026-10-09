extends Node3D
## Guards52/53 each hold one Short Sword (identity 0xe29a1126) and one Guard Shield (0x9e689a13), granted on cave
## arrival: prop699 -> group7878 (op3 actor52, item property1 each) and prop1067 -> group8908 (op3 actor53, item
## property4 each). Native ADF34 selects both groups without a predicate; no group removes actor52/53
## (opus/guard52_53_loot_20261009/grant_replay.json). Property is an item byte, not a quantity. Native retirement
## drains the whole actor inventory. Modern adapter: five active seconds then hide the corpse and expose both items;
## each is picked up individually. One owner instance per guard (configure(actor)).
const DELAY := 5.0
const SPREAD := 7.0
const KEYS := ["sword","shield"]
const ACTORS := {
	"52":{"sword":"cave:guard52:Short_Sword","shield":"cave:guard52:Guard_Shield"},
	"53":{"sword":"cave:guard53:Short_Sword","shield":"cave:guard53:Guard_Shield"}}
const IMAGES := {"sword":"res://assets/lol2/generated/cave_captain_items/Short_Sword_indices.png","shield":"res://assets/lol2/generated/cave_guard_shield/Guard_Shield_indices.png"}
var actor := ""
var host: Node3D
var state := initial()
var sprites := {}

static func initial() -> Dictionary: return {"elapsed":0.0,"taken":{"sword":false,"shield":false}}

static func eligible(guards: Variant, id: String) -> bool:
	if not guards is Dictionary: return false
	var row = guards.get("actors",{}).get(id,{})
	return row is Dictionary and row.get("present",false) and int(row.get("health",1)) == 0

static func validate(packet: Variant, guards: Variant, id: String) -> String:
	if packet == null: return ""
	if not ACTORS.has(id): return "Unknown guard loot owner."
	if not packet is Dictionary or packet.size() != 2 or not packet.get("taken") is Dictionary or packet.taken.size() != 2: return "Invalid guard%s loot." % id
	for key in KEYS:
		if not packet.taken.get(key) is bool: return "Invalid guard%s loot receipt." % id
	var elapsed = packet.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0 or elapsed > DELAY: return "Invalid guard%s loot clock." % id
	if not eligible(guards, id) or ((packet.taken.sword or packet.taken.shield) and elapsed != DELAY): return "Guard%s loot lacks a dead, present actor." % id
	return ""

static func carried(packet: Dictionary, id: String) -> Array:
	var out: Array = []
	for key in KEYS:
		if packet.get("taken",{}).get(key,false): out.append(ACTORS[id][key])
	return out

func configure(id: String) -> Node3D:
	actor = id; name = "CaveGuard%sLoot" % id
	return self

func setup(owner: Node3D) -> void:
	host = owner
	for key in KEYS:
		var image := Image.load_from_file(IMAGES[key])
		var sprite := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(image.get_width(), image.get_height()) * 0.5
		sprite.mesh = quad; sprite.layers = 2
		sprite.material_override = host._indexed_material(IMAGES[key])
		sprite.material_override.set_shader_parameter("sprite",true)
		add_child(sprite); host._copy_occluders(sprite)
		sprites[key] = sprite
	present()

func checkpoint() -> Variant:
	return state.duplicate(true) if state.elapsed > 0 or state.taken.sword or state.taken.shield else null

func restore(packet: Variant) -> void:
	state = initial() if packet == null else packet.duplicate(true)
	present()

func active() -> bool:
	return not host.flying and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and host.starting_magic != null and host.starting_magic.world_active()

func advance(delta: float) -> void:
	if not active() or not is_finite(delta) or delta <= 0: return
	if eligible(host.guard_population.state, actor): state.elapsed = minf(DELAY, float(state.elapsed) + delta)
	present()

func present() -> void:
	if sprites.is_empty(): return
	var body: Node3D = host.guard_population.bodies[actor]
	var dead := eligible(host.guard_population.state, actor)
	var retired := dead and float(state.elapsed) >= DELAY
	if dead: body.visible = host.guard_population.state.actors[actor].present and not retired
	var across: Vector3 = body.global_basis.x.normalized() if body.global_basis.x.length() > 0.01 else Vector3.RIGHT
	for i in KEYS.size():
		var key: String = KEYS[i]
		var sprite: MeshInstance3D = sprites[key]
		sprite.visible = retired and not state.taken[key]
		sprite.global_position = body.global_position + Vector3.UP * 8 + across * SPREAD * (-1.0 if i == 0 else 1.0)
	for pair in host.occluder_pairs + host.light_pairs:
		if pair[0] == host.guard_population.meshes[actor]: pair[1].visible = pair[0].is_visible_in_tree()
		else:
			for sprite in sprites.values():
				if pair[0] == sprite:
					pair[1].global_transform = sprite.global_transform
					pair[1].visible = sprite.visible

func aimed() -> String:
	if not active(): return ""
	var best := ""
	var best_dot := 0.96
	for key in KEYS:
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
	state.taken[key] = true; present(); host._save_feedback(("Short Sword" if key == "sword" else "Guard Shield") + " taken.")
	return true

func _physics_process(delta: float) -> void: advance(delta)
func _process(_delta: float) -> void: present()
