extends SceneTree
const State=preload("res://scripts/lol2/player_item_state.gd")
func _initialize():
 var state:Dictionary=State.initial()
 assert(State.validate(state,[]).is_empty())
 state.low_light=60.0
 assert(not State.validate(state,[]).is_empty())
 state.spent=["act2:L13_RC:item70"]
 assert(State.validate(state,[]).is_empty() and State.canonical(state).low_light==60)
 for bad in [-1,61,INF,NAN,"60"]:
  state.low_light=bad;assert(not State.validate(state,[]).is_empty())
 state.low_light=0
 assert(State.validate(state,[]).is_empty())
 print("PASS optional sight timer old-packet compatibility, genuine consumed eggs receipt, finite0..60 bounds")
 quit()
