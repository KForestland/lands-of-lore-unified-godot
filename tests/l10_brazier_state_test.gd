extends SceneTree
const Save=preload("res://scripts/lol2/act2_save.gd")
func _initialize():
 var loaded:=Save.read_save("res://tmp/l10_catacomb_earned_save.json","lol2-restoration-map-L10_DC")
 assert(loaded.error.is_empty(),loaded.error)
 for invalid in [{"version":2,"lit":[]},{"version":1,"lit":["235","235"]},{"version":1,"lit":["999"]},{"version":1,"lit":[235]},{"version":1,"lit":["0235"]}]:
  var bad: Dictionary=loaded.state.duplicate(true)
  bad.quests.l10_braziers=invalid
  assert(not Save.validate(bad,"lol2-restoration-map-L10_DC").is_empty())
 print("PASS malformed brazier packets rejected by actual save validator; earned input untouched")
 quit()
