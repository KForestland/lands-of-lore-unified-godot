extends SceneTree
const State=preload("res://scripts/lol2/cave_scenic_guard_state.gd")
var accepted: Array=[]
var waiting:=true
func effects(c: Dictionary) -> bool:
	if c.op==8 and waiting:return false
	accepted.append(c.raw_hex);return true
func _initialize() -> void:
	var src:=State.source();var s:=State.initial()
	assert(State.validate(s,src).is_empty())
	assert(not State.enqueue(s,"actor_event3"))
	assert(State.enqueue(s,"supplied_hit") and not State.enqueue(s,"supplied_hit"))
	var blocked:=State.drain(s,src)
	assert(blocked.applied==0 and blocked.blocked[0].command.raw_hex=="0f033e026503de00")
	State.drain(s,src,effects)
	assert(s.selector==0 and s.local0==0 and s.pending[0].cursor==51)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s))
	assert(State.validate(saved,src).is_empty())
	var previous:=accepted.size();State.drain(s,src,effects);assert(accepted.size()==previous)
	waiting=false;State.drain(s,src,effects)
	assert(s.pending.is_empty() and s.selector==3 and s.actor_mode==4 and s.local0==1)
	assert(not State.enqueue(s,"region969"))
	State.advance(s,src,5.0)
	var mid: Dictionary=JSON.parse_string(JSON.stringify(s))
	assert(State.validate(mid,src).is_empty() and State.frame(mid,src)==32)
	State.advance(s,src,20.0)
	assert(State.frame(s,src)==75 and s.actor_state==0 and s.selector==3)
	assert(not State.enqueue(s,"actor_event3")) # Clock endpoint does not invent prop completion.
	assert(State.enqueue(s,"prop_event0"));State.drain(s,src,effects)
	assert(s.actor_state==1 and s.prop_state==1 and not s.prop_present)
	assert(State.enqueue(s,"actor_event3"));State.drain(s,src,effects)
	assert(s.selector==4 and s.movables=={"21":true,"22":true})
	assert(not State.enqueue(s,"actor_event3") and State.validate(s,src).is_empty())
	var replay:=State.canonical(saved);State.drain(replay,src,effects)
	assert(replay.local0==1 and replay.selector==3 and replay.pending.is_empty())
	var alternate:=State.initial();assert(State.enqueue(alternate,"region969"));State.drain(alternate,src,effects)
	assert(not alternate.present and not alternate.prop_present and not State.enqueue(alternate,"supplied_hit"))
	var bad:=s.duplicate(true);bad.elapsed=99.0;assert(not State.validate(bad,src).is_empty())
	bad=saved.duplicate(true);bad.pending[0].cursor=100;assert(not State.validate(bad,src).is_empty())
	print("PASS scenic guard ordered69-command prefix, external blocking/no replay, cursor JSON, collapse endpoint awaiting supplied completion, corpse/movables and local0 alternate branch")
	quit()
