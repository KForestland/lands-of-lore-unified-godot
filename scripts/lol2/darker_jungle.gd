extends "res://scripts/lol2/jungle_walkthrough.gd"
## Original L8_SJ terrain/initial scenery; the connected Act1 arrival.
const FORMAT := "lol2-restoration-darker-jungle"
const DEFAULT_PATH := "user://saves/darker_jungle_quicksave.json"
static func arrival_assets_ready() -> bool:
	var path := "res://assets/lol2/generated/darker_jungle/area.json"
	if not FileAccess.file_exists(path): return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("materials") is Dictionary: return false
	for file in data.materials.values():
		if not FileAccess.file_exists(path.get_base_dir()+"/"+file): return false
	return preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready()
func _ready() -> void:
	super._ready()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
	var prop_materials: Dictionary = {}
	for prop in data.props:
		var key: String = prop.material
		if not prop_materials.has(key):
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(geometry_file.get_base_dir()+"/"+data.materials[key]))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			prop_materials[key] = material
		var mesh := QuadMesh.new()
		mesh.size = Vector2(prop.right-prop.left,prop.top-prop.bottom)
		mesh.center_offset = Vector3((prop.left+prop.right)/2.0,(prop.bottom+prop.top)/2.0,0)
		mesh.material = prop_materials[key]
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.position = Vector3(prop.position[0],prop.position[1],prop.position[2])
		add_child(node)
	player.rotation.y = -PI/2
	if get_tree().has_meta("lol2_darker_handoff"):
		var error := apply_area_handoff(get_tree().get_meta("lol2_darker_handoff"))
		if error.is_empty(): get_tree().remove_meta("lol2_darker_handoff")
		else: push_error(error)
	if get_tree().has_meta("lol2_darker_resume"):
		var error := apply_save(get_tree().get_meta("lol2_darker_resume"))
		if error.is_empty(): get_tree().remove_meta("lol2_darker_resume")
		else: push_error(error)
