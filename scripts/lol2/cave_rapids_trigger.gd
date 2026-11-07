extends Node3D
## Original hit/group9976 -> prop518/group5074 -> prop453/group4076 chain.
## Source view-effect command is retained pending its active RNG/camera implementation.
const State=preload("res://scripts/lol2/cave_rapids_trigger_state.gd")
const Controls=preload("res://scripts/lol2/cave_rapids_control_state.gd")
const DURATION=142080.0/22050.0
var host: Node3D
var state:=State.initial()
var sound_time:=0.0
var view_effect_pending:=false
var voice: AudioStreamPlayer3D
var sound_starts:=0
static func initial_packet() -> Dictionary:
	return {"version":1,"state":State.initial(),"sound_time":0.0,"view_effect_pending":false}
static func validate_packet(value: Variant) -> String:
	if not value is Dictionary or value.size()!=4 or value.get("version")!=1:return "Invalid rapids trigger packet."
	var error:=State.validate(value.get("state"))
	if not error.is_empty():return error
	var time: Variant=value.get("sound_time")
	if not (time is int or time is float) or not is_finite(float(time)) or time<0 or time>DURATION+0.00000001:return "Invalid rapids sound clock."
	if not value.get("view_effect_pending") is bool:return "Invalid rapids view request."
	if State.released(value.state)!=bool(value.view_effect_pending):return "Rapids view receipt mismatch."
	if not State.released(value.state) and time!=0:return "Rapids sound precedes trigger."
	return ""
func setup(owner: Node3D) -> String:
	host=owner;name="CaveRapidsTrigger"
	var source:=Controls.source();var sound: Dictionary=source.sound379
	if FileAccess.get_sha256(sound.path)!=str(sound.wav_sha256):return "Rapids sound changed."
	voice=AudioStreamPlayer3D.new();voice.stream=AudioStreamWAV.load_from_file(sound.path)
	if voice.stream==null:return "Rapids sound did not load."
	var point: Array=source.prop453.placement.position
	voice.position=host.native_translation+Vector3(point[0],point[1],point[2])
	voice.unit_size=128;voice.max_distance=1400 # Godot attenuation adapter, not source command tail decoding.
	add_child(voice)
	host.rapids_controls.bodies["103"].set_meta("spark_receiver",self)
	return ""
func active() -> bool:return host.starting_magic!=null and host.starting_magic.world_active()
func receive_spark() -> bool:return receive_hit(1,1,8)
func receive_hit(mask0: int, mask2: int, amount: int) -> bool:
	if not active():return false
	var result:=State.hit(state,mask0,mask2,amount,int(host.cave_local7))
	if not result.accepted:return false
	if result.released:
		# Apply the admitted source command batch in this update. Native queue scheduling
		# between the two groups is not claimed; motion begins on the next world tick.
		host.guard_encounter.State.release_crossbow_definition(host.guard_encounter.state)
		host.rapids_controls.start()
		host.rapids_floors.start_material_motion()
		view_effect_pending=true;sound_time=0;voice.play();sound_starts+=1
	return true
func strike() -> bool:
	if not active() or int(state.hit_mode)!=0x81:return false
	var start: Vector3=host.camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(start,start-host.camera.global_basis.z*96.0,3,[host.player.get_rid()])
	var hit:=host.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider!=host.rapids_controls.bodies["103"]:return false
	return receive_hit(2,4,1) # Positive landed-hit adapter; source wildcard/threshold admission is exact.
func advance(delta: float, world_active: bool) -> void:
	voice.stream_paused=not world_active
	if not world_active or not is_finite(delta) or delta<=0 or not State.released(state) or sound_time>=DURATION:return
	sound_time=minf(DURATION,sound_time+delta)
	if sound_time>=DURATION:voice.stop()
func checkpoint() -> Dictionary:
	return {"version":1,"state":state.duplicate(true),"sound_time":sound_time,"view_effect_pending":view_effect_pending}
func restore(value: Variant) -> String:
	var error:=validate_packet(value)
	if not error.is_empty():return error
	state=State.canonical(value.state);sound_time=minf(DURATION,float(value.sound_time));view_effect_pending=bool(value.view_effect_pending)
	voice.stop()
	if State.released(state) and sound_time<DURATION:voice.play(sound_time)
	voice.stream_paused=not active()
	return ""
