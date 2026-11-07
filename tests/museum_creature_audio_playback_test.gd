extends SceneTree
const Museum=preload("res://scripts/lol2/museum_skeleton_population_state.gd")
class Population extends Node3D:
	const State=preload("res://scripts/lol2/scripted_creature_state.gd")
	const Live=preload("res://scripts/lol2/creature_live_rules.gd")
	var src: Dictionary
	var state: Dictionary
	var bodies: Dictionary={}
	var clocks: Dictionary={}
	var running:=true
	func world_active() -> bool: return running
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var pop:=Population.new();pop.src=Museum.source();pop.state=Museum.initial();root.add_child(pop)
	for id in pop.state.actors:
		var body:=Node3D.new();pop.add_child(body);pop.bodies[id]=body;pop.clocks[id]=0.0
	var audio:=preload("res://scripts/lol2/scripted_creature_audio.gd").new();pop.add_child(audio)
	assert(audio.setup(pop,Museum.audio_contract(),"res://assets/lol2/generated/museum_creature_audio/audio.json").is_empty())
	assert(not pop.state.has("audio")) # Legacy read does not add a packet.
	audio.sync(0.0)
	assert(audio.players.size()==13 and pop.state.audio["21"].request==0 and pop.state.audio["24"].request==0)
	assert(Museum.wake(pop.state,"24"));audio.sync(0.0)
	assert(pop.state.audio["24"].request==989 and audio.players["24"].stream==audio.streams[989])
	assert(audio.players["25"].stream==null and audio.players["30"].stream==null)
	Museum.advance_clocks(pop.state,pop.src,0.25);audio.sync(0.25)
	assert(pop.state.audio["24"].sample==5513)
	var saved:=pop.state.duplicate(true)
	await physics_frame;await physics_frame
	paused=true;await process_frame;await process_frame
	assert(audio.players["24"].stream_paused and pop.state==saved)
	paused=false
	Museum.advance_clocks(pop.state,pop.src,0.25);audio.sync(0.25)
	pop.running=false
	pop.state=Museum.canonical(JSON.parse_string(JSON.stringify(saved)))
	audio.sync(0.0,true)
	assert(pop.state==saved and not audio.players["24"].playing)
	pop.running=true;audio.sync(0.0)
	assert(pop.state==saved and audio.players["24"].stream==audio.streams[989])
	# Death at frame8 selects the original skeldie1 clip; corpse never retriggers it.
	assert(Museum.damage(pop.state,pop.src,"24",999)>0);audio.sync(0.0)
	Museum.advance_clocks(pop.state,pop.src,1.0);audio.sync(1.0)
	assert(pop.state.audio["24"].request==988 and pop.state.audio["24"].sample==0)
	Museum.advance_clocks(pop.state,pop.src,2.0);audio.sync(2.0)
	assert(not audio.players["24"].playing)
	# Rat selector4 uses rat3, unlike skeleton selector4 footsteps.
	pop.state.live["22"].mode=pop.Live.ATTACK;pop.state.live["22"].elapsed=0.75
	audio.sync(0.0)
	assert(pop.state.audio["22"].request==652)
	# Restoring an old mid-attack packet suppresses already-passed cues.
	pop.state.erase("audio");audio.sync(0.0,true);audio.sync(0.0)
	assert(pop.state.audio["22"].request==0)
	# Walk-phase restoration uses the same saved cursor as the sound events.
	pop.state.actors["23"].woken=true;pop.state.actors["23"].rise=2.0
	pop.state.live["23"].mode=pop.Live.PURSUE;pop.clocks["23"]=0.625
	audio.sync(0.0)
	pop.clocks["23"]=0.0;audio.sync(0.0,true)
	assert(pop.clocks["23"]==0.625)
	pop.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: 13 independent voices; dormant/absent silence; rise/death/Rat cues; exact partial restore; tree/world pause; legacy suppression; walk cursor and teardown")
	quit()
