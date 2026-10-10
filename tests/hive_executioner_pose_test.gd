extends SceneTree
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
func _initialize() -> void:
	var helpers := {"vertical":func(_s,_m):return 4,"random":func(_s,_m):return 0,"behavior":func(_s):pass}
	for pose in [0,2]:
		for mask in [1,2]:
			var actor := {"ac":mask,"ad":0,"b4":0,"b5":0,"b7":1,"b9":0,"target":0}
			var owner := Owner.new()
			assert(owner.initialize_pose(actor,pose,15,true,0).is_empty())
			var dormant := owner.checkpoint()
			assert(dormant.pose == pose)
			assert(not owner.animation_context().terminal)
			assert(owner.advance(32767).events.back().type == "terminal")
			assert(owner.checkpoint().source_pose.frame==15 and owner.animation_context().terminal)
			var resumed := Owner.new()
			assert(resumed.restore(JSON.parse_string(JSON.stringify(dormant))).is_empty())
			assert(resumed.advance(32767).events.back().type=="terminal")
			var started := resumed.decide_current({},helpers)
			assert(started.selections.size() == 1 and started.selections[0].changed)
			assert(resumed.checkpoint().pose == (12 if mask == 1 else 11))
			assert(resumed.checkpoint().attack.frame == 0 and resumed.checkpoint().attack.timer == 0)
			assert(not resumed.advance(1).has("error") and resumed.checkpoint().attack.frame == 1)
			var active := resumed.checkpoint()
			assert(resumed.restore(JSON.parse_string(JSON.stringify(active))).is_empty())
			assert(resumed.checkpoint() == active)
			var bad := dormant.duplicate(true);bad.attack.frame = 1
			assert(not resumed.restore(bad).is_empty() and resumed.checkpoint() == active)
			bad = active.duplicate(true);bad.pose = 4
			assert(not resumed.restore(bad).is_empty() and resumed.checkpoint() == active)
			actor.b5 = 1
			assert(owner.initialize_pose(actor,pose,15,true,0).is_empty())
			assert(owner.decide({"action":0,"terminal":true},helpers).selections.is_empty())
			assert(owner.checkpoint().pose == pose and owner.advance(1024).events.is_empty())
	print("PASS: full source poses0/2, frame-derived admission, first attacks11/12 and JSON continuation")
	quit(0)
