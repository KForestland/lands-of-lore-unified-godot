extends Node3D
## Static source candidates. Billboarding/alpha are review conventions.
const ROOT := "res://assets/lol2/generated/museum_props/"
@export var asset_root := ROOT
var records: Array = []
var animations: Array = []
var animation_time := 0.0
var instances: Array[MeshInstance3D] = []
func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(asset_root + "props.json"))
	records = data.props
	var materials: Dictionary = {}
	for key in data.images:
		var material := StandardMaterial3D.new()
		material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(asset_root + data.images[key].file))
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		materials[key] = material
		if data.images[key].has("frames"):
			var textures: Array[Texture2D] = []
			for frame in data.images[key].frames:
				textures.append(ImageTexture.create_from_image(Image.load_from_file(asset_root + frame.file)))
			animations.append({"material": material, "textures": textures, "fps": float(data.images[key].preview_fps), "frame": 0})
	for record in records:
		var instance := MeshInstance3D.new()
		instance.name = "MuseumProp_%d" % int(record.record)
		var quad := QuadMesh.new()
		quad.size = Vector2(record.right - record.left, record.top - record.bottom)
		quad.center_offset = Vector3((record.right + record.left) / 2.0, (record.top + record.bottom) / 2.0, 0)
		instance.mesh = quad
		var material: StandardMaterial3D = materials[str(int(record.descriptor))]
		# Native 129AC8 frame setup (special_placed_prop_review.gd, hive_jungle_scenery.gd): frame flag 0x40 reverses the
		# columns and 0x80 the rows. Flipped records get their own copy of the shared material (owner r12q 09-27-28: the
		# ceiling dust props, flag 0x80). The row flip stays. Flag 0x80 lies flat and drops the billboard.
		var flags := int(record.get("frame_flags", 0)) & 0xC0
		if flags != 0:
			var key := "%d|%d" % [int(record.descriptor), flags]
			if not materials.has(key):
				var flipped: StandardMaterial3D = material.duplicate()
				flipped.uv1_scale = Vector3(-1.0 if flags & 0x40 else 1.0, -1.0 if flags & 0x80 else 1.0, 1.0)
				flipped.uv1_offset = Vector3(1.0 if flags & 0x40 else 0.0, 1.0 if flags & 0x80 else 0.0, 0.0)
				if flags & 0x80: flipped.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
				materials[key] = flipped
				for animation in animations:
					if animation.material == material: animations.append({"material": flipped, "textures": animation.textures, "fps": animation.fps, "frame": 0}); break
			material = materials[key]
		instance.material_override = material
		instance.position = Vector3(record.position[0], record.position[1], record.position[2])
		if flags & 0x80: instance.rotation.x = -PI / 2.0
		instance.set_meta("source_record", int(record.record))
		add_child(instance)
		instances.append(instance)

func _process(delta: float) -> void:
	animation_time += delta
	for animation in animations:
		var frame: int = int(animation_time * animation.fps) % animation.textures.size()
		if frame != animation.frame:
			animation.material.albedo_texture = animation.textures[frame]
			animation.frame = frame
