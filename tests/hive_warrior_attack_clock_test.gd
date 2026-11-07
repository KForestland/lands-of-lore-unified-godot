extends SceneTree
const Attack=preload("res://scripts/lol2/hive_warrior_attack.gd")
func _initialize() -> void:
	for selector in [11,12,13,14]:
		var coarse:=Attack.initial(selector)
		var result:=Attack.advance(coarse,100,true,100)
		assert(result.terminal)
		var hits: Array=result.events.filter(func(e): return e.type=="damage")
		assert(hits.size()==1 and hits[0].amount=={11:60,12:100,13:20,14:50}[selector])
		var fine:=Attack.initial(selector)
		var count:=0
		for tick in range(100):
			var step:=Attack.advance(fine,1.0/60.0,true,100)
			count+=step.events.filter(func(e): return e.type=="damage").size()
			if step.terminal: break
		assert(count==1 and fine==coarse)
		var partial:=Attack.initial(selector)
		Attack.advance(partial,0.217,true)
		var restored:=Attack.canonical(JSON.parse_string(JSON.stringify(partial)))
		assert(restored.selector==partial.selector and restored.frame==partial.frame and restored.timer==partial.timer and is_equal_approx(restored.fraction,partial.fraction))
		var missed:=Attack.advance(restored,100,false)
		assert(missed.terminal and missed.events.filter(func(e): return e.type=="damage").is_empty())
		var bad:=partial.duplicate(true)
		bad.frame=Attack.LAST[selector]
		assert(not Attack.validate(bad).is_empty())
	var population=preload("res://scripts/lol2/hive_return_population_state.gd")
	var ambush=preload("res://scripts/lol2/hive_ambush_state.gd")
	var initial: Dictionary=population.initial()
	initial.actors["27"].attack_animation=Attack.initial(12)
	assert(not population.validate(initial).is_empty())
	initial.actors["27"].active=true
	assert(population.validate(initial).is_empty())
	initial.actors["27"].health=0
	assert(not population.validate(initial).is_empty())
	var feeding: Dictionary=ambush.initial()
	feeding.actors["35"].phase=3;feeding.actors["35"].active=true
	feeding.actors["35"].attack_animation=Attack.initial(12)
	assert(not ambush.validate(feeding).is_empty())
	print("PASS warrior four attack variants, one hit per coarse/fine cycle, source percentages, JSON clock, miss and terminal rejection")
	quit()
