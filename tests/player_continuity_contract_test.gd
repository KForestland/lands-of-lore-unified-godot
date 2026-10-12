extends SceneTree
const C = preload("res://scripts/lol2/player_continuity.gd")
var failed := false
var checks := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failed = true
  push_error(message)
func _initialize() -> void:
 check(C.compare({"xp":10},{"xp":10}).is_empty(),"Unchanged progression rejected")
 check(not C.compare({"xp":10},{}).is_empty(),"Lost progression accepted")
 check(not C.compare({}, {}, {"mana":8}).is_empty(),"Missing expected field ignored")
 check(C.compare({}, {"mana":8}, {"mana":8}).is_empty(),"Explicit grant rejected")
 check(C.compare({"item":1}, {}, {"item":null}).is_empty(),"Explicit consumption rejected")
 var bound := {"mana":{"min":5,"max":6,"reason":"measured time"}}
 check(C.compare({"mana":5},{"mana":6},bound).is_empty(),"Bounded regeneration rejected")
 for value in [NAN, INF, -INF, "6", true, null, 7]:
  check(not C.compare({"mana":5},{"mana":value},bound).is_empty(),"Invalid regeneration accepted: %s" % str(value))
 for rule in [{"min":6,"max":5,"reason":"bad bounds"},{"min":5,"reason":"missing max"},{"min":5,"max":6},{"min":NAN,"max":6,"reason":"NaN"}]:
  check(not C.compare({"mana":5},{"mana":5},{"mana":rule}).is_empty(),"Invalid allowance accepted")
 var one := C.from_packet({"collected":["a"],"item_effects":{"spent":["b"]}}, {})
 var reordered := C.from_packet({"item_effects":{"spent":["b"]},"collected":["a"]}, {})
 check(C.compare(one,reordered).is_empty(),"Dictionary ordering changed meaning")
 check(not C.compare(one,C.from_packet({"collected":["a","a"],"item_effects":{"spent":["b"]}},{})).is_empty(),"Duplicate carried identity hidden")
 check(not C.compare(one,C.from_packet({"collected":["a"],"item_effects":{"spent":["b","b"]}},{})).is_empty(),"Duplicate consumption hidden")
 var allowance := C.mana_allowance(5,20,0.1,0.0)
 check(allowance.max==5,"Sub-period elapsed time permits refill")
 check(not C.compare({"mana":5},{"mana":20},{"mana":allowance}).is_empty(),"Spontaneous full refill accepted")
 check(C.mana_allowance(5,20,0.2,2.9).max==6,"Carried regeneration remainder ignored")
 check(C.mana_allowance(19,20,10.0,0.0).max==20,"Regeneration exceeds maximum")
 print("%s: %d continuity contract checks; omissions, duplication, finite allowances and measured regeneration" % ["FAIL" if failed else "PASS", checks])
 quit(1 if failed else 0)
