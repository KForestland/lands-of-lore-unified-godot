extends SceneTree
const Defense=preload("res://scripts/lol2/player_defense.gd")
const Items=preload("res://scripts/lol2/player_item_state.gd")
const Creatures=preload("res://scripts/lol2/scripted_creature_state.gd")
func _initialize() -> void:
	var proof: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/gargoyle-bracers-checks.json"))
	for row in proof.native_damage_cases:
		var wanted:=maxi(1,roundi(int(row.native_loss)*0.4))
		assert(Defense.damage(int(row.amount),int(row.scalar),int(row.signature))==wanted,str(row))
	var state:=Items.initial()
	assert(Items.validate(state).is_empty())
	state.offhand=Defense.BRACERS
	assert(Items.validate(state,[Defense.BRACERS]).is_empty())
	assert(not Items.validate(state,[]).is_empty())
	assert(Items.canonical(JSON.parse_string(JSON.stringify(state)))==state)
	for invalid in [null,5,{},"museum:item11:Fine_Longsword"]:
		var bad:=state.duplicate(true);bad.offhand=invalid
		assert(not Items.validate(bad,[Defense.BRACERS]).is_empty())
	var src:=Creatures.source("res://scripts/lol2/cave_guard_population_source.json")
	var population:=Creatures.initial(src)
	var id:="52"
	population.actors[id].present=true;population.actors[id].woken=true
	population.actors[id].rise=Creatures.clip_seconds(int(src.definitions["2"].clips.rise.frames))
	population.live[id].mode=2
	var ordinary:=population.duplicate(true)
	var reduced:=population.duplicate(true)
	var before:=Creatures.advance_live(ordinary,src,id,0.9,10,true,false,30)
	var after:=Creatures.advance_live(reduced,src,id,0.9,10,true,false,30,5)
	assert(before==6 and after==5,str([before,after]))
	print("PASS native defense fixture240; optional offhand validation; actual generic strike6->5")
	quit()
