extends Node3D
## Audio owner for a scripted_creature_population; immutable source cue contract.
const AudioState=preload("res://scripts/lol2/scripted_creature_audio_state.gd")
var population: Node3D
var contract: Dictionary
var players: Dictionary={}
var streams: Dictionary={}
var voices: Dictionary={}
func setup(owner_population: Node3D, cue_contract: Dictionary, manifest_path: String) -> String:
	population=owner_population;contract=cue_contract
	process_mode=Node.PROCESS_MODE_ALWAYS
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary: return "Missing creature audio manifest."
	for id in contract.samples:
		var clip=manifest.get("clips",{}).get(id)
		if not clip is Dictionary or clip.samples!=contract.samples[id] or clip.rate!=contract.rate or FileAccess.get_sha256(clip.path)!=clip.wav_sha256: return "Creature audio source differs."
		var stream:=AudioStreamWAV.load_from_file(clip.path)
		if stream==null: return "Cannot load creature audio."
		streams[int(id)]=stream
	for id in population.bodies:
		var player:=AudioStreamPlayer3D.new()
		# Modern attenuation and one interruptible voice per actor, not native mixing.
		player.unit_size=96;player.max_distance=600;player.max_db=0
		add_child(player);players[id]=player
	sync(0.0,true)
	return ""
func pose(id: String) -> Dictionary:
	var actor: Dictionary=population.state.actors[id]
	var live: Dictionary=population.state.live[id]
	var definition:=str(int(population.State.actor_row(population.src,id).definition))
	var clips: Dictionary=population.src.definitions[definition].clips
	var result: Dictionary={"definition":definition,"selector":-1,"time":0.0,"loop":0.0}
	if not actor.present: return result
	if actor.health<=0:
		result.selector=int(clips.death.selector) if actor.death<float(clips.death.frames)/population.State.FPS else int(clips.corpse.selector)
		result.time=float(actor.death) if result.selector==int(clips.death.selector) else 0.0
	elif not actor.woken: return result
	elif not population.State.ready_to_fight(population.state,population.src,id):
		result.selector=int(clips.rise.selector);result.time=maxf(0.0,float(actor.rise))
	elif live.mode==population.Live.ATTACK:
		result.selector=int(clips.attacks[int(live.attack)].selector);result.time=float(live.elapsed)
	elif live.mode==population.Live.PURSUE:
		result.selector=int(clips.walk.selector);result.time=float(population.clocks[id]);result.loop=float(clips.walk.frames)/population.State.FPS
	else: result.selector=int(clips.idle.selector)
	return result
func sync(delta: float, restoring: bool=false) -> void:
	var legacy: bool=not population.state.has("audio")
	if restoring: voices=AudioState.initial(population.src.actors) if legacy else population.state.audio
	elif not legacy: voices=population.state.audio
	for id in players:
		var player: AudioStreamPlayer3D=players[id]
		var p:=pose(id)
		var v: Dictionary=voices[id]
		if restoring:
			player.stop()
			if legacy: v.selector=int(p.selector);v.time=snappedf(float(p.time),1.0/1024)
			elif p.loop>0 and int(v.selector)==int(p.selector): population.clocks[id]=float(v.time);p.time=float(v.time)
		else:
			var cues: Array=[] if p.selector<0 else contract.definitions[p.definition][str(int(p.selector))].cues
			AudioState.advance(v,int(p.selector),float(p.time),delta,cues,float(p.loop),population.State.FPS,contract)
		# Dormant/absent owners never emit or retain a voice.
		if p.selector<0:
			if not restoring: v.request=0;v.sample=0
			player.stop();continue
		player.global_position=population.bodies[id].global_position
		var request:=int(v.request)
		var active: bool=request!=0 and int(v.sample)<int(contract.samples[str(request)])
		if not active: player.stop()
		elif suspended(): player.stream_paused=true
		else:
			var changed: bool=player.stream!=streams[request]
			if changed: player.stream=streams[request]
			var seconds:=float(v.sample)/float(contract.rate)
			if restoring or changed or not player.playing or absf(player.get_playback_position()-seconds)>0.1: player.play(seconds)
		player.pitch_scale=maxf(0.01,Engine.time_scale)
		player.stream_paused=suspended()
	if not restoring: population.state.audio=voices
func suspended() -> bool:
	return get_tree().paused or Engine.time_scale<=0 or not population.world_active()
func pause() -> void:
	for player in players.values(): player.stream_paused=true
func _process(_delta: float) -> void:
	if is_instance_valid(population) and suspended(): pause()
func _exit_tree() -> void:
	for player in players.values():
		if is_instance_valid(player): player.stop()
