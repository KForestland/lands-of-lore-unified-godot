extends Node3D
## Native A5411/B6B98 drains the dead captain's actor inventory into world drops.
## Modern adapter: five active seconds after the source fighting-death grant;
## the corpse is hidden at retirement. The source item list remains a grant ledger.
const Items = preload("res://scripts/lol2/cave_captain_items.gd")
const DELAY := 5.0
var captain: Node3D
var sprite: MeshInstance3D

static func eligible(source: Dictionary) -> bool:
	return int(source.captain.health) == 0 and "5-Short swd" in source.captain.items

static func validate(packet: Variant, source: Dictionary) -> String:
	if packet == null: return ""
	if not packet is Dictionary or packet.size() != 2 or not packet.get("taken") is bool: return "Invalid captain loot."
	var elapsed = packet.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0 or elapsed > DELAY: return "Invalid captain loot clock."
	if not eligible(source) or (packet.taken and elapsed != DELAY): return "Captain loot lacks its death grant."
	return ""

func setup(owner: Node3D) -> void:
	captain = owner
	var path := "res://assets/lol2/generated/cave_captain_items/Short_Sword_indices.png"
	var image := Image.load_from_file(path)
	sprite = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(image.get_width(), image.get_height()) * 0.5
	sprite.mesh = quad
	sprite.layers = 2
	sprite.material_override = captain.host._indexed_material(path)
	sprite.material_override.set_shader_parameter("sprite", true)
	add_child(sprite)
	captain.host._copy_occluders(sprite)
	sprite.visible = false

func advance(delta: float) -> void:
	if eligible(captain.state.source):
		if not captain.state.has("loot"): captain.state.loot = {"elapsed":0.0,"taken":false}
		captain.state.loot.elapsed = minf(DELAY, float(captain.state.loot.elapsed) + delta)
	present()

func present() -> void:
	if sprite == null or captain.state == null: return
	var packet: Dictionary = captain.state.get("loot", {})
	var retired := eligible(captain.state.source) and float(packet.get("elapsed", 0)) >= DELAY
	sprite.visible = retired and not packet.get("taken", false)
	captain.population.bodies["56"].visible = captain.state.source.captain.present and not retired
	for pair in captain.host.occluder_pairs + captain.host.light_pairs:
		if pair[0] == captain.population.meshes["56"]: pair[1].visible = pair[0].is_visible_in_tree()
	sprite.global_position = captain.population.bodies["56"].global_position + Vector3.UP * 8
	for pair in captain.host.occluder_pairs + captain.host.light_pairs:
		if pair[0] == sprite:
			pair[1].global_transform = sprite.global_transform
			pair[1].visible = sprite.visible

func aimed() -> bool:
	if not sprite.visible or not captain.active() or captain.intro_active(): return false
	var host: Node3D = captain.host
	var offset: Vector3 = sprite.global_position - host.camera.global_position
	if offset.length() < 0.01 or offset.length() > 96 or (-host.camera.global_basis.z).dot(offset.normalized()) < 0.96: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, sprite.global_position, 1, [host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func collect() -> bool:
	if not aimed(): return false
	captain.state.loot.taken = true
	present()
	captain.host._save_feedback("Short Sword taken.")
	return true
