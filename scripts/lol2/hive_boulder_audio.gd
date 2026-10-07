extends Node3D
## Original cues and owner lifecycle with saved PCM clocks.
## Godot panning/voice mixing and host scheduling are explicit audio adapters.
const State=preload("res://scripts/lol2/hive_boulder_audio_state.gd")
const REQUESTS={"close":"704","exit":"701","30":"709","31":"709"}
var host: Node3D
var state:=State.initial()
var players: Dictionary={}
var started: Dictionary={}
var previous_surface: Dictionary
var data: Dictionary
func _ready() -> void:
	host=get_parent()
	data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_boulder_audio/audio.json"))
	for key in REQUESTS:
		var player:=AudioStreamPlayer3D.new()
		var clip: Dictionary=data.clips[REQUESTS[key]]
		var stream:=AudioStreamWAV.load_from_file(clip.path)
		assert(stream!=null and absf(stream.get_length()-State.LENGTHS[key])<0.000001)
		if key in ["30","31"]:
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_end=int(clip.samples)
		player.stream=stream
		player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED
		player.max_db=0.0
		player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(player)
		players[key]=player
	previous_surface=host.boulder_surfaces.checkpoint()
	process_mode=Node.PROCESS_MODE_ALWAYS
	# Added after surfaces and actors: consume their completed physics update.
func checkpoint() -> Dictionary:
	return state.duplicate(true)
func restore(value: Variant) -> String:
	var error:=State.validate(value)
	if not error.is_empty(): return error
	state=State.canonical(value)
	previous_surface=host.boulder_surfaces.checkpoint()
	for player in players.values(): player.stop()
	started.clear()
	present(true)
	return ""
func suspended() -> bool:
	var conversation=host.get_node("ConversationReview")
	return Engine.time_scale<=0 or get_tree().paused or host.flying or host.get_node("Warriors").health==0 or (conversation.started and not conversation.completed)
func _process(_delta: float) -> void:
	for player in players.values(): player.stream_paused=suspended()
func _physics_process(delta: float) -> void:
	if suspended() or not is_finite(delta) or delta<=0: return
	var current: Dictionary=host.boulder_surfaces.checkpoint()
	State.advance(state,previous_surface,current,host.boulders.state,delta)
	previous_surface=current
	present()
func present(force: bool=false) -> void:
	for key in REQUESTS:
		var player: AudioStreamPlayer3D=players[key]
		var rolling: bool=key in ["30","31"]
		if rolling: player.position=host.boulders.bodies[key].position
		else:
			var p: Array=data.positions["234" if key=="close" else "77"]
			player.position=Vector3(p[0],p[1],p[2])
		# Native approximate distance/fade, followed by Godot volume/pan adapters.
		var near_distance:=48 if rolling else 192
		var far_distance:=144 if rolling else 288
		var difference: Vector3=player.position-host.player.position
		var native_delta:=Vector3(difference.x,-difference.z,difference.y)
		var gain:=float(State.spatial_factor(native_delta,near_distance,far_distance))/255.0*(1.0 if rolling else 150.0/255.0)
		player.volume_db=linear_to_db(maxf(gain,0.0001))
		player.pitch_scale=maxf(0.01,Engine.time_scale)
		if not State.active(state,key):
			if player.playing: player.stop()
			if rolling: started.erase(key)
			elif state.clocks[key]>=0: started[key]=true
		elif force or not started.get(key,false) or (rolling and not player.playing):
			player.play(float(state.clocks[key]))
			started[key]=true
		elif player.playing and State.drift(key,player.get_playback_position(),float(state.clocks[key]))>0.1:
			player.seek(float(state.clocks[key]))
		player.stream_paused=suspended()
