extends SceneTree
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
func _initialize() -> void:
	var actor := {"ac":1,"ad":0,"b4":0,"b5":0,"b7":1,"b9":0,"target":0}
	var target := {"attacker_heading":32768,"player_heading":32768,"guard":1,"mode":1,"scalar":0,"current":100,"descriptors":[]}
	var helpers := {"vertical":func(_s,_m):return 4,"random":func(_s,_m):return 0,"behavior":func(_s):pass}
	var owner := Owner.new()
	assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
	assert(owner.bind_player_damage(target).is_empty())
	assert(owner.advance_with_player_damage(1).has("error"))
	assert(not owner.advance(32767).has("error"))
	assert(not owner.decide_current({},helpers).has("error"))
	var first := owner.advance_with_player_damage(6145)
	assert(not first.has("error") and first.hits.size()==1)
	assert(first.player_damage.current==93 and owner.checkpoint().actor.ad==1)
	assert(target.current==100)
	var saved := owner.checkpoint();var resumed := Owner.new()
	assert(resumed.restore(JSON.parse_string(JSON.stringify(saved))).is_empty())
	assert(resumed.checkpoint()==saved)
	var next := owner.advance_with_player_damage(4096)
	assert(next.player_damage.current==86 and next.hits.size()==1)
	assert(resumed.advance_with_player_damage(4096)==next and resumed.checkpoint()==owner.checkpoint())
	var bad := saved.duplicate(true);bad.player_damage.current=true
	var before := resumed.checkpoint()
	assert(not resumed.restore(bad).is_empty() and resumed.checkpoint()==before)
	# A second hit can fail after a first succeeds within one call: roll back both.
	assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
	assert(owner.advance(32767).events.back().type=="terminal")
	assert(not owner.decide_current({},helpers).has("error"))
	target.current=10
	assert(owner.bind_player_damage(target).is_empty())
	before=owner.checkpoint()
	var failed := owner.advance_with_player_damage(10241)
	assert(failed.has("error") and "Lethal" in failed.error and owner.checkpoint()==before)
	# Virtual84 cannot be silently treated as no effect.
	target.current=100;target.descriptors=[[[8,0,0]]]
	assert(owner.bind_player_damage(target).is_empty());before=owner.checkpoint()
	failed=owner.advance_with_player_damage(6145)
	assert(failed.has("error") and "virtual84" in failed.error and owner.checkpoint()==before)
	target.maximum=150;target.flags229=0
	assert(owner.bind_player_damage(target).is_empty())
	var healed := owner.advance_with_player_damage(6145)
	assert(not healed.has("error") and healed.player_damage.current==104)
	assert(healed.hits[0].loss==0 and healed.hits[0].remaining==100)
	assert(healed.hits[0].player_health.displays==[102,104])
	var healed_save := owner.checkpoint();var healed_resume := Owner.new()
	assert(healed_resume.restore(JSON.parse_string(JSON.stringify(healed_save))).is_empty())
	assert(healed_resume.checkpoint()==healed_save)
	var legacy := before.duplicate(true);legacy.erase("player_damage")
	assert(owner.restore(legacy).is_empty() and not owner.checkpoint().has("player_damage"))
	print("PASS: saved damage/attacker continuation, two-hit atomic rollback and guarded virtual84 application")
	quit()
