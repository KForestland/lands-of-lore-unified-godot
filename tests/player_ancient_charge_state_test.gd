extends SceneTree
const State = preload("res://scripts/lol2/player_item_state.gd")
const Ancient = preload("res://scripts/lol2/ancient_stone_effect.gd")
const Stone = preload("res://scripts/lol2/hive_ancient_stone.gd")
func _initialize() -> void:
	var legacy := State.initial()
	legacy.erase("ancient_charges")
	assert(State.validate(legacy).is_empty() and State.canonical(legacy).ancient_charges == 0)
	for count in 10:
		var saved := State.initial()
		saved.ancient_charges = count
		saved.spent = [Stone.ITEM]
		assert(State.validate(saved).is_empty())
		assert(State.canonical(JSON.parse_string(JSON.stringify(saved))) == saved)
		assert(not State.validate(saved,[Stone.ITEM]).is_empty(),"Consumed stone cannot remain carried")
		var use := Ancient.use(1,count,0)
		assert(use.result == (1 if count < 9 else 0))
		assert(use.counter == mini(9,count+1))
	for value in [-1,10,1.5,true,"1",null,NAN,INF]:
		var invalid := State.initial()
		invalid.ancient_charges = value
		assert(not State.validate(invalid).is_empty())
	var duplicate := State.initial()
	duplicate.spent = [Stone.ITEM,Stone.ITEM]
	assert(not State.validate(duplicate).is_empty())
	print("PASS Ancient charge save: legacy zero,0..9 canonical rollback, consumed ownership and malformed counter/history rejection")
	quit()
