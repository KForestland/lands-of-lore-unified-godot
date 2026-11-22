extends SceneTree
const Rules=preload("res://tests/foundation/source_rules.gd")
func _initialize():run.call_deferred()
func run():
	var failures:Array[String]=[]
	for file in DirAccess.get_files_at("res://scripts/lol2"):
		if file.ends_with(".gd"):failures.append_array(Rules.problems(file,FileAccess.get_file_as_string("res://scripts/lol2/"+file)))
	for problem in failures:push_error(problem)
	assert(failures.is_empty(),"player foundation source policy")
	# Mutations are strings, never changes to the running source revision.
	for text in [
		"extends Node\nvar health := 30",
		"extends RefCounted\nconst STRIKE_COOLDOWN := 0.45",
		"extends Node\nfunc strike():\n var damage:int=8",
		"extends Node\nfunc strike():\n return Forms.melee_damage(host.player_form,true)",
		"extends Node\nclass Callback:\n func _physics_process(_d):\n  guards.health=maxi(0,guards.health-6)",
		"extends Node\nfunc _ready():\n host.set_deferred(\"health\",0)",
		"extends Node\nfunc _process(_d):\n get_parent().health=25",
		"extends Node\nfunc receive():\n host.player_health_owner._current=1",
		"extends Node\nfunc strike():\n effects.call(\"melee_damage\",8)",
		"extends RefCounted\nfunc copied_damage(a):\n return 8 if a else 4"]:
		assert(not Rules.problems("new_copy.gd",text).is_empty(),"mutation escaped: "+text)
	assert(Rules.problems("l19_sewer_forms.gd","extends Node\nconst STRIKE_REACH := 96.0").is_empty(),"unchanged click-only bar/region reach")
	assert(not Rules.problems("l19_sewer_forms.gd","extends Node\nconst STRIKE_REACH := 97.0").is_empty(),"click-only exception cannot change silently")
	assert(Rules.problems("presentation.gd","extends Node\nfunc draw():\n var color=Color(0.45,0.45,0.45)").is_empty(),"UI colour is not a cooldown")
	assert(Rules.problems("jungle_walkthrough.gd","extends Node\nvar health:int:\n get:return player_health_owner.value()\n set(v):player_health_owner.set_value(v)\nfunc apply_inventory_handoff(s):\n health=int(s.health)").is_empty(),"legacy loader still targets forwarding alias")
	print("PASS foundation source guard: shared strike rules, one canonical health store, all ten writer families;10 mutation probes and presentation/loader exclusions")
	quit()
