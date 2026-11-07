extends Node3D
## Original prop214/template29. 60Hz clock conversion follows existing restoration adapters;
## native producer rate remains untraced. Billboard, E aim and spatial mixing are modern adapters.
const State=preload("res://scripts/lol2/museum_belial_state.gd")
const ROOT="res://assets/lol2/generated/museum_belial/"
const DURATIONS=[199936.0/22050.0,11774.0/22050.0]
var host: Node3D
var state: Dictionary=State.initial()
var clocks: Array=[-1.0,-1.0]
var sounds: Array[AudioStreamPlayer3D]=[]
var display: MeshInstance3D
var material: StandardMaterial3D
var textures: Array[ImageTexture]=[]
var last_frame: int=-1
var last_phase: String=""
static func validate(value: Variant) -> String:
	if value==null:return ""
	if not value is Dictionary or value.size()!=3 or value.get("version")!=1 or not value.get("sounds") is Array or value.sounds.size()!=2:return "Invalid Belial exhibit checkpoint."
	var error:=State.validate(value.get("animation"))
	if not error.is_empty() or value.get("animation")==null:return "Invalid Belial animation."
	for i in range(2):
		var elapsed=value.sounds[i]
		if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or (elapsed!=-1 and (elapsed<0 or elapsed>DURATIONS[i])):return "Invalid Belial sound time."
	if value.animation.phase=="idle" and value.sounds!=[-1.0,-1.0]:
		if value.sounds[0]!=-1 or value.sounds[1]!=-1:return "Idle Belial has active sound."
	if value.animation.phase!="gone" and value.sounds[1]!=-1:return "Belial completion sound precedes completion."
	return ""
func setup(owner: Node3D,saved: Variant=null) -> String:
	host=owner;name="MuseumBelial"
	for base in [970,1009]:textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT+"atlas_%d.png"%base)))
	display=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(255,159);quad.center_offset=Vector3(0,79.5,0)
	display.mesh=quad;display.position=Vector3(347,-50,-3423)
	material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	display.material_override=material;add_child(display)
	for request in [1176,1175]:
		var sound:=AudioStreamPlayer3D.new();sound.stream=AudioStreamWAV.load_from_file(ROOT+"%d.wav"%request)
		# Both op20 commands target control102, not prop214: its property16 must not stop these cues.
		sound.position=Vector3(345,-10,-3255);sound.unit_size=180;add_child(sound);sounds.append(sound)
	return restore(saved)
func checkpoint() -> Dictionary:return {"version":1,"animation":state.duplicate(true),"sounds":clocks.duplicate()}
func restore(value: Variant) -> String:
	var error:=validate(value)
	if not error.is_empty():return error
	state=State.initial() if value==null else value.animation.duplicate(true)
	clocks=[-1.0,-1.0] if value==null else value.sounds.duplicate()
	for i in range(2):
		sounds[i].stop()
		if clocks[i]>=0 and clocks[i]<DURATIONS[i]:sounds[i].play(float(clocks[i]))
	last_frame=-1;last_phase="";present();return ""
func active() -> bool:
	return is_instance_valid(host.starting_magic) and host.starting_magic.world_active() and not get_tree().paused and host.introduction_state=="complete" and not host.flying
func target() -> bool:
	return active() and state.phase!="gone" and host.hand_item=="" and host.can_reach_item(Vector3(347,29.5,-3423))
func interaction_hint() -> String:return "E — Touch the figure" if target() else ""
func use() -> bool:
	if not target() or not State.use(state):return false
	clocks[0]=0.0;sounds[0].play();present();return true
func _physics_process(delta: float) -> void:
	var running:=active()
	for sound in sounds:sound.stream_paused=not running
	if not running:return
	for i in range(2):
		if clocks[i]>=0:clocks[i]=minf(DURATIONS[i],float(clocks[i])+delta)
	if State.advance_units(state,delta*60.0*256.0):
		clocks[1]=0.0;sounds[1].play()
	present()
func present() -> void:
	display.visible=state.phase!="gone"
	if last_frame==int(state.frame) and last_phase==state.phase:return
	last_frame=int(state.frame);last_phase=state.phase
	var selector:=0 if state.phase=="idle" else 1
	var rows:=5 if selector==0 else 8
	material.albedo_texture=textures[selector]
	material.uv1_scale=Vector3(1.0/8,1.0/rows,1)
	material.uv1_offset=Vector3((int(state.frame)%8)/8.0,(int(state.frame)/8)/float(rows),0)
