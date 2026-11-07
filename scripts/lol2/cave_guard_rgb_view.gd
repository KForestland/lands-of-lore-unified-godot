extends Node
## RGB VQA composition after Cave palette resolution. Existing layer4 occluders
## supply real depth testing. Their reserved (64,64,0) output is removed; source
## preparation verifies that all decoded movie frames exclude this exact colour.
const MOVIE_LAYER:=128
var host: Node3D
var movie: Node3D
var view: SubViewport
var camera: Camera3D
var surface: TextureRect
func setup(owner_host: Node3D, owner_movie: Node3D) -> void:
	host=owner_host;movie=owner_movie;movie.picture.layers=MOVIE_LAYER
	view=SubViewport.new();view.world_3d=host.get_world_3d();view.transparent_bg=true;view.msaa_3d=Viewport.MSAA_DISABLED;view.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(view)
	camera=Camera3D.new();camera.cull_mask=4|MOVIE_LAYER;camera.environment=Environment.new();camera.environment.background_mode=Environment.BG_COLOR;camera.environment.background_color=Color(0,0,0,0);view.add_child(camera);camera.current=true
	surface=TextureRect.new();surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;surface.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;surface.texture=view.get_texture();host.resolve_surface.get_parent().add_child(surface)
	var shader:=Shader.new();shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ vec4 c=texture(TEXTURE,UV); if(all(lessThan(abs(c.rgb-vec3(64.0,64.0,0.0)/255.0),vec3(0.5/255.0)))) discard; COLOR=c; }"
	var material:=ShaderMaterial.new();material.shader=shader;surface.material=material
	_process(0)
func _process(_delta: float) -> void:
	if not is_instance_valid(movie):return
	var showing:=movie.is_visible_in_tree()
	surface.visible=showing
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	if not showing:return
	if view.size!=host.index_view.size:view.size=host.index_view.size
	surface.size=Vector2(host.get_window().size)
	camera.global_transform=host.camera.global_transform;camera.fov=host.camera.fov;camera.near=host.camera.near;camera.far=host.camera.far

func _exit_tree() -> void:
	if is_instance_valid(surface):surface.queue_free()
