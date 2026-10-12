extends Node3D
const State=preload("res://scripts/lol2/jungle_dino_audio_state.gd")
var population: Node3D
var players: Dictionary={}
var streams: Dictionary={}
func setup(owner_population: Node3D) -> void:
	population=owner_population
	process_mode=Node.PROCESS_MODE_ALWAYS
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_dino_audio/audio.json"))
	for id in data.clips:
		var clip: Dictionary=data.clips[id]
		assert(FileAccess.get_sha256(clip.path)==clip.wav_sha256)
		streams[int(id)]=AudioStreamWAV.load_from_file(clip.path)
	for id in population.bodies:
		var player:=AudioStreamPlayer3D.new()
		# Godot positional attenuation is provisional, not native mixing parity.
		player.unit_size=96;player.max_distance=600;player.max_db=0
		add_child(player);players[id]=player
func sync(delta: float, restoring: bool=false) -> void:
	var packet: Dictionary=population.view()
	var legacy:=not packet.has("audio")
	if legacy: packet.audio=State.initial()
	for id in players:
		var actor: Dictionary=packet.actors[id]
		var live: Dictionary=packet.live[id]
		var pose:=0
		var clock:=float(population.clocks[id])
		if actor.health==0:
			pose=8 if actor.death<population.State.DEATH_SECONDS else 9
			clock=float(actor.death) if pose==8 else 0.0
		elif live.mode==population.Live.ATTACK: pose=4;clock=float(live.elapsed)
		elif live.mode==population.Live.PURSUE: pose=1;clock=float(population.clocks[id])
		var v: Dictionary=packet.audio[id]
		if restoring:
			players[id].stop()
			if not legacy and pose in [0,1]: population.clocks[id]=float(v.time);clock=float(v.time)
			if legacy: v.pose=pose;v.time=snappedf(clock,1.0/1024)
		else: State.sample(v,pose,clock,delta)
		var player: AudioStreamPlayer3D=players[id]
		player.global_position=population.bodies[id].global_position
		var request:=int(v.request)
		var active: bool=request!=0 and int(v.elapsed)<int(State.SAMPLES[request])
		if not active: player.stop()
		elif suspended():
			# A paused restore must not enqueue a new voice before physics starts it.
			player.stream_paused=true
		else:
			var changed: bool=player.stream!=streams[request]
			if changed: player.stream=streams[request]
			if restoring or changed or not player.playing or absf(player.get_playback_position()-float(v.elapsed)/22050.0)>0.1: player.play(float(v.elapsed)/22050.0)
		player.pitch_scale=maxf(0.01,Engine.time_scale)
		player.stream_paused=suspended()
func pause() -> void:
	for player in players.values(): player.stream_paused=true

func suspended() -> bool:
	return get_tree().paused or Engine.time_scale<=0 or not population.world_active()

func _process(_delta: float) -> void:
	# Audio continues independently of a paused SceneTree; keep its gate alive.
	if is_instance_valid(population) and suspended(): pause()
