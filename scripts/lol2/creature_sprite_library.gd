extends RefCounted
## Indexed creature frames from a multi-definition manifest (prepare_museum_creature_sprites.py).
## Presentation only: caller owns selector, frame, view, clocks and world scale.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
var root: String
var definitions: Dictionary={}
var textures: Dictionary={}
var palette: ImageTexture
## Texture chosen by the last present(); hosts with render copies mirror it.
var last_texture: Texture2D

func load_manifest(source_root: String) -> String:
	root=source_root
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(root+"sprites.json"))
	if not manifest is Dictionary or manifest.get("version")!=1 or not manifest.get("definitions") is Dictionary or not manifest.get("frames") is Array: return "Invalid creature manifest."
	if FileAccess.get_sha256(root+"palette.png")!=str(manifest.palette.png_sha256): return "Creature palette hash differs."
	var image:=Image.load_from_file(root+"palette.png")
	if image==null or image.get_size()!=Vector2i(256,1): return "Invalid creature palette."
	var loaded: Dictionary={}
	for row in manifest.frames:
		var path:=root+str(row.file)
		if FileAccess.get_sha256(path)!=str(row.png_sha256): return "Creature frame hash differs."
		var picture:=Image.load_from_file(path)
		if picture==null or picture.get_format()!=Image.FORMAT_L8: return "Invalid creature frame."
		var mirrored:=picture.duplicate();mirrored.flip_x()
		loaded[int(row.resource)]=[ImageTexture.create_from_image(picture),ImageTexture.create_from_image(mirrored),picture.get_size()]
	for key in manifest.definitions:
		for state in manifest.definitions[key].states:
			for view in state.views:
				for resource in view.frames:
					if not loaded.has(int(resource)) and int(resource) not in manifest.get("unsupported",[]).map(func(u):return int(u.resource)): return "Missing creature frame."
	definitions=manifest.definitions;textures=loaded
	palette=ImageTexture.create_from_image(image)
	return ""

## indexed=true uses the cave composite pipeline (index buffer + host palette).
func bind(mesh: MeshInstance3D, indexed: bool=false) -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	if indexed:
		material.shader=load("res://scripts/lol2/indexed_surface_review.gdshader")
		material.set_shader_parameter("sprite",true)
	else:
		material.shader=preload("res://scripts/lol2/jungle_dino_sprite.gdshader")
		material.set_shader_parameter("source_palette",palette)
	mesh.material_override=material
	return material

func view_count(definition: int, selector: int) -> int:
	return definitions[str(definition)].states[selector].views.size()

func frame_count(definition: int, selector: int) -> int:
	return definitions[str(definition)].states[selector].views[0].frames.size()

func present(material: ShaderMaterial, definition: int, selector: int, frame: int, view_slot: int=0) -> String:
	var defn=definitions.get(str(definition))
	if defn==null or selector<0 or selector>=defn.states.size(): return "Invalid creature pose."
	var views: Array=defn.states[selector].views
	var view: Dictionary=views[clampi(view_slot,0,views.size()-1)]
	var resource:=int(view.frames[clampi(frame,0,view.frames.size()-1)])
	if not textures.has(resource): return "Unsupported creature frame."
	last_texture=textures[resource][1 if int(view.flags)==64 else 0]
	material.set_shader_parameter("indices",last_texture)
	return ""
