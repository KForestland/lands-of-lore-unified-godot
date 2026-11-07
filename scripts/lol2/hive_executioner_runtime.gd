extends RefCounted
## Owns source, attack and outcome frames. Live admission is external.
const OutcomeRuntime = preload("res://scripts/lol2/hive_outcome_pose_runtime.gd")
const OutcomeTransition = preload("res://scripts/lol2/hive_outcome_transition.gd")
const OutcomeLookup = preload("res://scripts/lol2/hive_outcome_lookup.gd")
const OutcomePreparation = preload("res://scripts/lol2/hive_outcome_preparation.gd")
const PlayerEntry = preload("res://scripts/lol2/hive_player_damage_entry.gd")
const Health = preload("res://scripts/lol2/hive_player_health_adjustment.gd")
const Damage = preload("res://scripts/lol2/hive_damage_preparation.gd")
const PoseRuntime = preload("res://scripts/lol2/hive_source_pose_runtime.gd")
const AnimationContext = preload("res://scripts/lol2/hive_ai_animation_context.gd")
const GoalChoice = preload("res://scripts/lol2/hive_ai_goal_choice.gd")
const Choice = preload("res://scripts/lol2/hive_ai_action_choice.gd")
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
const Bridge = preload("res://scripts/lol2/hive_executioner_action.gd")
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
var _attack = Attack.new()
var _pose_runtime = PoseRuntime.new()
var _actor: Dictionary = {}
var _player_damage: Dictionary = {}
var _busy := false
var _pose := -1
var _choice: RefCounted
var _goal_choice: RefCounted
var _perception_definition: Dictionary = {}

func checkpoint() -> Dictionary:
	if _busy or _actor.is_empty(): return {}
	var saved := {"version":3,"pose":_pose,"actor":_actor.duplicate(true),"attack":_attack.checkpoint(),"source_pose":_pose_runtime.checkpoint() if _pose not in [11,12] else {}}
	if not _player_damage.is_empty(): saved.player_damage = _player_damage.duplicate(true)
	return saved

func restore(saved: Variant) -> String:
	if _busy: return "Cannot restore during executioner callbacks."
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),3) or saved.version < 1: return "Invalid executioner checkpoint."
	if not saved.get("actor") is Dictionary: return "Invalid executioner actor."
	var actor: Dictionary = saved.actor
	for field in ["flags16","flags17","state25","word7c"]:
		if actor.has(field) and not Numbers._integer(actor[field],65535 if field=="word7c" else 255): return "Invalid actor command field: "+field
	for field in ["byte91","word70","a7"]:
		if actor.has(field) and not Numbers._integer(actor[field],0xffffffff if field=="word70" else 255): return "Invalid actor hit field: "+field
	if actor.has("b0") and not Numbers._integer(actor.b0,65535): return "Invalid actor maximum health word."
	if actor.has("word6c") and not Numbers._integer(actor.word6c,4294967295): return "Invalid actor perception threshold value."
	for field in ["byte9c","byte9e","byte51","byte52","byte5a","byte5f","byte60","byte61"]:
		if actor.has(field) and not Numbers._integer(actor[field],255): return "Invalid actor perception field: "+field
	for field in ["ac","ad","b4","b5","b7","b9"]:
		if not Numbers._integer(actor.get(field),255): return "Invalid actor field: "+field
	if not Numbers._integer(actor.get("target"),4294967295): return "Invalid executioner target."
	for field in ["id","a0","word84","stats","next_actor"]:
		if actor.has(field):
			var preparation_error: String = OutcomePreparation.validate_actor(actor)
			if not preparation_error.is_empty(): return preparation_error
			if int(actor.id)!=36: return "Outcome actor is not the Hive executioner."
			break
	for field in ["flags14","flags15","ae","b6","health"]:
		if actor.has(field):
			var outcome_error: String = OutcomeTransition._validate(actor)
			if not outcome_error.is_empty(): return outcome_error
			break
	for field in ["a8","a9","aa","ab","b8","ba","bb"]:
		if actor.has(field):
			var ai_error: String = Choice.validate_ai_state(actor)
			if not ai_error.is_empty(): return ai_error
			break
	var error: String = _attack.validate(saved.get("attack"))
	if not error.is_empty(): return error
	var stream: Dictionary = saved.attack
	var pose: Variant = saved.get("pose") if int(saved.version) >= 2 else stream.selector
	if not Numbers._integer(pose,20) or int(pose) not in [0,2,11,12,17,18,19,20]: return "Invalid executioner pose."
	if int(pose) in [17,18,19,20] and int(saved.version)<3: return "Outcome pose requires explicit progress."
	if int(pose) in [11,12] and int(pose) != int(stream.selector): return "Pose and attack selector disagree."
	if int(pose) not in [11,12] and (int(stream.frame) != 0 or int(stream.timer) != 0): return "Non-attack pose has active attack progress."
	if int(stream.version) != 2: return "Executioner owner requires explicit feedback counters."
	if int(actor.b7) != int(stream.flags) or int(actor.ad) != int(stream.result_count) or ((int(actor.b4)&8) != 0) != stream.reverse or ((int(actor.b5)&2) != 0) != stream.frozen:
		return "Actor and attack state disagree."
	var player_damage: Dictionary = {}
	if saved.has("player_damage"):
		var checked := _checked_player_damage(saved.player_damage)
		if checked.has("error"): return checked.error
		player_damage = checked.state
	var pose_runtime = OutcomeRuntime.new() if int(pose) in [17,18,19,20] else PoseRuntime.new()
	if int(pose) not in [11,12]:
		var progress: Variant = saved.get("source_pose") if int(saved.version)==3 else {"selector":int(pose),"frame":0,"timer":0}
		error = pose_runtime.restore(progress)
		if not error.is_empty(): return error
		if int(progress.selector)!=int(pose): return "Source pose and animation disagree."
	elif int(saved.version)==3 and (not saved.get("source_pose") is Dictionary or not saved.source_pose.is_empty()):
		return "Active attack has unexpected source pose progress."
	error = _attack.restore(stream)
	if not error.is_empty(): return error
	_player_damage = player_damage
	_pose_runtime = pose_runtime
	_pose = int(pose)
	_actor = actor.duplicate(true)
	if actor.has("word6c"): _actor.word6c=int(actor.word6c)
	for field in ["byte9c","byte9e","byte51","byte52","byte5a","byte5f","byte60","byte61"]:
		if actor.has(field): _actor[field]=int(actor[field])
	for field in ["ac","ad","b4","b5","b7","b9","target","a8","a9","aa","ab","b8","ba","bb","flags14","flags15","ae","b6","health"]:
		if actor.has(field): _actor[field] = int(actor[field])
	for field in ["id","a0","word84","b0","flags16","flags17","state25","word7c","byte91","word70","a7","byte9e"]:
		if actor.has(field): _actor[field]=int(actor[field])
	if actor.has("stats"):
		_actor.stats=Attack.apply_stat_adjustments(actor.stats,{},[]).stats
		for i in range(30): _actor.stats[i]=int(_actor.stats[i])
	if actor.get("next_actor")!=null: _actor.next_actor=int(actor.next_actor)
	return ""

func begin_outcome(world: Variant, context: Variant, helpers: Dictionary) -> Dictionary:
	# Returns the updated world for the controller to commit alongside this owner.
	# Helpers must stage external effects; no world input is mutated in place.
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var prepared := OutcomePreparation.run(_actor,world)
	if prepared.has("error"): return prepared
	var candidate := checkpoint()
	candidate.actor=prepared.state
	candidate.attack.reverse=(int(prepared.state.b4)&8)!=0
	var provisional = get_script().new()
	var error: String = provisional.restore(candidate)
	if not error.is_empty(): return {"error":error}
	var result: Dictionary = {"checkpoint":candidate,"selections":[],"state":prepared.state}
	if not prepared.already:
		_busy=true
		result=provisional.finish_outcome_preparation(context,helpers)
		_busy=false
		if result.has("error"): return result
	error=restore(provisional.checkpoint())
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":checkpoint(),"state":_actor.duplicate(true),"world":prepared.world,
		"adjustments":prepared.adjustments,"already":prepared.already,"selections":result.selections}

func finish_outcome_preparation(context: Variant, helpers: Dictionary) -> Dictionary:
	# Caller has completed A7544 world/group preparation. External callbacks
	# stage effects; only the fully validated actor/animation result is committed.
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if not helpers.get("random") is Callable or not helpers.random.is_valid(): return {"error":"Missing outcome random source."}
	var candidate := checkpoint()
	var selections: Array = []
	var failures: Array[String] = []
	var hooks := helpers.duplicate()
	hooks.lookup = func(state,action,variant):
		var selected := OutcomeLookup.select(state,action,variant,helpers.get("random",Callable()))
		if selected.has("error"):
			failures.append(selected.error);return -2
		return selected.selector
	hooks.start = func(_state,selector,flags):
		if flags!=0 or selector not in [17,18,19,20]: return {"error":"Invalid executioner outcome start."}
		var changed: bool = int(candidate.pose)!=selector
		if changed:
			candidate.pose=selector
			candidate.source_pose={"selector":selector,"frame":0,"timer":0}
			candidate.attack.frame=0;candidate.attack.timer=0
		selections.append({"selector":selector,"changed":changed})
		return {}
	_busy=true
	var result := OutcomeTransition.run(_actor,context,hooks)
	_busy=false
	if result.has("error"):
		if not failures.is_empty(): result.error=failures[0]
		return result
	if not Numbers._integer(result.state.get("ad"),255): return {"error":"Invalid outcome feedback counter."}
	candidate.actor=result.state
	candidate.attack.flags=int(result.state.b7)
	candidate.attack.result_count=int(result.state.ad)
	candidate.attack.reverse=(int(result.state.b4)&8)!=0
	candidate.attack.frozen=(int(result.state.b5)&2)!=0
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	return {"state":_actor.duplicate(true),"selections":selections,"checkpoint":checkpoint()}

func decide(context: Variant, helpers: Dictionary) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if _pose in [17,18,19,20]: return {"error":"Outcome pose requires outcome admission."}
	if _actor.has("aa") and int(_actor.aa) != 2: return {"error":"Current AI action does not admit an attack decision."}
	var before: Dictionary = _attack.checkpoint()
	_busy = true
	var result := Bridge.run(_actor,context,helpers,_attack,_pose if _pose in [0,2] else -1)
	if not result.has("error"):
		_actor = result.state.duplicate(true)
		if not result.selections.is_empty(): _pose = int(result.selections.back().selector)
	else:
		_attack.restore(before)
	_busy = false
	return result

func advance(delta: Variant, feedback: Callable = Callable()) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if not Numbers._integer(delta,32767): return {"error":"Invalid native attack delta."}
	if _pose not in [11,12]: return _pose_runtime.advance(delta,_actor.b4,_actor.b5)
	_busy = true
	var result: Dictionary = _attack.advance_native(delta,feedback)
	if not result.has("error"):
		var stream: Dictionary = _attack.checkpoint()
		_actor.b7 = stream.flags
		_actor.ad = stream.result_count
	_busy = false
	return result

func initialize_pose(actor: Variant, pose: Variant, base: Variant, gate: Variant, feedback_total: Variant) -> String:
	if not actor is Dictionary or not Numbers._integer(pose,2) or int(pose) not in [0,2]: return "Invalid source pose."
	if not Numbers._integer(base,255) or not gate is bool or not Numbers._integer(feedback_total,65535): return "Invalid supplied combat context."
	for field in ["b4","b5","b7","ad"]:
		if not Numbers._integer(actor.get(field),255): return "Invalid actor field: "+field
	var stream: Dictionary = Attack.new().checkpoint()
	stream.base = int(base);stream.gate = gate;stream.result_total = int(feedback_total)
	stream.flags = int(actor.b7);stream.result_count = int(actor.ad)
	stream.reverse = (int(actor.b4)&8) != 0;stream.frozen = (int(actor.b5)&2) != 0
	return restore({"version":2,"pose":int(pose),"actor":actor,"attack":stream})

func choose_pending_action(stats: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var error: String = Choice.validate_ai_state(_actor)
	if not error.is_empty(): return {"error":error}
	if _choice == null:
		var choice := Choice.new()
		error = choice.configure_source()
		if not error.is_empty(): return {"error":error}
		_choice = choice
	var result: Dictionary = _choice.update_pending(_actor,stats)
	if not result.has("error"): _actor = result.state.duplicate(true)
	return result

func commit_ai_decision(mode: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var result: Dictionary = Choice.commit_postdecision(_actor,mode)
	if not result.has("error"): _actor = result.state.duplicate(true)
	return result

func choose_pending_ai(stats: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var error: String = Choice.validate_ai_state(_actor)
	if not error.is_empty(): return {"error":error}
	if _goal_choice == null:
		var chooser := GoalChoice.new()
		error = chooser.configure_source()
		if not error.is_empty(): return {"error":error}
		_goal_choice = chooser
	if _choice == null:
		var chooser := Choice.new()
		error = chooser.configure_source()
		if not error.is_empty(): return {"error":error}
		_choice = chooser
	# Both selections use the same effective bank, prepared with the old goal.
	var goal_result: Dictionary = _goal_choice.update_pending(_actor,stats)
	if goal_result.has("error"): return goal_result
	var action_result: Dictionary = _choice.update_pending(goal_result.state,stats)
	if action_result.has("error"): return action_result
	_actor = action_result.state.duplicate(true)
	return {"state":_actor.duplicate(true),"goal":goal_result,"action":action_result}

func commit_ai_animation_boundary(mode: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var result: Dictionary = Choice.commit_animation_boundary(_actor,mode)
	if not result.has("error"): _actor = result.state.duplicate(true)
	return result

func animation_context() -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if _pose not in [11,12]: return _pose_runtime.animation_context(_actor.b4)
	var stream := _attack.checkpoint()
	return AnimationContext.evaluate({"action":5,"frame":stream.frame,"last":17 if _pose==11 else 16,"b4":_actor.b4})

func decide_current(context: Variant, helpers: Dictionary) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid executioner context."}
	var current := animation_context()
	if current.has("error"): return current
	var supplied: Dictionary = context.duplicate(true)
	supplied.action = current.action;supplied.terminal = current.terminal
	return decide(supplied,helpers)

static func _checked_player_damage(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid player damage snapshot."}
	var probe := Damage.resolve_attack({"type":"damage","mask":8,"flags":36,"amount":1},context)
	if probe.has("error"): return probe
	if int(context.current)<1: return {"error":"Player damage snapshot requires surviving target."}
	var state := {}
	for field in ["attacker_heading","player_heading","guard","mode","scalar","current"]: state[field]=int(context[field])
	if context.has("maximum") or context.has("flags229"):
		var health := Health.adjust(context,0)
		if health.has("error"): return health
		state.maximum=int(context.maximum);state.flags229=int(context.flags229)
	if context.has("global223d4") or context.has("flags228"):
		for field in ["global223d4","flags228"]:
			if not Numbers._integer(context.get(field),255): return {"error":"Invalid player entry gate: "+field}
			state[field]=int(context[field])
	state.descriptors=[]
	for descriptor in context.descriptors:
		var slots: Array = []
		for entry in descriptor: slots.append([int(entry[0]),int(entry[1]),int(entry[2])])
		state.descriptors.append(slots)
	return {"state":state}

func bind_player_damage(context: Variant) -> String:
	if _busy or _actor.is_empty(): return "Executioner state unavailable."
	var checked := _checked_player_damage(context)
	if checked.has("error"): return checked.error
	_player_damage = checked.state
	return ""

func advance_with_player_damage(delta: Variant) -> Dictionary:
	if _busy or _actor.is_empty() or _player_damage.is_empty(): return {"error":"Player damage state unavailable."}
	if int(_actor.target)!=0x22574: return {"error":"Executioner target is not the source player."}
	var provisional := _player_damage.duplicate(true)
	var failures: Array[String] = []
	var hits: Array = []
	var feedback := func(event):
		var result := PlayerEntry.resolve(event,provisional)
		if result.has("error"):
			failures.append(result.error);return {}
		var health := Health.finalize(provisional,result)
		if health.has("error"):
			failures.append(health.error);return {}
		provisional.current=health.current
		result.player_health=health
		hits.append(result.duplicate(true))
		return result
	var result := advance(delta,feedback)
	if result.has("error"):
		if not failures.is_empty(): result.error=failures[0]
		return result
	_player_damage = provisional
	result.player_damage=_player_damage.duplicate(true)
	result.hits=hits
	return result

func set_actor_health(health_context: Variant, world: Variant, outcome_context: Variant, helpers: Dictionary) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var result := preload("res://scripts/lol2/hive_actor_health.gd").run(_actor,health_context)
	if result.has("error"): return result
	if result.outcome:
		if not outcome_context is Dictionary: return {"error":"Missing outcome context."}
		var context: Dictionary = outcome_context.duplicate(true)
		context.flags=0 # A7A74 invokes A7544 with flags zero.
		return begin_outcome(world,context,helpers)
	var candidate := checkpoint();candidate.actor=result.state
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	return {"state":_actor.duplicate(true),"checkpoint":checkpoint(),"outcome":false}

func consume_commands(saved_queue: Variant, blocked: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var result := preload("res://scripts/lol2/hive_executioner_command_queue.gd").consume(saved_queue,_actor,_actor.get("word7c"),blocked)
	if result.has("error"): return result
	var candidate := checkpoint();candidate.actor=result.state;candidate.actor.word7c=result.counter
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":checkpoint(),"queue":result.checkpoint,"executed":result.executed,"counter":result.counter}

func enqueue_hit_commands(saved_queue: Variant, saved_registry: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var queue_type = preload("res://scripts/lol2/hive_executioner_command_queue.gd")
	var registry_type = preload("res://scripts/lol2/hive_actor_registry.gd")
	var original: Dictionary = queue_type.restore(saved_queue)
	if original.has("error"): return original
	var registry: Dictionary = registry_type.restore(saved_registry)
	if registry.has("error"): return registry
	var queued: Dictionary = queue_type.enqueue(original.checkpoint,[13,7])
	if queued.has("error"): return queued
	if queued.inserted.is_empty():
		return {"checkpoint":checkpoint(),"queue":queued.checkpoint,"registry":registry.checkpoint,"inserted":[],"rejected":false}
	var activated: Dictionary = registry_type.activate_executioner(registry.checkpoint,_actor)
	if activated.has("error"): return activated
	if not activated.accepted:
		return {"checkpoint":checkpoint(),"queue":original.checkpoint,"registry":registry.checkpoint,"inserted":[],"rejected":true}
	var candidate := checkpoint();candidate.actor=activated.state
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":checkpoint(),"queue":queued.checkpoint,"registry":activated.checkpoint,"inserted":queued.inserted,"rejected":false}

func enqueue_hit_record(loss: Variant, saved_queue: Variant, saved_registry: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if not Numbers._integer(_actor.get("flags15"),255): return {"error":"Missing executioner event flags."}
	if not Numbers._integer(loss,2147483647): return {"error":"Invalid actor hit loss."}
	if (int(_actor.flags15)&4)==0 or (int(_actor.flags15)&16)!=0 or int(loss)==0:
		return {"checkpoint":checkpoint(),"event_matched":false}
	var event := preload("res://scripts/lol2/hive_executioner_hit_record.gd").evaluate_owner(loss,_actor.get("state25"))
	if event.has("error"): return event
	if event.groups.is_empty(): return {"checkpoint":checkpoint(),"event_matched":false}
	var result := enqueue_hit_commands(saved_queue,saved_registry)
	if not result.has("error"): result.event_matched=true
	return result

func apply_prepared_hit(hit: Variant, saved_queue: Variant, saved_registry: Variant, world: Variant, outcome_context: Variant, helpers: Dictionary) -> Dictionary:
	# Caller has completed native hit admission and damage calculation.
	# Source event scripts are queued before the setter, not executed inline.
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if not hit is Dictionary or not Numbers._integer(hit.get("loss"),65535) or not Numbers._integer(hit.get("remaining"),65535): return {"error":"Invalid prepared actor hit."}
	if not Numbers._integer(_actor.get("health"),65535) or int(hit.loss)+int(hit.remaining)!=int(_actor.health): return {"error":"Prepared hit disagrees with actor health."}
	var queue := preload("res://scripts/lol2/hive_executioner_command_queue.gd").restore(saved_queue)
	if queue.has("error"): return queue
	var registry := preload("res://scripts/lol2/hive_actor_registry.gd").restore(saved_registry)
	if registry.has("error"): return registry
	var provisional = get_script().new()
	var error: String = provisional.restore(checkpoint())
	if not error.is_empty(): return {"error":error}
	var event: Dictionary = provisional.enqueue_hit_record(hit.loss,queue.checkpoint,registry.checkpoint)
	if event.has("error"): return event
	if event.event_matched:
		queue.checkpoint=event.queue;registry.checkpoint=event.registry
	var health_context: Dictionary = hit.duplicate(true);health_context.requested=int(hit.remaining)
	_busy=true
	var health: Dictionary = provisional.set_actor_health(health_context,world,outcome_context,helpers)
	_busy=false
	if health.has("error"): return health
	error=restore(provisional.checkpoint())
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":checkpoint(),"queue":queue.checkpoint,"registry":registry.checkpoint,
		"event_matched":event.event_matched,"health":health}

func update_player_perception(context: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if not context is Dictionary: return {"error":"Invalid player perception context."}
	if int(_actor.target) not in [0,0x22574]: return {"error":"Other-target perception requires a separate evaluation."}
	if _perception_definition.is_empty():
		var resource: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_perception_definition.json"))
		if not resource is Dictionary or resource.get("version")!=1 or resource.get("actor")!=36 or not resource.get("definition") is Dictionary: return {"error":"Executioner perception definition unavailable."}
		_perception_definition=resource.definition.duplicate(true)
	var inputs: Dictionary = context.duplicate(true)
	inputs.merge(_perception_definition,true)
	var result := preload("res://scripts/lol2/hive_perception.gd").evaluate_player(_actor,inputs)
	if result.has("error"): return result
	if int(_actor.target)==0x22574: result.state.byte9e=int(result.state.byte9c)
	var candidate := checkpoint()
	candidate.actor=result.state
	candidate.attack.flags=int(result.state.b7)
	candidate.attack.frozen=(int(result.state.b5)&2)!=0
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":checkpoint(),"result":result.result,"calls":result.calls}

func update_target_reach(target_flags: Variant, points: Variant, reach: Variant, obstruction: Variant, draw: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var result := preload("res://scripts/lol2/hive_attack_reach_gate.gd").evaluate_target(_actor,target_flags,points,reach,obstruction,draw)
	if result.has("error"): return result
	var candidate := checkpoint()
	candidate.actor=result.state;candidate.attack.flags=int(result.state.b7)
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	result.erase("state");result.checkpoint=checkpoint()
	return result

func apply_valid_target_reach(distance: Variant, reach: Variant, obstruction: Variant, draw: Variant) -> Dictionary:
	# Caller has admitted the non-null target and calculated its native distance.
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	if int(_actor.target)==0: return {"error":"Executioner reach requires an admitted target."}
	var result := preload("res://scripts/lol2/hive_attack_reach_gate.gd").run(_actor,distance,reach,obstruction,draw)
	if result.has("error"): return result
	var candidate := checkpoint()
	candidate.actor = result.state
	candidate.attack.flags = int(result.state.b7)
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":checkpoint(),"threshold":result.threshold,"calls":result.calls}

func refresh_material_region(saved_registry: Variant, context: Variant) -> Dictionary:
	if _busy or _actor.is_empty(): return {"error":"Executioner state unavailable."}
	var updated := preload("res://scripts/lol2/hive_actor_registry.gd").refresh_material_region(saved_registry,_actor,36,context)
	if updated.has("error"): return updated
	var candidate := checkpoint()
	candidate.actor=updated.state
	var error := restore(candidate)
	if not error.is_empty(): return {"error":error}
	return {"checkpoint":checkpoint(),"registry":updated.checkpoint}
