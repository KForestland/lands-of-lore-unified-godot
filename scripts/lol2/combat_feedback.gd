extends RefCounted
## Player-facing combat and spell feedback (modern presentation adapter; no combat rule changes).
## the owner playtest 2026-10-14: clicks gave no visible swing, Spark showed a 0.12 s hairline, Healing had no effect.
## Reference: original longplay frames (white Spark impact burst, hit splash on the HUD attack ring).
##
## landed(): melee strike owners report a landed hit here; the shared HUD reads landed_hits to show the ring splash.
## bolt()/burst(): world-space Spark/fire visuals; the damage rays and amounts stay in player_starting_magic.gd.

static var landed_hits := 0

static func landed(result: bool) -> bool:
	if result: landed_hits += 1
	return result

## Render layer for effects in hosts whose main camera draws nothing (the Cave's indexed viewports, cull_mask 0).
const EFFECT_LAYER := 1 << 19

## In such hosts effects go on EFFECT_LAYER and a transparent overlay view, following the main camera, draws them over
## the composed world (no depth occlusion against the indexed world). Other hosts draw them normally with depth.
static func _overlay_needed(host: Node) -> bool:
	var camera = host.get("camera")
	return camera is Camera3D and camera.cull_mask == 0

static func _ensure_overlay(host: Node3D) -> void:
	if host.has_node("SpellEffectsOverlay"): return
	var camera: Camera3D = host.get("camera")
	var layer := CanvasLayer.new()
	layer.name = "SpellEffectsOverlay"
	# The indexed world is resolved on a layer-20 CanvasLayer (indexed_cave_wall_review.gd); draw right after it in tree
	# order, so the effects sit over the world and under the HUD.
	layer.layer = 20
	host.add_child(layer)
	var resolve = host.get("resolve_surface")
	if resolve is Control and resolve.get_parent() is CanvasLayer and resolve.get_parent().get_parent() == host:
		host.move_child(layer, resolve.get_parent().get_index() + 1)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(container)
	var view := SubViewport.new()
	view.transparent_bg = true
	view.world_3d = host.get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	var effects_camera := Camera3D.new()
	effects_camera.cull_mask = EFFECT_LAYER
	effects_camera.fov = camera.fov; effects_camera.near = camera.near; effects_camera.far = camera.far
	view.add_child(effects_camera)
	effects_camera.current = true
	var follow := RemoteTransform3D.new()
	follow.update_scale = false
	camera.add_child(follow)
	follow.remote_path = follow.get_path_to(effects_camera)

static func _place(host: Node3D, root: Node3D) -> void:
	if not _overlay_needed(host): return
	_ensure_overlay(host)
	for node in root.find_children("*", "VisualInstance3D", true, false):
		node.layers = EFFECT_LAYER
		if node is Light3D: node.light_cull_mask = EFFECT_LAYER

static func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	# Area fog (Cave light field) would otherwise darken the effect to near black.
	material.disable_fog = true
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	return material

## Jagged bolt from `from` to `to`: short cylinders between jittered points, fading over `life` seconds.
static func bolt(host: Node3D, from: Vector3, to: Vector3, color: Color, life := 0.25, radius := 1.4) -> Node3D:
	var root := Node3D.new()
	root.name = "SpellBolt"
	host.add_child(root)
	var length := from.distance_to(to)
	if length < 0.01: return root
	var axis := (to - from) / length
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01: side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(axis).normalized()
	var segments := clampi(int(length / 24.0), 3, 12)
	var points: Array[Vector3] = [from]
	for i in range(1, segments):
		var t := float(i) / segments
		var jitter := minf(length * 0.04, 10.0)
		points.append(from + axis * length * t + side * randf_range(-jitter, jitter) + up * randf_range(-jitter, jitter))
	points.append(to)
	var material := _material(color, 1.0)
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var piece := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = a.distance_to(b)
		mesh.radial_segments = 6; mesh.rings = 1
		piece.mesh = mesh
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(piece)
		var middle := (a + b) * 0.5
		var direction := (b - a).normalized()
		var basis_up := direction
		var basis_side := basis_up.cross(Vector3.FORWARD if absf(basis_up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT).normalized()
		piece.global_transform = Transform3D(Basis(basis_side, basis_up, basis_side.cross(basis_up)), middle)
	_place(host, root)
	var tween := root.create_tween()
	tween.tween_method(func(value: float): material.albedo_color.a = value, 1.0, 0.0, life)
	tween.tween_callback(root.queue_free)
	return root

## Expanding glow sphere plus a short light flash at `at` (the original white Spark impact burst).
static func burst(host: Node3D, at: Vector3, color: Color, size := 10.0, life := 0.35) -> Node3D:
	var root := Node3D.new()
	root.name = "SpellBurst"
	host.add_child(root)
	root.global_position = at
	var material := _material(color, 0.9)
	var core := _material(Color.WHITE, 1.0)
	for scale_factor in [1.0, 0.55]:
		var glow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = size * scale_factor; sphere.height = size * 2.0 * scale_factor
		sphere.radial_segments = 12; sphere.rings = 6
		glow.mesh = sphere
		glow.material_override = material if scale_factor == 1.0 else core
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = size * 12.0
	light.light_energy = 6.0
	root.add_child(light)
	_place(host, root)
	root.scale = Vector3.ONE * 0.3
	var tween := root.create_tween().set_parallel(true)
	tween.tween_property(root, "scale", Vector3.ONE * 1.6, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "light_energy", 0.0, life)
	tween.tween_method(func(value: float): material.albedo_color.a = value, 0.9, 0.0, life)
	tween.tween_method(func(value: float): core.albedo_color.a = value, 1.0, 0.0, life)
	tween.chain().tween_callback(root.queue_free)
	return root

## Glowing orb travelling from `from` to `to` in `travel` seconds, then an impact burst (the original Spark is a
## projectile with a white impact flash). Presentation only: the hit was already resolved by the caller's ray.
static func projectile(host: Node3D, from: Vector3, to: Vector3, color: Color, impact_size := 10.0, travel := 0.18) -> Node3D:
	var root := Node3D.new()
	root.name = "SpellProjectile"
	host.add_child(root)
	root.global_position = from
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.0; sphere.height = 6.0; sphere.radial_segments = 10; sphere.rings = 5
	glow.mesh = sphere
	glow.material_override = _material(color.lightened(0.4), 0.95)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = color; light.omni_range = 60.0; light.light_energy = 3.0
	root.add_child(light)
	_place(host, root)
	var tween := root.create_tween()
	tween.tween_property(root, "global_position", to, travel)
	tween.tween_callback(func():
		if is_instance_valid(host): burst(host, to, color, impact_size)
		root.queue_free())
	return root
