extends SceneTree
const Barrel=preload("res://scripts/lol2/l10_barrel.gd")
func _initialize():
 for s in [Barrel.initial(),{"version":1,"switch":true,"phase":1,"distance":400.5},{"version":1,"switch":true,"phase":2,"distance":1426}]:
  assert(Barrel.validate(s).is_empty())
  assert(Barrel.validate(JSON.parse_string(JSON.stringify(s))).is_empty(),"JSON round trip")
 for s in [{"version":1,"switch":false,"phase":1,"distance":12},{"version":1,"switch":true,"phase":1,"distance":1426},{"version":1,"switch":true,"phase":2,"distance":1425},{"version":1,"switch":true,"phase":0,"distance":1},{"version":1,"switch":true,"phase":1,"distance":INF},{"version":1,"switch":true,"phase":0.5,"distance":0},{"version":1,"switch":true,"phase":"1","distance":10}]:
  assert(not Barrel.validate(s).is_empty(),str(s))
 print("PASS barrel save rejects impossible partial/finished motion and round-trips valid progress")
 quit()
