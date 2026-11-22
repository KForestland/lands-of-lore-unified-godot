extends SceneTree
const State=preload("res://scripts/lol2/player_item_state.gd")
const Rules=preload("res://scripts/lol2/item_throw_rules.gd")
const ROCK:="jungle:item16:Rock"
func _initialize():
 var old:Dictionary=State.initial()
 assert(State.validate(old,[]).is_empty())
 old.spent=[ROCK];old.thrown_items=[{"id":ROCK,"area":"res://scenes/lol2/maps/L10_DC.tscn","position":[0,4,0]}]
 assert(State.validate(old,[]).is_empty())
 assert(State.canonical(old).thrown_items==old.thrown_items)
 assert(not State.validate(old,[ROCK]).is_empty())
 for bad in ["res://tests/item_throw_state_test.gd","",null]:
  old.thrown_items[0].area=bad;assert(not State.validate(old,[]).is_empty())
 old.thrown_items[0].area="res://scenes/lol2/maps/L10_DC.tscn"
 for bad in [INF,NAN,32769,"0"]:
  old.thrown_items[0].position[0]=bad;assert(not State.validate(old,[]).is_empty())
 old.thrown_items[0].position[0]=0
 old.thrown_items.append(old.thrown_items[0].duplicate(true));assert(not State.validate(old,[]).is_empty())
 assert(Rules.supported(6) and Rules.supported(9) and Rules.supported(23) and not Rules.supported(61),"Lightning dagger is not guessed as physical")
 print("PASS saved recoverable physical items, old packet, malformed area/coordinates/duplicates/ownership rejected")
 quit()
