extends Node3D
## Original VQA crop on its descriptor's640x400 canvas. Exact RGB matte shader.
## Source visibility admission remains caller-owned; Godot supplies depth occlusion.
var src: Dictionary
var frames: Array=[]
var voices: Array=[]
var picture: MeshInstance3D
var voice: AudioStreamPlayer3D
var material: ShaderMaterial
var current_selector: int=-1
var current_frame: int=-1
var camera: Camera3D
func setup(contract: Dictionary, view_camera: Camera3D, translation: Vector3) -> String:
	src=contract;camera=view_camera
	position=translation+Vector3(src.position[0],src.position[1],src.position[2])
	for clip in src.clips:
		var images: Array=[]
		for row in clip.frames:
			if FileAccess.get_sha256(row.file)!=str(row.sha256):return "Guard movie frame hash differs."
			images.append(ImageTexture.create_from_image(Image.load_from_file(row.file)))
		if FileAccess.get_sha256(clip.audio)!=str(clip.audio_sha256):return "Guard movie audio hash differs."
		var audio:=AudioStreamWAV.load_from_file(clip.audio)
		if audio==null:return "Guard movie audio failed to load."
		frames.append(images);voices.append(audio)
	var shader:=Shader.new();shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D frame_image:source_color,filter_nearest; uniform vec4 matte:source_color; void fragment(){ vec4 c=texture(frame_image,UV); if(distance(c.rgb,matte.rgb)<0.002) discard; ALBEDO=c.rgb; }"
	material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("matte",Color(0,251.0/255.0,251.0/255.0))
	picture=MeshInstance3D.new();picture.material_override=material;picture.layers=2;add_child(picture)
	voice=AudioStreamPlayer3D.new();voice.unit_size=160;voice.max_distance=1200;add_child(voice)
	visible=false
	return ""
func show_state(sequence: Dictionary, present: bool, active: bool, restoring: bool=false) -> void:
	visible=present and sequence.phase!="idle"
	if not visible:voice.stop();return
	var selector:=int(sequence.selector);var clip: Dictionary=src.clips[selector]
	if current_selector!=selector:
		current_selector=selector;current_frame=-1
		var quad:=QuadMesh.new();var crop: Dictionary=clip.crop
		quad.size=Vector2(float(crop.width)/clip.canvas[0]*src.dimensions[0],float(crop.height)/clip.canvas[1]*src.dimensions[1])
		quad.center_offset=Vector3((float(crop.x)+float(crop.width)/2)/clip.canvas[0]*src.dimensions[0]-float(src.dimensions[0])/2,float(src.dimensions[1])-(float(crop.y)+float(crop.height)/2)/clip.canvas[1]*src.dimensions[1],0)
		picture.mesh=quad;voice.stop();voice.stream=voices[selector]
	var frame:=mini(int(clip.count)-1,int(float(sequence.elapsed)*float(clip.fps)))
	if frame!=current_frame:current_frame=frame;material.set_shader_parameter("frame_image",frames[selector][frame])
	var to_camera: Vector3=camera.global_position-global_position
	picture.rotation.y=atan2(to_camera.x,to_camera.z)
	var audio_duration:=float(clip.audio_samples)/float(clip.audio_rate)
	if sequence.phase!="playing" or float(sequence.elapsed)>=audio_duration:voice.stop()
	elif active and (restoring or not voice.playing):voice.play(float(sequence.elapsed))
	voice.stream_paused=not active
func _exit_tree() -> void:
	if is_instance_valid(voice):voice.stop()
