extends SceneTree
const S=preload("res://scripts/lol2/l9_escape_state.gd")
const W=preload("res://scripts/lol2/l9_flood_state.gd")
func _initialize():
 var s:=S.initial();assert(S.validate(s).is_empty())
 s.raft=1;assert(not S.validate(s).is_empty())
 s=S.initial();s.lift=1;assert(not S.validate(s).is_empty())
 s.boarded=true;assert(S.validate(s).is_empty())
 s.lift=16;s.raft=5;assert(not S.validate(s).is_empty())
 s.escaped=true;assert(S.validate(JSON.parse_string(JSON.stringify(s))).is_empty())
 for field in ["lift","raft"]:
  var bad:=s.duplicate();bad[field]=NAN;assert(not S.validate(bad).is_empty())
 var later:={"later":true}
 assert(W.height(later,30)==-2 and W.height(later,66)==70 and W.height(later,99)==400)
 print("PASS escape prerequisite/clock/JSON refusal and modern later-water schedule")
 quit()
