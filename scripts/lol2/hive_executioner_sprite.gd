extends RefCounted
## Presentation only: displays supplied pose/frame without advancing combat time.
const ROOT := "res://assets/lol2/generated/hive_executioner_sprites/"
const Numbers = preload("res://scripts/lol2/save_value_rules.gd")
var _clips: Dictionary = {}
var _material: StandardMaterial3D
var _mesh: QuadMesh
var _base_size: Vector2
var _base_center: Vector3
var _reference_canvas := Vector2(320,200)

func bind(sprite: MeshInstance3D, source_root: String=ROOT, expected: Dictionary={}, reference_canvas: Vector2=Vector2(320,200)) -> String:
	if not is_instance_valid(sprite) or not sprite.material_override is StandardMaterial3D or not sprite.mesh is QuadMesh: return "Invalid executioner sprite."
	if not reference_canvas.is_finite() or reference_canvas.x<=0 or reference_canvas.y<=0: return "Invalid source reference canvas."
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(source_root+"sprites.json"))
	if not manifest is Dictionary or manifest.get("version") != 1 or not manifest.get("clips") is Array: return "Missing executioner sprite manifest."
	if expected.is_empty():
		for selector in [0,2,11,12,17,18,19,20]: expected[selector]={"frames":{0:16,2:16,11:18,12:17,17:19,18:9,19:1,20:1}[selector],"height":240 if selector in [19,20] else 200}
	var loaded := {}
	for clip in manifest.clips:
		if not expected.has(int(clip.selector)): continue
		var picture := Image.load_from_file(source_root+clip.file)
		if picture == null or picture.is_empty(): return "Missing executioner sprite image."
		var width := int(clip.get("width",320))
		var height := int(clip.get("height",200))
		if width!=int(expected[int(clip.selector)].get("width",320)) or height!=int(expected[int(clip.selector)].height): return "Invalid executioner canvas size."
		if picture.get_width() != int(clip.columns)*width or picture.get_height() != ceili(float(clip.frames)/float(clip.columns))*height: return "Invalid executioner atlas size."
		loaded[int(clip.selector)] = {"texture":ImageTexture.create_from_image(picture),"frames":int(clip.frames),"columns":int(clip.columns),"width":width,"height":height}
	for selector in expected:
		if not loaded.has(selector) or loaded[selector].frames!=int(expected[selector].frames): return "Invalid source frame count."
	_clips = loaded
	_material = sprite.material_override.duplicate()
	sprite.material_override = _material
	_mesh = sprite.mesh.duplicate()
	_base_size = _mesh.size
	_base_center = _mesh.center_offset
	_reference_canvas = reference_canvas
	sprite.mesh = _mesh
	return ""

func present(checkpoint: Variant) -> String:
	if _material == null: return "Executioner sprite is not bound."
	if not checkpoint is Dictionary or not Numbers.integer(checkpoint.get("pose"),255): return "Invalid executioner visual pose."
	var pose := int(checkpoint.pose)
	if not _clips.has(pose): return "Unsupported executioner visual pose."
	var frame := 0
	if pose in [11,12]:
		if not checkpoint.get("attack") is Dictionary or checkpoint.attack.get("selector") != pose or not Numbers.integer(checkpoint.attack.get("frame"),_clips[pose].frames-1): return "Invalid executioner visual frame."
		frame = int(checkpoint.attack.frame)
	elif checkpoint.has("source_pose"):
		if not checkpoint.source_pose is Dictionary or checkpoint.source_pose.get("selector")!=pose or not Numbers.integer(checkpoint.source_pose.get("frame"),_clips[pose].frames-1): return "Invalid source pose visual frame."
		frame = int(checkpoint.source_pose.frame)
	var clip: Dictionary = _clips[pose]
	var size: Vector2 = clip.texture.get_size()
	_material.albedo_texture = clip.texture
	_material.uv1_scale = Vector3(float(clip.width)/size.x,float(clip.height)/size.y,1)
	_material.uv1_offset = Vector3(float(frame%clip.columns)*clip.width/size.x,float(frame/clip.columns)*clip.height/size.y,0)
	# Preserve source pixel aspect and the existing preview's bottom anchor.
	_mesh.size = _base_size*Vector2(float(clip.width)/_reference_canvas.x,float(clip.height)/_reference_canvas.y)
	_mesh.center_offset = _base_center+Vector3(0,(_mesh.size.y-_base_size.y)*0.5,0)
	return ""
