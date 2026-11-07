extends SceneTree
## Report 10-13-23: the SHADE ghost drew as palette noise. Its views carry flags 0x18 and intensity frames; the sprite shader's
## ghost mode draws them translucent. Headless: the library flags only SHADE views, present() sets the shader parameter.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var library = preload("res://scripts/lol2/creature_sprite_library.gd").new()
	var error: String = library.load_manifest("res://assets/lol2/generated/dark_halls_creatures/")
	check(error.is_empty(), "library loads the Dark Halls creatures: " + error)
	if not error.is_empty(): quit(1); return
	var ghost_views := 0
	var other_ghost := 0
	for key in library.definitions:
		for state in library.definitions[key].states:
			for view in state.views:
				if library.ghost_view(view):
					if str(key) == "0": ghost_views += 1
					else: other_ghost += 1
	check(ghost_views > 0 and other_ghost == 0, "only SHADE views carry flags 0x18 (%d ghost, %d others)" % [ghost_views, other_ghost])
	var mesh := MeshInstance3D.new()
	var material: ShaderMaterial = library.bind(mesh)
	check(library.present(material, 0, 0, 0).is_empty() and bool(material.get_shader_parameter("ghost")), "SHADE pose 0 presents with ghost on")
	check(library.present(material, 1, 0, 0).is_empty() and not bool(material.get_shader_parameter("ghost")), "Rat pose 0 presents with ghost off")
	var frame: Image = library.last_texture.get_image() if library.present(material, 0, 0, 0).is_empty() else null
	var lo := 255; var hi := 0
	if frame != null:
		for y in range(0, frame.get_height(), 4):
			for x in range(0, frame.get_width(), 4):
				var v := int(frame.get_pixel(x, y).r * 255.0)
				if v > 0: lo = mini(lo, v); hi = maxi(hi, v)
	check(frame != null and lo >= 30 and hi <= 200, "SHADE frame 434 is an intensity ramp, not palette indices (%d..%d)" % [lo, hi])
	mesh.material_override = null
	material = null
	mesh.free()
	library = null
	await process_frame
	print("Dark Halls ghost: %d failures" % failures)
	if failures == 0: print("PASS dark halls ghost: SHADE views (flags 0x18) draw translucent through the sprite shader's ghost mode")
	quit(0 if failures == 0 else 1)
