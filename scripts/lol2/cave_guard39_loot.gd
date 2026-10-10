extends Node3D
## Prop1235 kind6 tail[9,0] -> group9420: op3 actor39/identity0xe29a1126 ("5-Short swd")/property1.
## Native ADF34 (the event9 arrival scanner, callers AEC74<-9C998 / AEEBC<-E66AB) selects group9420 with no
## predicate on cave arrival (opus/guard39_loot_20261009/grant_replay.json), so actor39 holds the sword before it is
## spawned by region631. One Short Sword, not a quantity field. Native retirement drains actor inventory.
## Modern adapter: five active seconds then hide the corpse and expose the pickup.
const ITEM := "cave:guard39:Short_Sword"
const DELAY := 5.0
var host: Node3D
var state := {"elapsed":0.0,"taken":false}
var sprite: MeshInstance3D

## The actor that died holding the arrival-granted sword: the population entry, or the dead actor that production
## control109 (cave_guard_controls.hide39) retained in guard_controls.hidden39 before resetting population39.
## A living guard (present or retained) drops nothing.
static func death_actor(guards: Variant, controls: Variant = null) -> Dictionary:
	if guards is Dictionary:
		var actor = guards.get("actors",{}).get("39",{})
		if actor is Dictionary and actor.get("present",false) and int(actor.get("health",1)) == 0: return actor
	if controls is Dictionary and controls.get("hidden39") is Dictionary:
		var hidden = controls.hidden39.get("actor",{})
		if hidden is Dictionary and hidden.get("present",false) and int(hidden.get("health",1)) == 0: return hidden
	return {}

static func eligible(guards: Variant, controls: Variant = null) -> bool: return not death_actor(guards, controls).is_empty()

static func validate(packet: Variant, guards: Variant, controls: Variant = null) -> String:
	if packet == null: return ""
	if not packet is Dictionary or packet.size() != 2 or not packet.get("taken") is bool: return "Invalid guard39 loot."
	var elapsed = packet.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0 or elapsed > DELAY: return "Invalid guard39 loot clock."
	if not eligible(guards, controls) or (packet.taken and elapsed != DELAY): return "Guard39 loot lacks a dead actor39 (population or retained by control109)."
	return ""

static func carried(packet: Dictionary) -> Array:
	return [ITEM] if packet.get("taken",false) else []

func setup(owner: Node3D) -> void:
	host = owner
	var path := "res://assets/lol2/generated/cave_captain_items/Short_Sword_indices.png"
	var image := Image.load_from_file(path)
	sprite = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(image.get_width(), image.get_height()) * 0.5
	sprite.mesh = quad; sprite.layers = 2
	sprite.material_override = host._indexed_material(path)
	sprite.material_override.set_shader_parameter("sprite",true)
	add_child(sprite); host._copy_occluders(sprite)
	present()

func checkpoint() -> Variant:
	return state.duplicate(true) if state.elapsed > 0 or state.taken else null

func restore(packet: Variant) -> void:
	state = {"elapsed":0.0,"taken":false} if packet == null else packet.duplicate(true)
	present()

func active() -> bool:
	return not host.flying and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and host.starting_magic != null and host.starting_magic.world_active()

func advance(delta: float) -> void:
	if not active() or not is_finite(delta) or delta <= 0: return
	if eligible(host.guard_population.state, controls_state()): state.elapsed = minf(DELAY, float(state.elapsed) + delta)
	present()

func controls_state() -> Variant:
	var controls = host.get("guard_controls")
	return controls.state if controls != null else null

func present() -> void:
	if sprite == null: return
	var body: Node3D = host.guard_population.bodies["39"]
	var population_dead := eligible(host.guard_population.state)
	var retired := eligible(host.guard_population.state, controls_state()) and float(state.elapsed) >= DELAY
	# Only the dead population actor's corpse is retired here; a hidden actor's body is owned by guard_controls.
	if population_dead: body.visible = host.guard_population.state.actors["39"].present and not retired
	sprite.visible = retired and not state.taken
	if population_dead: sprite.global_position = body.global_position + Vector3.UP * 8
	else:
		var dead := death_actor(null, controls_state())
		if not dead.is_empty():
			var p: Array = dead.position
			sprite.global_position = Vector3(float(p[0]), float(p[1]), float(p[2])) + host.guard_population.origin() + Vector3.UP * 8
	for pair in host.occluder_pairs + host.light_pairs:
		if pair[0] == host.guard_population.meshes["39"]: pair[1].visible = pair[0].is_visible_in_tree()
		elif pair[0] == sprite:
			pair[1].global_transform = sprite.global_transform
			pair[1].visible = sprite.visible

func aimed() -> bool:
	if not sprite.visible or not active(): return false
	var offset: Vector3 = sprite.global_position - host.camera.global_position
	if offset.length() < 0.01 or offset.length() > 96 or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.96: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position,sprite.global_position,1,[host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func collect() -> bool:
	if not aimed(): return false
	state.taken = true; present(); host._save_feedback("Short Sword taken.")
	return true

func _physics_process(delta: float) -> void: advance(delta)
func _process(_delta: float) -> void: present()
