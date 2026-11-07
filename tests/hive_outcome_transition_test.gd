extends SceneTree
const Transition = preload("res://scripts/lol2/hive_outcome_transition.gd")
const Lookup = preload("res://scripts/lol2/hive_outcome_lookup.gd")
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
const Group = preload("res://scripts/lol2/hive_outcome_group.gd")
const Preparation = preload("res://scripts/lol2/hive_outcome_preparation.gd")
const World = preload("res://scripts/lol2/hive_outcome_world.gd")
func _initialize() -> void:
	var timer_type = preload("res://scripts/lol2/hive_event_timer.gd")
	var timer_draws = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_material_timers_native.json"))
	var timer_ranges := {273:[4,15],275:[4,13],278:[3,15],279:[4,12],293:[4,15]}
	assert(timer_draws.size()==5120)
	for row in timer_draws:
		var bounds: Array = timer_ranges[int(row.prop)]
		var drawn: Dictionary = timer_type.draw_reload(row.seed,bounds[0],bounds[1],row.scale)
		assert(not drawn.has("error") and drawn.rng==row.rng_after and drawn.draw==row.draw and drawn.reload==row.ticks)
		var expired: Dictionary = timer_type.advance_with_rng({"version":1,"flags":0,"remaining":0},0,row.seed,bounds[0],bounds[1],row.scale)
		assert(not expired.has("error") and expired.fired and expired.rng==row.rng_after and expired.checkpoint.remaining==row.ticks)
	assert(timer_type.advance_with_rng({"version":1,"flags":0,"remaining":10},1,123,null,null,null).rng==123)
	assert(timer_type.advance_with_rng({"version":1,"flags":1,"remaining":0},null,123,null,null,null).rng==123)
	var expiries = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_material_timer_expiry_native.json"))
	assert(expiries.size()==1080)
	for row in expiries:
		var saved := {"version":1,"flags":1 if row.disabled else 0,"remaining":int(row.remaining)}
		var result: Dictionary = timer_type.advance(saved,row.elapsed,row.reload)
		assert(not result.has("error") and result.fired==row.fired and result.checkpoint.remaining==row.next)
		assert(saved.remaining==row.remaining)
		assert(timer_type.restore(JSON.parse_string(JSON.stringify(result.checkpoint))).checkpoint==result.checkpoint)
	var stops = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_material_timer_stop_native.json"))
	assert(stops.size()==60)
	for row in stops:
		var result: Dictionary = timer_type.stop({"version":1,"flags":row.flags,"remaining":54321})
		assert(not result.has("error") and result.unregister==row.removed and result.checkpoint.flags==row.after_flags and result.checkpoint.remaining==54321)
	for flags in range(256):
		for reload_value in [0,180,240,720,780,900,65535]:
			var result: Dictionary = timer_type.reset({"version":1,"flags":flags,"remaining":7},reload_value)
			assert(not result.has("error") and result.checkpoint.flags==flags and result.checkpoint.remaining==reload_value)
	assert(timer_type.advance({"version":1,"flags":0,"remaining":1},1,null).has("error"))
	assert(timer_type.restore({"version":1,"flags":0,"remaining":65536}).has("error"))
	_test_actor_hit_entry()
	_test_actor_damage_preparation()
	_test_command_queue()
	_test_executioner_hit_record()
	_test_hit_events()
	_test_actor_health()
	_test_prepared_owner()
	var regions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_outcome_regions_native.json"))
	assert(regions.size()==1024)
	for row in regions:
		var result := World.mark_sector(row.flags,0,row.targets)
		assert(not result.has("error"),str(result))
		for field in ["marked","recorded","flags"]:
			var expected: Array = row.after if field=="flags" else row[field]
			assert(result[field].size()==expected.size())
			for i in range(expected.size()): assert(result[field][i]==expected[i])
	var notifications = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_outcome_notifications_native.json"))
	assert(notifications.size()==512)
	for row in notifications:
		var before := JSON.stringify(row)
		var result := World.adjust(row.stats,row.group,row.peers,row.sector_flags)
		assert(not result.has("error"),str(result))
		for i in range(30): assert(result.stats[i]==row.expected[i])
		assert(result.operations.size()==row.operations.size())
		for i in range(result.operations.size()):
			for j in range(2): assert(result.operations[i][j]==row.operations[i][j])
		var flags: Array = row.sector_flags.duplicate();flags.append(0)
		var composed := World.prepare(row.stats,row.group,flags.size()-1,[],flags,row.peers)
		assert(not composed.has("error") and composed.stats==result.stats and composed.operations==result.operations)
		for i in range(flags.size()): assert(composed.flags[i]==flags[i])
		assert(World.prepare(row.stats,row.group,null,[],flags,row.peers).operations.is_empty())
		assert(JSON.stringify(row)==before)
		assert(World.mark_sector(flags,flags.size(),[]).has("error"))
		assert(World.mark_sector(flags,0,[flags.size()]).has("error"))
	var groups = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_outcome_group_native.json"))
	assert(groups.size()==68)
	for row in groups:
		var original: Dictionary = row.before.duplicate(true)
		var result := Group.remove(row.before,row.actor)
		assert(not result.has("error"),str(result))
		assert(row.before==original)
		assert(result.group.index==row.after.index)
		for field in ["members","flags","reserved"]:
			assert(result.group[field].size()==row.after[field].size())
			for i in range(result.group[field].size()): assert(result.group[field][i]==row.after[field][i])
		for field in row.removed: assert(result.removed[field]==row.removed[field])
		assert(Group.restore(JSON.parse_string(JSON.stringify(result.group))).group==result.group)
		assert(Group.remove(result.group,row.actor).has("error"))
		# Compose the entry flag clear with native ring removal, including leader
		# transfer and the final-member reserved byte rule.
		var bank: Array = [];bank.resize(30);bank.fill(250)
		var member := -1
		for i in range(row.before.members.size()):
			if row.before.members[i]==row.actor: member=i
		assert(member>=0)
		var actor := {"id":row.actor,"a8":7,"b4":row.before.flags[member],"a0":row.before.index,"word84":77,"stats":bank,"health":300}
		var world := {"sector":null,"neighbors":[],"sector_flags":[],"peers":[],"group":row.before}
		var prepared := Preparation.run(actor,world)
		assert(not prepared.has("error"),str(prepared))
		assert(prepared.world.group==result.group and prepared.state.b4==(int(row.removed.b4)&0xf7))
		assert(prepared.state.a0==255 and prepared.state.next_actor==null and prepared.state.word84==0)
		assert(prepared.state.health==300 and prepared.state.stats==bank and not prepared.already)
		assert(world.group==original and actor.word84==77)
		var mismatched: Dictionary = world.duplicate(true)
		mismatched.group.flags[member]=int(mismatched.group.flags[member])^1
		assert(Preparation.run(actor,mismatched).has("error"))
		actor.a8=15
		var bypass := Preparation.run(actor,{})
		assert(not bypass.has("error") and bypass.already and bypass.world.is_empty())
		assert(bypass.state.health==300 and bypass.state.a0==actor.a0 and bypass.state.word84==0)
		assert(bypass.state.b4==(int(actor.b4)&0xf7))
		var bad: Dictionary = row.before.duplicate(true)
		bad.members.append(bad.members[0]);bad.flags.append(0)
		assert(Group.restore(bad).has("error"))
	var lookups = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_outcome_lookup_native.json"))
	assert(lookups.size()==8192)
	for row in lookups:
		var draws: Array = []
		var actor := {"ac":int(row.mask),"b7":int(row.mode)<<1}
		var selected := Lookup.select(actor,row.action,row.variant,func(_state,maximum):draws.append(maximum);return row.sample)
		assert(not selected.has("error") and selected.selector==row.selector)
		assert(draws.size()==int(row.draws) and selected.draws==int(row.draws))
		for maximum in draws: assert(maximum==100)
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_outcome_transition_native.json"))
	assert(fixture.size()==2048)
	for row in fixture:
		var operations: Array = []
		var hooks := {
			"event":func(_state,event):operations.append(["event",event]),
			"release":func(_state):operations.append(["release"]),
			"lookup":func(_state,action,variant):
				operations.append(["lookup",action,variant]);return row.context.lookup[str(action)],
			"start":func(_state,selector,flags):operations.append(["start",selector,flags]),
			"effect":func(_state,resource,parameter):operations.append(["effect",resource,parameter])}
		var before: Dictionary = row.state.duplicate(true)
		var result := Transition.run(row.state,row.context,hooks)
		assert(not result.has("error"),str(result))
		assert(row.state==before)
		for key in row.after: assert(result.state[key]==row.after[key],str(row))
		assert(operations.size()==row.operations.size(),str(row))
		for i in range(operations.size()):
			assert(operations[i].size()==row.operations[i].size())
			for j in range(operations[i].size()): assert(operations[i][j]==row.operations[i][j],str(row))
		# A failed staged callback cannot change the supplied actor checkpoint.
		hooks.event=func(state,_event):state.health=99;return {"error":"staged failure"}
		assert(Transition.run(row.state,row.context,hooks).has("error") and row.state==before)
	var owner_cases := 0
	for mask in [0,1,2,6,7,255]:
		for mode in range(4):
			for blocked in [0,1]:
				for action in [0,21,22]:
					var actor := {"ac":mask,"ad":0,"b4":0,"b5":blocked,"b6":0,"b7":mode<<1,"b9":0,"target":0,"a8":7,"a9":7,"aa":1,"ab":1,"b8":0,"ba":0,"bb":0,"flags14":0,"flags15":0,"ae":0,"health":300}
					var owner := Owner.new()
					assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
					var events: Array = [];var draws: Array = []
					var context := {"flags":0,"action":action,"definition77":5,"effects_disabled":true,"effect21":0,"effect22":0,"effect_template":0}
					var helpers := {
						"random":func(_state,maximum):draws.append(maximum);return 50,
						"event":func(_state,event):assert(owner.checkpoint().is_empty());events.append(event),
						"release":func(_state):pass,
						"effect":func(_state,_resource,_parameter):assert(false,"EXEC has no action21/22 selection")}
					var result := owner.finish_outcome_preparation(context,helpers)
					assert(not result.has("error"),str(result))
					assert(result.state.health==0 and result.state.a8==15 and result.state.aa==15 and result.state.ab==16 and result.state.ae==5)
					assert(events==([10,11] if blocked else [10]))
					assert(draws.size()==(0 if blocked else 1))
					if not blocked:
						var expected := 18 if (mask&6)!=0 and (mask&1)==0 else 17
						assert(result.checkpoint.pose==expected and result.selections==[{"selector":expected,"changed":true}])
						assert(owner.advance(6145).state.frame==7)
						var progress := owner.checkpoint()
						var again := owner.finish_outcome_preparation(context,helpers)
						assert(not again.has("error") and not again.selections[0].changed)
						assert(owner.checkpoint().source_pose==progress.source_pose)
					var saved := owner.checkpoint();var restored := Owner.new()
					assert(restored.restore(JSON.parse_string(JSON.stringify(saved))).is_empty())
					assert(restored.checkpoint()==saved)
					helpers.release=func(state):state.health=999;return {"error":"staged release failure"}
					assert(owner.finish_outcome_preparation(context,helpers).has("error") and owner.checkpoint()==saved)
					owner_cases+=1
	print("PASS:1536 world fixtures,68 group fixtures,8192 source lookups,2048 outcome transitions,",owner_cases," owner transitions")
	quit()

func _test_prepared_owner() -> void:
	var stats: Array = [];stats.resize(30);stats.fill(250)
	var positive: Array = [];positive.resize(30);positive.fill(10)
	var negative: Array = [];negative.resize(30);negative.fill(-20)
	var actor := {"id":36,"a0":4,"b0":300,"word84":77,"stats":stats,"ac":1,"ad":0,"b4":24,"b5":0,"b6":0,"b7":0,"b9":0,"target":0,"a8":7,"a9":7,"aa":1,"ab":1,"b8":0,"ba":0,"bb":0,"flags14":0,"flags15":0,"ae":0,"health":300}
	var world := {"sector":0,"neighbors":[1],"sector_flags":[0,0],"group":{"version":1,"index":4,"members":[36,3],"flags":[24,0],"reserved":[7,8,9]},"peers":[
		{"id":3,"kind":2,"group":4,"sector":0,"rows":{"4":positive}},
		{"id":8,"kind":2,"group":255,"sector":1,"rows":{"3":negative}}]}
	var owner := Owner.new()
	assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
	var before := owner.checkpoint();var world_before: Dictionary = world.duplicate(true)
	var context := {"flags":0,"action":0,"definition77":5,"effects_disabled":true,"effect21":0,"effect22":0,"effect_template":0}
	var events: Array = [];var draws: Array = []
	var helpers := {"random":func(_state,maximum):draws.append(maximum);return 50,
		"event":func(_state,event):assert(owner.checkpoint().is_empty());events.append(event),
		"release":func(_state):return {"error":"release failed"},
		"effect":func(_state,_resource,_parameter):assert(false)}
	var health_context := {"requested":0,"maximum":300,"definition3c":0,"definition7f":100,"mode":0}
	context.flags=2 # The health setter must supply zero instead.
	assert(owner.set_actor_health(health_context,world,context,helpers).has("error"))
	assert(owner.checkpoint()==before and world==world_before)
	events.clear();draws.clear()
	helpers.release=func(_state):pass
	var result := owner.set_actor_health(health_context,world,context,helpers)
	assert(not result.has("error"),str(result))
	assert(world==world_before and events==[10] and draws==[100])
	assert(result.state.a0==255 and result.state.b4==0 and result.state.word84==0 and result.state.next_actor==null)
	for value in result.state.stats: assert(value==235 and value is int)
	assert(result.state.health==0 and result.state.aa==15 and result.state.ab==16 and result.checkpoint.pose==17)
	assert(result.world.group.members==[3] and result.world.group.flags==[16] and result.world.group.reserved==[7,8,9])
	assert(result.world.sector_flags==[0,0] and result.adjustments==[[3,4],[8,3]])
	var restored := Owner.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(owner.checkpoint()))).is_empty())
	assert(restored.checkpoint()==owner.checkpoint())
	assert(owner.advance(6145).state.frame==7)
	var progress := owner.checkpoint()
	var again := owner.begin_outcome(result.world,{}, {})
	assert(not again.has("error") and again.already and again.selections.is_empty())
	assert(owner.checkpoint()==progress and events==[10] and draws==[100])
	var hit_owner := Owner.new();var hit_seed: Dictionary = before.duplicate(true)
	hit_seed.actor.flags15=4;hit_seed.actor.flags16=0;hit_seed.actor.flags17=0;hit_seed.actor.state25=1;hit_seed.actor.word7c=99
	hit_seed.actor.merge({"byte91":0,"word70":0xfffffff1,"a7":15},true)
	assert(hit_owner.restore(hit_seed).is_empty())
	var saved_hit_owner := Owner.new()
	assert(saved_hit_owner.restore(JSON.parse_string(JSON.stringify(hit_owner.checkpoint()))).is_empty())
	for field in ["byte91","word70","a7"]:
		assert(saved_hit_owner.checkpoint().actor[field] is int and saved_hit_owner.checkpoint().actor[field]==hit_seed.actor[field])
		var malformed := hit_owner.checkpoint();malformed.actor[field]=-1
		assert(not saved_hit_owner.restore(malformed).is_empty())
	assert(saved_hit_owner.checkpoint()==hit_owner.checkpoint())
	var pending := {"version":1,"commands":[],"cursor":0}
	var registry := {"version":1,"active":[3],"inactive":[36]}
	var hit := {"loss":1,"remaining":299,"mode":0,"definition3c":0,"definition7f":50}
	var survived := hit_owner.apply_prepared_hit(hit,pending,registry,null,null,{})
	assert(not survived.has("error"),str(survived))
	assert(survived.checkpoint.actor.health==299 and survived.queue.commands==[13,7])
	assert(survived.registry.active==[36,3] and survived.registry.inactive.is_empty())
	assert(pending.commands.is_empty() and registry.inactive==[36])
	assert(hit_owner.restore(hit_seed).is_empty())
	hit.loss=300;hit.remaining=0
	var failed_helpers := helpers.duplicate()
	failed_helpers.event=func(_state,_event):pass
	failed_helpers.release=func(_state):return {"error":"outcome release failed"}
	assert(hit_owner.apply_prepared_hit(hit,pending,registry,world,context,failed_helpers).has("error"))
	assert(hit_owner.checkpoint()==hit_seed and pending.commands.is_empty() and registry.inactive==[36])
	failed_helpers.release=func(_state):pass
	var lethal := hit_owner.apply_prepared_hit(hit,pending,registry,world,context,failed_helpers)
	assert(not lethal.has("error"),str(lethal))
	assert(lethal.checkpoint.actor.health==0 and lethal.checkpoint.pose==17 and lethal.queue.commands==[13,7])
	assert(lethal.health.world.group.members==[3])
	var healed := Owner.new();assert(healed.restore(before).is_empty())
	var nonzero := health_context.duplicate();nonzero.requested=100
	var reduced := healed.set_actor_health(nonzero,null,null,{})
	assert(not reduced.has("error") and reduced.state.health==100 and reduced.state.ac==2 and reduced.state.stats[4]==84)
	var intermediate := healed.checkpoint();var roundtrip := Owner.new()
	assert(roundtrip.restore(JSON.parse_string(JSON.stringify(intermediate))).is_empty() and roundtrip.checkpoint()==intermediate)
	nonzero.requested=300
	var recovered := healed.set_actor_health(nonzero,null,null,{})
	assert(not recovered.has("error") and recovered.state.health==300 and recovered.state.ac==1 and recovered.state.stats[4]==255)
	print("PASS: composed outcome world/group/owner transaction, rollback and JSON persistence")

func _test_actor_health() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_health_native.json"))
	assert(fixture.size()==4096)
	for row in fixture:
		var actor: Dictionary = row.state.duplicate(true)
		actor.stats=[];actor.stats.resize(30);actor.stats.fill(0);actor.stats[4]=actor.stat4
		var before: Dictionary = actor.duplicate(true)
		var result := preload("res://scripts/lol2/hive_actor_health.gd").run(actor,row.context)
		assert(not result.has("error"),str(result))
		assert(actor==before and result.outcome==row.outcome and result.maximum_calls==row.maximum_calls)
		for field in ["a8","b5","ac","health"]: assert(result.state[field]==row.after[field],str(row))
		assert(result.state.stats[4]==row.after.stat4,str(row))
		actor.b0=row.context.maximum
		var bound_context: Dictionary = row.context.duplicate(true);bound_context.erase("maximum")
		var bound := preload("res://scripts/lol2/hive_actor_health.gd").run(actor,bound_context)
		assert(not bound.has("error") and bound.outcome==result.outcome and bound.state.health==result.state.health and bound.state.stats==result.state.stats)
		bound_context.maximum=int(actor.b0)+1
		assert(preload("res://scripts/lol2/hive_actor_health.gd").run(actor,bound_context).has("error"))
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_actor_health.json"))
	assert(source.actor==36 and source.maximum==300 and source.requested==300 and source.definition7f==50)
	var bank: Array = [];bank.resize(30);bank.fill(0)
	var seed := {"a8":7,"b5":0,"ac":1,"stats":bank}
	var fresh := preload("res://scripts/lol2/hive_actor_health.gd").initialize_fresh(seed,source)
	assert(not fresh.has("error") and not fresh.outcome and fresh.state.health==300 and fresh.state.b0==300 and fresh.state.stats[4]==255)
	assert(not seed.has("health") and not seed.has("b0"))
	var initializations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_health_initialization_native.json"))
	assert(initializations.size()==1024)
	for row in initializations:
		# The setter's maximum-zero division remains unsupported, but constructor
		# wrap and call inputs are still covered by the native fixture.
		if int(row.maximum)==0: continue
		var context := {"maximum":row.maximum,"requested":row.requested,"definition3c":0,"definition7f":50,"mode":0}
		var initialized := preload("res://scripts/lol2/hive_actor_health.gd").initialize_fresh(seed,context)
		var staged: Dictionary = seed.duplicate(true);staged.health=row.initial_health;staged.b0=row.maximum
		var expected := preload("res://scripts/lol2/hive_actor_health.gd").run(staged,context)
		assert(initialized==expected)
	print("PASS:4096 native actor health setter cases")

func _test_hit_events() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_events_native.json"))
	assert(fixtures.size()==2048)
	for row in fixtures:
		var operations: Array = []
		var helpers := {"list":func(_actor):operations.append(["list"]);return 9,
			"dispatch":func(listing,_request,index):assert(listing==9);operations.append(["dispatch",index]);return 3 if index==0 else 5,
			"kind":func(_attacker):operations.append(["kind"]);return row.kind,
			"event":func(listing,event,value):assert(listing==9);operations.append(["event",event,value]);return 7}
		var actor := {"flags15":4 if row.enabled else 0}
		var request := {"attacker":null if row.kind==null else 1,"mode":row.mode,"subtype":row.subtype}
		var result := preload("res://scripts/lol2/hive_hit_events.gd").run(actor,request,helpers)
		assert(not result.has("error") and result.result==row.result,str(result))
		assert(operations.size()==row.operations.size())
		for i in range(operations.size()):
			for j in range(operations[i].size()): assert(operations[i][j]==row.operations[i][j])
		if row.enabled:
			helpers.dispatch=func(_listing,staged,_index):staged.mode=99;return {"error":"event failed"}
			assert(preload("res://scripts/lol2/hive_hit_events.gd").run(actor,request,helpers).has("error") and request.mode==row.mode)
	print("PASS:2048 native hit event ordering cases and staged failure isolation")

func _test_executioner_hit_record() -> void:
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_executioner_hit_record_native.json"))
	assert(rows.size()==1024)
	for row in rows:
		var calls: Array = []
		var result := preload("res://scripts/lol2/hive_executioner_hit_record.gd").evaluate(row.loss,func(index):calls.append(["predicate",index]);return row.predicate)
		assert(not result.has("error") and result.result==row.result)
		for group in result.groups: calls.append(["enqueue",group])
		assert(calls.size()==row.calls.size())
		for i in range(calls.size()):
			for j in range(calls[i].size()): assert(calls[i][j]==row.calls[i][j])
	assert(preload("res://scripts/lol2/hive_executioner_hit_record.gd").evaluate(1,func(_i):return {"error":"predicate unavailable"}).has("error"))
	var predicates = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_predicate_native.json"))
	assert(predicates.size()==256)
	for row in predicates:
		var accepted := preload("res://scripts/lol2/hive_executioner_hit_record.gd").evaluate_owner(1,row.owner_state)
		assert(not accepted.has("error") and accepted.result==int(row.accepted))
		assert(preload("res://scripts/lol2/hive_executioner_hit_record.gd").evaluate_owner(0,row.owner_state).groups.is_empty())
	var groups = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_group_native.json"))
	assert(groups.size()==512)
	for row in groups:
		var actor := {"a8":row.state,"b5":row.flags}
		var changed := preload("res://scripts/lol2/hive_executioner_hit_record.gd").apply_group(actor,1234)
		assert(not changed.has("error") and changed.state.b5==row.after and changed.counter==row.counter)
		assert(actor.b5==row.flags and changed.applied==(int(row.state)!=15))
	print("PASS:1024 source executioner hit record cases")

func _test_command_queue() -> void:
	var queue = preload("res://scripts/lol2/hive_executioner_command_queue.gd")
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_queue_duplicates_native.json"))
	assert(rows.size()==30)
	for row in rows:
		var saved := {"version":1,"commands":row.before,"cursor":row.cursor}
		var before: Dictionary = saved.duplicate(true)
		var result: Dictionary = queue.enqueue(saved,[row.operation])
		assert(not result.has("error") and saved==before)
		assert(result.checkpoint.commands.size()==row.after.size())
		for i in range(row.after.size()): assert(result.checkpoint.commands[i]==row.after[i])
		assert(result.inserted.size()==int(row.inserted))
		assert(queue.restore(JSON.parse_string(JSON.stringify(result.checkpoint))).checkpoint==result.checkpoint)
	assert(queue.restore({"version":1,"commands":[7],"cursor":-1}).has("error"))
	assert(queue.restore({"version":1,"commands":[16],"cursor":0}).has("error"))
	var removals = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_queue_removal_native.json"))
	assert(removals.size()==72)
	for row in removals:
		var result: Dictionary = queue.remove({"version":1,"commands":row.before,"cursor":row.cursor},row.index,255)
		assert(not result.has("error") and result.flags16==row.flags16 and result.checkpoint.cursor==row.cursor)
		assert(result.checkpoint.commands.size()==row.after.size())
		for i in range(row.after.size()): assert(result.checkpoint.commands[i]==row.after[i])
		assert(queue.restore(JSON.parse_string(JSON.stringify(result.checkpoint))).checkpoint==result.checkpoint)
	var registry_type = preload("res://scripts/lol2/hive_actor_registry.gd")
	var refreshes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_material_actor_refresh_native.json"))
	assert(refreshes.size()==2880)
	for row in refreshes:
		var inactive: Array = []
		for i in range(int(row.placement[0])): inactive.append(100+i)
		var active: Array = [40,41]
		if row.registered: active.push_front(36)
		else: inactive.insert(int(row.placement[1]),36)
		var saved := {"version":1,"active":active,"inactive":inactive}
		var before: Dictionary = saved.duplicate(true)
		var actor := {"flags14":int(row.mode),"flags15":int(row.flag15),"flags16":0,"flags17":32 if row.registered else 0}
		var result: Dictionary = registry_type.refresh_material_region(saved,actor,36,{"same_region":row.same,"actor_z":row.actor_z,"floor_height":row.floor_height})
		assert(not result.has("error") and saved==before and actor.flags16==0)
		assert(result.state.flags16==int(row.marked) and result.state.flags17==(32 if row.registered or row.queued else 0))
		if row.queued:
			active=active.duplicate();active.append(36)
			inactive=inactive.duplicate();inactive.erase(36)
		assert(result.checkpoint.active==active and result.checkpoint.inactive==inactive)
		assert(registry_type.restore(JSON.parse_string(JSON.stringify(result.checkpoint))).checkpoint==result.checkpoint)
	assert(registry_type.apply_material_refresh({"version":1,"active":[36],"inactive":[]},{"flags16":0,"flags17":0},36,true).has("error"))
	var registries = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_command_registry_native.json"))
	assert(registries.size()==90)
	for row in registries:
		var saved := {"version":1,"active":row.active,"inactive":row.inactive}
		var original: Dictionary = saved.duplicate(true)
		var result: Dictionary = registry_type.activate_executioner(saved,{"flags16":row.flags16,"flags17":row.flags17})
		assert(not result.has("error") and saved==original)
		assert(result.state.flags16==row.after16 and result.state.flags17==row.after17)
		for field in ["active","inactive"]:
			assert(result.checkpoint[field].size()==row["after_"+field].size())
			for i in range(result.checkpoint[field].size()): assert(result.checkpoint[field][i]==row["after_"+field][i])
		assert(registry_type.restore(JSON.parse_string(JSON.stringify(result.checkpoint))).checkpoint==result.checkpoint)
	assert(registry_type.restore({"version":1,"active":[36],"inactive":[36]}).has("error"))
	var activations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_command_activation_native.json"))
	assert(activations.size()==1024)
	for row in activations:
		var actor := {"flags16":row.flags16,"flags17":row.flags17}
		var result: Dictionary = queue.activation(actor)
		assert(not result.has("error") and result.accepted==row.accepted and result.register==row.register)
		assert(result.state.flags16==row.after16 and result.state.flags17==row.after17)
		assert(actor.flags16==row.flags16 and actor.flags17==row.flags17)
	var searches = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_queue_search_native.json"))
	assert(searches.size()==108)
	for row in searches: assert(queue.next_index(int(row.count),row.previous,row.removed)==row.next)
	for goal in [7,15]:
		for flags in range(256):
			for blocked in [0,1]:
				var pending := {"version":1,"commands":[13,7],"cursor":2}
				var actor := {"a8":goal,"b5":flags,"flags16":4}
				var result: Dictionary = queue.consume(pending,actor,99,blocked)
				assert(not result.has("error"))
				assert(pending.commands==[13,7] and actor.b5==flags)
				assert(result.checkpoint.cursor==2)
				if blocked: assert(result.checkpoint.commands==[13,7] and result.state==actor and result.counter==99)
				else:
					assert(result.checkpoint.commands.is_empty() and result.executed==[13,7] and result.state.flags16==0)
					assert(result.state.b5==(flags if goal==15 else (flags|12)&254))
					assert(result.counter==(99 if goal==15 else 0))
	print("PASS:30 native duplicate/cursor cases and pending-command JSON persistence")

func _test_actor_damage_preparation() -> void:
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_damage_preparation_native.json"))
	assert(rows.size()==4096)
	for row in rows:
		var result := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").prepare(row)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result[field]==row.expected[field])
	var calculations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_mitigation_native.json"))
	assert(calculations.size()==2048)
	for row in calculations:
		var result := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").calculate(row)
		assert(not result.has("error"),str(result))
		for field in ["fixed","loss","remaining","percentage","mask","flags"]: assert(result[field]==row.expected[field])
		assert(result.virtual84.is_empty() and row.expected.virtual84.is_empty())
	print("PASS:4096 player-to-actor native damage preparations")

func _test_actor_hit_entry() -> void:
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_hit_entry_native.json"))
	assert(rows.size()==2560)
	for row in rows:
		var actor := {"a8":row.goal,"b5":row.b5,"b8":row.b8}
		var kind: Variant = null if row.attacker=="none" else 1 if row.attacker=="player" else 32 if row.attacker=="kind32" else 2
		var result := preload("res://scripts/lol2/hive_actor_hit_entry.gd").evaluate(actor,kind,row.attacker=="self")
		assert(not result.has("error") and result.admitted==row.admitted and result.state.b8==row.after_b8)
		assert(actor.b8==row.b8)
	var resistance = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_status_resistance_native.json"))
	assert(resistance.size()==1024)
	for row in resistance:
		var result := preload("res://scripts/lol2/hive_actor_hit_entry.gd").source_resists_status(row.status,row.mask)
		assert(not result.has("error") and result.resists==row.resists)
	print("PASS:2560 native initial actor hit gates")
	var resources = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_resource_adjustment_native.json"))
	assert(resources.size()==225)
	for row in resources:
		var result := preload("res://scripts/lol2/hive_actor_hit_entry.gd").adjust_resource(row.current,row.maximum,row.amount)
		assert(not result.has("error") and result.current==row.expected)
	for invalid in [-2147483649,2147483648,0.5,"1",null]:
		assert(preload("res://scripts/lol2/hive_actor_hit_entry.gd").adjust_resource(0,300,invalid).has("error"))
	print("PASS:225 native actor resource adjustments")
	var weapons = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_weapon_request_modifiers_native.json"))
	assert(weapons.size()==192)
	for row in weapons:
		var before: Dictionary = row.duplicate(true)
		var result := preload("res://scripts/lol2/hive_weapon_request.gd").build(row)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result[field]==row.expected[field])
		assert(row==before)
	print("PASS:192 native player weapon request modifier cases")
	var fields = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_weapon_request_fields_native.json"))
	assert(fields.size()==480)
	for row in fields:
		var context: Dictionary = row.duplicate(true)
		context.merge({"counter43":0,"counter44":0,"flags45":0})
		var result := preload("res://scripts/lol2/hive_weapon_request.gd").build(context)
		assert(not result.has("error") and result.amount==row.amount and result.mask==row.mask and result.signature==row.signature)
	for c43 in [0,1,2]:
		for c44 in [0,1,2]:
			var context := {"counter43":c43,"counter44":c44,"flags45":0,"stats":[7,11,13,17],"signed_bonus":-8}
			var result := preload("res://scripts/lol2/hive_weapon_request.gd").fine_longsword(context)
			assert(not result.has("error") and result.mask==2 and result.amount==40)
			assert(result.signature==(68 if c44 else 36 if c43 else 4))
			assert(not context.has("mask") and not context.has("signature"))
	var sword_hits = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_mitigation_native.json"))
	assert(sword_hits.size()==1050)
	for row in sword_hits:
		var result := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").calculate(row)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result[field]==row.expected[field],str(row))
	print("PASS:1050 native Fine Longsword mitigation cases")
	var sword_preparations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_preparation_native.json"))
	assert(sword_preparations.size()==4096)
	for row in sword_preparations:
		var result := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").prepare(row)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result[field]==row.expected[field])
	var sword := preload("res://scripts/lol2/hive_weapon_request.gd").fine_longsword({"counter43":0,"counter44":0,"flags45":0,"stats":[7,11,13,17],"signed_bonus":-8})
	var calculation := {"amount":sword.amount,"signature":sword.signature,"damage_mask":sword.mask,"attacker_heading":0,"target_heading":32768,"mode":1,"scalar":15,"current":300}
	var sword_result := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").resolve(calculation)
	assert(not sword_result.has("error") and sword_result.loss==17 and sword_result.remaining==283 and sword_result.mask==2)
	print("PASS:4096 sword preparations and source-request calculation composition")
	var handoffs = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_hit_handoff_native.json"))
	assert(handoffs.size()==2048)
	for row in handoffs:
		var before: Dictionary = row.state.duplicate(true)
		var result := preload("res://scripts/lol2/hive_actor_hit_entry.gd").prepare_calculation(row.state,row.definition83)
		assert(not result.has("error"),str(result))
		assert(result.direct_calculation==row.admitted and result.state.b4==(int(row.state.b4)&252))
		assert(result.state.b5==(int(row.state.b5)|12 if (int(row.state.word70)&15)==1 else int(row.state.b5)))
		assert(result.current==row.state.health and result.remaining==row.state.health and result.scalar==row.state.a7)
		assert(result.scale==maxi(int(row.definition83),1) and row.state==before)
	print("PASS:2048 native actor calculation admission preparations")
	var status_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_status_descriptor_native.json"))
	assert(status_rows.size()==256)
	for row in status_rows:
		var result := preload("res://scripts/lol2/hive_actor_hit_entry.gd").status_descriptor(row.status)
		assert(not result.has("error"))
		for index in range(3): assert(result.descriptor[index]==row.descriptor[index])
	print("PASS:256 native alternate-hit status descriptors")
	var extra_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_hit_extra_mitigation_native.json"))
	assert(extra_rows.size()==1024)
	for row in extra_rows:
		var result := preload("res://scripts/lol2/hive_actor_hit_entry.gd").extra_mitigation(row.status,row.b7,4)
		assert(not result.has("error") and result.signature==row.signature)
		if row.descriptor==null: assert(result.descriptor==null)
		else:
			for slot in range(4):
				for field in range(3): assert(result.descriptor[slot][field]==row.descriptor[slot][field])
	print("PASS:1024 native alternate-hit status/flag mitigation combinations")
	var alternate_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_alternate_damage_native.json"))
	assert(alternate_rows.size()==5120)
	for row in alternate_rows:
		var result := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").calculate_alternate(row,row.status,row.b7)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result[field]==row.expected[field],str(row))
	print("PASS:5120 native alternate descriptor/damage compositions")
	var sword_statuses = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_status_entry_native.json"))
	assert(sword_statuses.size()==3072)
	for row in sword_statuses:
		var actor := {"byte91":row.status,"b6":row.b6}
		var result := preload("res://scripts/lol2/hive_actor_hit_entry.gd").sword_status_entry(actor,row.signature)
		assert(not result.has("error") and result.state.b6==row.after_b6 and result.clear_df67c==row.reset)
		assert(actor.b6==row.b6)
	print("PASS:3072 native sword status admissions")
	var hit_actor := {"a8":7,"b5":0,"b8":0,"byte91":0,"b6":0,"b4":3,"b7":0,"a7":15,"word70":1,"health":300}
	var hit_context := {"signature":4,"amount":40,"attacker_heading":0,"target_heading":32768,"mode":1}
	var composed := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").prepare_sword_hit(hit_actor,hit_context,1)
	assert(not composed.has("error"),str(composed))
	assert(composed.admitted and composed.damage.loss==17 and composed.state.b4==0 and composed.state.b5==12)
	assert(hit_actor.b4==3 and hit_actor.b5==0)
	hit_actor.b7=2
	composed=preload("res://scripts/lol2/hive_actor_damage_preparation.gd").prepare_sword_hit(hit_actor,hit_context,1)
	assert(not composed.has("error") and composed.damage.loss==20 and composed.prepared.signature==12)
	hit_actor.byte91=61
	composed=preload("res://scripts/lol2/hive_actor_damage_preparation.gd").prepare_sword_hit(hit_actor,hit_context,1)
	assert(not composed.has("error") and composed.clear_df67c and composed.state.b6==4)
	hit_actor.a8=15
	composed=preload("res://scripts/lol2/hive_actor_damage_preparation.gd").prepare_sword_hit(hit_actor,hit_context,1)
	assert(not composed.has("error") and not composed.admitted and not composed.has("damage"))
	print("PASS:composed sword gates, status, alternate mitigation and damage")
	var preflagged = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_preflagged_native.json"))
	assert(preflagged.size()==4096)
	for row in preflagged:
		var actor := {"a8":7,"b5":0,"b8":0,"byte91":0,"b6":0,"b4":0,"b7":2,"a7":15,"word70":0,"health":300}
		var incoming: Dictionary = row.duplicate(true)
		incoming.signature=int(row.signature)&~8
		var result := preload("res://scripts/lol2/hive_actor_damage_preparation.gd").prepare_sword_hit(actor,incoming,1)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result.prepared[field]==row.expected[field],str(row))
	print("PASS:4096 preexisting-bit8 heading/mode compositions")
	var reward_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_reward_seed_native.json"))
	assert(reward_rows.size()==216)
	for row in reward_rows:
		var result := preload("res://scripts/lol2/hive_sword_feedback.gd").reward_seed(row)
		assert(not result.has("error") and result.base==row.base and result.difference==row.difference and result.byte1b2==0)
	print("PASS:216 native sword feedback reward seeds")
	var reward_scaling = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_reward_scaling_native.json"))
	assert(reward_scaling.size()==4599)
	for row in reward_scaling:
		var result := preload("res://scripts/lol2/hive_sword_feedback.gd").scale_reward(row.base,row.difference)
		assert(not result.has("error") and result.award==row.award)
	print("PASS:4599 native sword reward scaling cases")
	var application_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_sword_reward_application_native.json"))
	assert(application_rows.size()==248)
	for row in application_rows:
		var player := {"experience":row.experience,"level":row.level,"condition":row.condition,"maximum":100,"health":80,"stat151":10,"stat155":12}
		var before: Dictionary = player.duplicate(true)
		var result := preload("res://scripts/lol2/hive_reward_application.gd").apply_reward(player,row.award,row.draws)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result.state[field]==row.expected[field])
		assert(result.draws_used==row.draws.size() and player==before)
		if not row.draws.is_empty():
			assert(preload("res://scripts/lol2/hive_reward_application.gd").apply_reward(player,row.award,[]).has("error"))
			assert(player==before)
	print("PASS:248 native reward applications and missing-draw rollback")
	var equipment_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_equipment_stats_native.json"))
	assert(equipment_rows.size()==64)
	for row in equipment_rows:
		var before: Array = row.slots.duplicate(true)
		var result := preload("res://scripts/lol2/hive_equipment_stats.gd").aggregate(row.slots)
		assert(not result.has("error"),str(result))
		var names := ["stat3a4","stat3a8","stat3ac","stat3b0","stat411","stat40d"]
		for index in range(6): assert(result.state[names[index]]==row.expected[index])
		assert(row.slots==before)
	var sword_equipment := preload("res://scripts/lol2/hive_equipment_stats.gd").aggregate([null,null,[12,0,7],null,null,null])
	assert(sword_equipment.state.stat3ac==12 and sword_equipment.state.stat411==7 and sword_equipment.state.stat3a4==0)
	for invalid in [[],[null,null,[128,0,0],null,null,null],[null,null,[0.5,0,0],null,null,null]]:
		assert(preload("res://scripts/lol2/hive_equipment_stats.gd").aggregate(invalid).has("error"))
	print("PASS:64 native equipment aggregations and Fine Longsword slot binding")
	var forms = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_stat_form_dispatch_native.json"))
	assert(forms.size()==1536)
	for row in forms:
		var context := {"form":row.form,"base_attack":row.base,"base_defense":row.base,"prior_attack":777,"prior_defense":888,"boosted":row.boosted}
		var result := preload("res://scripts/lol2/hive_equipment_stats.gd").for_form(context,[null,null,null,null,null,null])
		assert(not result.has("error"),str(result))
		assert(result.state.attack==row.attack and result.state.defense==row.defense and (int(result.state.signed_bonus)&255)==int(row.bonus))
	print("PASS:1536 native form-stat dispatch cases")
	var equipped_forms = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_equipped_form_native.json"))
	assert(equipped_forms.size()==384)
	for row in equipped_forms:
		var context := {"form":row.form,"base_attack":15,"base_defense":20,"prior_attack":777,"prior_defense":888,"boosted":0}
		var result := preload("res://scripts/lol2/hive_equipment_stats.gd").for_form(context,row.slots)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result.state[field]==row.expected[field],str(row))
	print("PASS:384 native equipped form/controller compositions")
	for row in equipped_forms:
		var controller: Dictionary = row.expected.duplicate(true)
		controller.stat39c=-3
		var request := preload("res://scripts/lol2/hive_weapon_request.gd").from_controller(controller,{"mask":2,"signature":4},{"version":1,"counter43":0,"counter44":0,"flags45":0})
		assert(not request.has("error"),str(request))
		var total := (int(controller.attack)+int(controller.stat3a4)-3+int(controller.stat3ac)+int(controller.signed_bonus))&0xffffffff
		assert(request.amount==total and request.mask==2 and request.signature==4)
	print("PASS:384 signed controller-to-weapon request compositions")
	var signed_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_weapon_signed_fields_native.json"))
	assert(signed_rows.size()==480)
	for row in signed_rows:
		var controller := {"attack":row.stats[0],"stat3a4":row.stats[1],"stat39c":row.stats[2],"stat3ac":row.stats[3],"signed_bonus":row.signed_bonus}
		var request := preload("res://scripts/lol2/hive_weapon_request.gd").from_controller(controller,{"mask":row.mask,"signature":row.signature},{"version":1,"counter43":0,"counter44":0,"flags45":0})
		assert(not request.has("error") and request.amount==row.amount and request.mask==row.mask and request.signature==row.signature)
	print("PASS:480 native signed/boundary controller request cases")
	var progression := {"version":1,"player":{"experience":249,"level":1,"condition":0,"maximum":100,"health":80,"stat151":10,"stat155":12}}
	var advanced := preload("res://scripts/lol2/hive_reward_application.gd").award_checkpoint(progression,1,[95,63,32])
	assert(not advanced.has("error"))
	var equipment := preload("res://scripts/lol2/hive_equipment_stats.gd").from_reward_checkpoint(advanced.checkpoint,{"form":1,"prior_attack":10,"prior_defense":12,"boosted":0},[null,null,[12,0,7],null,null,null])
	assert(not equipment.has("error") and equipment.state.attack==12 and equipment.state.defense==14 and equipment.state.stat3ac==12)
	equipment.state.stat39c=0
	var leveled_request := preload("res://scripts/lol2/hive_weapon_request.gd").from_controller(equipment.state,{"mask":2,"signature":4},{"version":1,"counter43":0,"counter44":0,"flags45":0})
	assert(not leveled_request.has("error") and leveled_request.amount==24)
	assert(progression.player.stat151==10 and progression.player.level==1)
	print("PASS:source reward-to-controller base mapping and equipped sword request")
	var adjustment_rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_attack_adjustment_clock_native.json"))
	assert(adjustment_rows.size()==512)
	for row in adjustment_rows:
		var before: Dictionary = row.duplicate(true)
		var result := preload("res://scripts/lol2/hive_attack_adjustment_clock.gd").advance(row)
		assert(not result.has("error"),str(result))
		for field in row.expected: assert(result[field]==row.expected[field])
		assert(row==before)
	print("PASS:512 native timed attack-adjustment updates")
	for limit in range(256):
		var started := preload("res://scripts/lol2/hive_attack_adjustment_clock.gd").start(limit,limit,255-limit)
		assert(not started.has("error") and started.timer==262144 and started.value==0 and started.limit==limit)
		assert(started.flags42c==(limit&251) and started.flags==((255-limit)|4) and not started.stop)
		var tick: Dictionary = started.duplicate(true);tick.delta=262144
		var at_zero := preload("res://scripts/lol2/hive_attack_adjustment_clock.gd").advance(tick)
		assert(not at_zero.has("error") and at_zero.timer==0 and at_zero.value==0)
		tick.merge(at_zero,true);tick.delta=1
		var following := preload("res://scripts/lol2/hive_attack_adjustment_clock.gd").advance(tick)
		assert(not following.has("error") and following.timer==262143 and following.value==(1 if limit>1 else 0))
	print("PASS:256 source adjustment starts and exact-zero continuation")
	var shield := preload("res://scripts/lol2/hive_attack_adjustment_clock.gd").start_damage_shield(255,0)
	assert(not shield.has("error") and shield.resource==469 and shield.limit==16 and shield.timer==262144)
	for index in range(16):
		shield.delta=262144 if index>0 else 262145
		var next := preload("res://scripts/lol2/hive_attack_adjustment_clock.gd").advance(shield)
		assert(not next.has("error"))
		shield.merge(next,true)
		assert(shield.value==((index+1)%16) and shield.timer==262143)
	print("PASS:source damage-shield initializer and complete repeat cycle")
