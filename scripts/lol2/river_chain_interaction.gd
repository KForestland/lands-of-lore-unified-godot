extends Node3D
const Rule = preload("res://scripts/lol2/river_chain_rule.gd")
var host: Node3D
var chains: Dictionary = {}
var frames: Array[Texture2D] = []
var intact_texture: Texture2D
func setup(walkthrough: Node3D) -> void:
	host = walkthrough
	intact_texture = ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/river_deck/chain_27_0.png"))
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/river_deck/chains.json"))
	for i in range(26): frames.append(ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/river_deck/chain_28_%d.png" % i)))
	for prop in source.props:
		var mesh := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(prop.right-prop.left,prop.top-prop.bottom)
		mesh.mesh = quad
		var anchor: Vector3 = Vector3(prop.position[0],prop.position[1],prop.position[2]) + host.native_translation
		mesh.position = anchor + Vector3((prop.right+prop.left)/2.0,(prop.top+prop.bottom)/2.0,0)
		mesh.layers = 2
		mesh.material_override = host._indexed_material("res://assets/lol2/river_deck/chain_27_0.png")
		mesh.material_override.set_shader_parameter("sprite",true)
		add_child(mesh)
		host._copy_occluders(mesh)
		chains[int(prop.record)] = {"mesh":mesh,"target":anchor+Vector3.UP*65,"elapsed":-1.0,"frame":-1}
func _physics_process(delta: float) -> void:
	for id in chains:
		var chain: Dictionary = chains[id]
		if chain.elapsed >= 0.0:
			chain.elapsed += delta
			var frame := mini(25,int(chain.elapsed*15.0))
			if frame != chain.frame:
				chain.frame = frame
				chain.mesh.material_override.set_shader_parameter("indices",frames[frame])
		var mesh: MeshInstance3D = chain.mesh
		var look := Vector3(host.camera.global_position.x,mesh.global_position.y,host.camera.global_position.z)
		if mesh.global_position.distance_squared_to(look) > 0.01: mesh.look_at(look,Vector3.UP)
		for pair in host.occluder_pairs + host.light_pairs:
			if pair[0] == mesh:
				pair[1].global_transform = mesh.global_transform
				if chain.frame >= 0: pair[1].material_override.set_shader_parameter("indices",frames[chain.frame])
func target_chain() -> int:
	if host.flying or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return -1
	var best := -1
	var distance := 96.0
	for id in chains:
		if not Rule.LINKS.has(id) or chains[id].elapsed >= 0.0: continue
		if host.river_deck.chain_rule.counts.get(Rule.LINKS[id],0) >= 2: continue
		var offset: Vector3 = chains[id].target-host.camera.global_position
		if offset.length() < 0.01 or offset.length() > distance: continue
		if (-host.camera.global_basis.z).dot(offset.normalized()) < 0.985: continue
		var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position,chains[id].target,1,[host.player.get_rid()])
		ray.hit_from_inside = true
		if not host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = id
		distance = offset.length()
	return best
func strike() -> bool:
	var id := target_chain()
	if id < 0: return false
	chains[id].elapsed = 0.0
	host.river_deck.cut_chain(id)
	return true

func near_bridge() -> bool:
	var native: Vector3 = host.player.global_position-host.native_translation
	return native.z < -16600.0 and native.z > -17780.0 and absf(native.x+65.0) < 240.0
func status_text() -> String:
	var id := target_chain()
	if id < 0: return "River bridge · Aim at a support chain to cut it."
	var count: int = host.river_deck.chain_rule.counts.get(Rule.LINKS[id],0)
	return "One chain cut · Step onto the next section before cutting another." if count == 1 else "Cut two support chains to release a bridge section."
