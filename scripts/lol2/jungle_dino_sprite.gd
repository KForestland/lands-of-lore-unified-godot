extends RefCounted
## Presentation only. Caller owns native selector, frame, view and world scale.
const ROOT="res://assets/lol2/generated/jungle_dino_sprites/"
const Values=preload("res://scripts/lol2/save_value_rules.gd")
var _states: Array=[]
var _textures: Dictionary={}
var _material: ShaderMaterial
var _palette: ImageTexture

func bind(sprite: MeshInstance3D, source_root: String=ROOT) -> String:
	if not is_instance_valid(sprite) or not sprite.mesh is QuadMesh or not sprite.material_override is ShaderMaterial: return "Invalid indexed DINO sprite."
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(source_root+"sprites.json"))
	if not manifest is Dictionary or manifest.get("version")!=1 or manifest.get("definition")!=4 or not manifest.get("states") is Array or manifest.states.size()!=11 or not manifest.get("frames") is Array: return "Invalid DINO manifest."
	if not manifest.get("palette") is Dictionary or manifest.palette.get("file")!="palette.png" or not manifest.palette.get("png_sha256") is String: return "Missing DINO source palette."
	var palette_path:=source_root+"palette.png"
	if FileAccess.get_sha256(palette_path)!=manifest.palette.png_sha256: return "DINO palette hash differs."
	var palette:=Image.load_from_file(palette_path)
	if palette==null or palette.get_size()!=Vector2i(256,1) or palette.get_format()!=Image.FORMAT_RGB8: return "Invalid DINO palette."
	var loaded: Dictionary={}
	for row in manifest.frames:
		if not row is Dictionary or not Values.integer(row.get("resource"),65535) or not row.get("file") is String or not row.get("png_sha256") is String: return "Invalid DINO frame record."
		var resource:=int(row.resource)
		if loaded.has(resource) or row.file!="frame_%d.png"%resource: return "Invalid DINO frame identity."
		var path:=source_root+str(row.file)
		if FileAccess.get_sha256(path)!=row.png_sha256: return "DINO frame hash differs."
		var picture:=Image.load_from_file(path)
		if picture==null or picture.get_size()!=Vector2i(320,200) or picture.get_format()!=Image.FORMAT_L8: return "Invalid DINO indexed canvas."
		var mirrored:=picture.duplicate()
		mirrored.flip_x()
		loaded[resource]=[ImageTexture.create_from_image(picture),ImageTexture.create_from_image(mirrored)]
	if loaded.size()!=133: return "Incomplete DINO frame library."
	var counts: Array=[12,14,14,12,14,14,11,13,12,1,12]
	for selector in range(11):
		var state=manifest.states[selector]
		if not state is Dictionary or state.get("selector")!=selector or not state.get("views") is Array or state.views.size()!=(8 if selector in [1,2] else 1): return "Invalid DINO selector."
		for slot in range(state.views.size()):
			var view=state.views[slot]
			if not view is Dictionary or view.get("slot")!=slot or not Values.integer(view.get("flags"),64) or int(view.flags) not in [0,64] or not view.get("frames") is Array or view.frames.size()!=counts[selector]: return "Invalid DINO view."
			for resource in view.frames:
				if not Values.integer(resource,65535) or not loaded.has(int(resource)): return "Missing DINO view frame."
	# Publish only after the complete library has validated.
	_states=manifest.states.duplicate(true);_textures=loaded
	_palette=ImageTexture.create_from_image(palette)
	_bind_material(sprite)
	return ""

func bind_shared(sprite: MeshInstance3D, library: RefCounted) -> String:
	if not is_instance_valid(sprite) or not sprite.mesh is QuadMesh or not sprite.material_override is ShaderMaterial: return "Invalid indexed DINO sprite."
	if library==null or library.get_script()!=get_script() or library._textures.size()!=133 or library._states.size()!=11 or library._palette==null: return "Missing validated DINO library."
	# These resources are immutable after validation. Each actor owns its material.
	_states=library._states
	_textures=library._textures
	_palette=library._palette
	_bind_material(sprite)
	return ""

func _bind_material(sprite: MeshInstance3D) -> void:
	_material=sprite.material_override.duplicate()
	_material.shader=preload("res://scripts/lol2/jungle_dino_sprite.gdshader")
	_material.set_shader_parameter("source_palette",_palette)
	sprite.material_override=_material

func present(selector: Variant, frame: Variant, view_slot: Variant=0) -> String:
	if _material==null: return "DINO sprite is not bound."
	if not Values.integer(selector,10) or not Values.integer(view_slot,7): return "Invalid DINO pose."
	var views: Array=_states[int(selector)].views
	var view: Dictionary=views[int(view_slot) if views.size()==8 else 0]
	if not Values.integer(frame,view.frames.size()-1): return "Invalid DINO frame."
	var texture: ImageTexture=_textures[int(view.frames[int(frame)])][1 if int(view.flags)==64 else 0]
	_material.set_shader_parameter("indices",texture)
	return ""
