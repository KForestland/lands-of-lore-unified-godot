extends SceneTree
const Binder = preload("res://scripts/lol2/act2_progression.gd")
const Light = preload("res://scripts/lol2/act2_sector_light.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL sector light: ",message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	Engine.set_meta("lol2_enhanced",false)
	for area in Light.AREAS:
		var scene = load(Binder.LEVEL_SCENES[int(area.get_slice("_",0).trim_prefix("L"))]).instantiate()
		root.add_child(scene)
		scene.set_physics_process(false); scene.player.set_physics_process(false)
		var lighting = scene.sector_lighting
		check(lighting != null and lighting.materials.size()>0, area+" attached")
		var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
		var sample: Dictionary = {}
		for face in pack.faces:
			if face.kind == "floor" and face.get("sector_light") is Array: sample=face; break
		check(not sample.is_empty(),area+" source sector")
		var raw: Array = sample.sector_light
		check(scene.static_face_light(sample)==Color(raw[0],raw[1],raw[2],raw[3]),area+" retains native sector operands")
		var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/sector_shades/%s.json"%area))
		check(rows.area==area and rows.rows.size()==64,area+" own palette table")
		var image: Image = lighting.rows_texture.get_image()
		check(image.get_pixel(30,0).is_equal_approx(Color(rows.rows[30][0],rows.rows[30][1],rows.rows[30][2])),area+" lookup value")
		for material in lighting.materials:
			check(material.get_shader_parameter("shade_rows")==lighting.rows_texture,area+" no L8 table leakage")
		# Actual animation binding must follow replacement textures after material conversion.
		var binding: Array = lighting.bindings[0]
		var texture := ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
		binding[0].albedo_texture=texture
		lighting._process(0.0)
		check(binding[1].get_shader_parameter("albedo")==texture,area+" animation texture follows")
		lighting.set_enabled(false)
		for material in lighting.materials: check(not bool(material.get_shader_parameter("night_enabled")),area+" reversible")
		scene.queue_free(); await process_frame
	if failures==0: print("PASS four Act2 maps source sector operands, own shade tables, animated textures and revert")
	quit(0 if failures==0 else 1)
