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
		instance.material_override = materials[str(int(record.descriptor))]
		instance.position = Vector3(record.position[0], record.position[1], record.position[2])
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
