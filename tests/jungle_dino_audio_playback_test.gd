extends SceneTree
class Population extends Node3D:
	const State=preload("res://scripts/lol2/jungle_dino_population_state.gd")
	const Live=preload("res://scripts/lol2/creature_live_rules.gd")
	var packet:=State.initial()
	var bodies: Dictionary={}
	var clocks: Dictionary={}
	var active:=true
	func view() -> Dictionary: return packet
	func world_active() -> bool: return active
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var pop:=Population.new();root.add_child(pop)
	for id in pop.packet.actors:
		var body:=Node3D.new();pop.add_child(body);pop.bodies[id]=body;pop.clocks[id]=0.0
	var audio:=preload("res://scripts/lol2/jungle_dino_audio.gd").new()
	pop.add_child(audio);audio.setup(pop)
	pop.packet.live["21"].mode=pop.Live.ATTACK
	pop.packet.live["21"].elapsed=1.25
	audio.sync(0.0,true)
	assert(pop.packet.audio["21"].request==0) # Legacy restore suppresses past cues.
	audio.sync(0.0)
	assert(pop.packet.audio["21"].request==0)
	pop.packet.live["21"].elapsed=0.0;audio.sync(0.0)
	pop.packet.live["21"].elapsed=1.0;audio.sync(1.0)
	assert(pop.packet.audio["21"].request==978)
	assert(audio.players["21"].stream==audio.streams[978])
	assert(audio.players["22"].stream==null)
	pop.packet.live["21"].elapsed=1.25;audio.sync(0.25)
	await physics_frame
	await physics_frame
	var saved:=pop.packet.duplicate(true)
	pop.active=false;audio.pause()
	assert(audio.players["21"].stream_paused and pop.packet==saved)
	pop.packet.live["21"].elapsed=1.5;audio.sync(0.25)
	pop.packet=pop.State.canonical(JSON.parse_string(JSON.stringify(saved)))
	audio.sync(0.0,true)
	await physics_frame
	assert(pop.packet==saved and not audio.players["21"].playing)
	pop.active=true;audio.sync(0.0)
	assert(not audio.players["21"].stream_paused and pop.packet==saved)
	await physics_frame
	await physics_frame
	paused=true
	await process_frame
	await process_frame
	assert(audio.players["21"].stream_paused and pop.packet==saved)
	paused=false
	audio.sync(0.0)
	assert(not audio.players["21"].stream_paused and pop.packet==saved)
	pop.packet.live["22"].mode=pop.Live.PURSUE;pop.clocks["22"]=0.875
	audio.sync(0.0)
	assert(pop.packet.audio["22"].request==354)
	pop.clocks["23"]=0.75
	audio.sync(0.0)
	assert(pop.packet.audio["23"].pose==0 and pop.packet.audio["23"].time==0.75 and pop.packet.audio["23"].request==0)
	pop.clocks["23"]=0.0
	audio.sync(0.0,true)
	assert(pop.clocks["23"]==0.75)
	var walk_clock: float=pop.packet.audio["22"].time
	pop.clocks["22"]=0.0;audio.sync(0.0,true)
	assert(pop.clocks["22"]==walk_clock)
	print("PASS: 15 independent voices, legacy cue suppression, partial PCM restore, pause/resume and walk-clock restoration (headless)")
	for player in audio.players.values(): player.stop()
	await physics_frame
	pop.queue_free();await process_frame
	# Let the audio mixer retire stopped playback instances before engine shutdown.
	await create_timer(0.1).timeout
	quit()
