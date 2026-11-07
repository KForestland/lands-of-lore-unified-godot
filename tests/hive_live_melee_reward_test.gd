extends SceneTree
const Reward = preload("res://scripts/lol2/hive_live_melee_reward.gd")
func _initialize() -> void:
	var hit := Reward.apply({},123,292)
	assert(not hit.has("error") and hit.award==20 and hit.checkpoint.player.experience==20)
	assert(hit.seed==123) # No level-up means no RNG consumption.
	var kill := Reward.apply(hit.checkpoint,hit.seed,0)
	assert(kill.award==200 and kill.checkpoint.player.experience==220)
	assert(hit.checkpoint.player.experience==20)
	var before: Dictionary = kill.checkpoint.duplicate(true)
	before.player.experience=249
	var level := Reward.apply(before,123,1)
	assert(level.checkpoint.player.level==2 and level.checkpoint.player.experience==19)
	assert(level.seed!=123 and before.player.level==1)
	assert(Reward.apply(JSON.parse_string(JSON.stringify(before)),123,1)==level)
	assert(Reward.apply(before,123,-1).has("error"))
	print("PASS: source Executioner hit/kill awards, threshold growth, RNG and JSON replay")
	quit()
