extends SceneTree
## Final receipt assertion for the29-process earned milestone runner, never a save producer.
const Save=preload("res://scripts/lol2/act2_save.gd")
func _initialize():
 var path:="res://tmp/act2_silverleaf_qualified/route_report.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--receipt="):path=arg.trim_prefix("--receipt=")
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(report.complete and report.tests.size()==29)
 for test in report.tests:
  assert(test.passed and test.source_changes.is_empty())
 assert(report.source_before==report.source_after)
 for save_path in report.saves:
  assert(FileAccess.get_sha256("res://"+save_path)==report.saves[save_path])
 var input:=Save.read_save(path.get_base_dir()+"/l8_shore_earned_save.json","lol2-restoration-darker-jungle")
 assert(input.error.is_empty())
 var quests:Dictionary=input.state.quests
 assert(quests.l9_escape.escaped and quests.l9_escape.lift==16 and quests.l9_escape.raft==5)
 assert(quests.l8_shore.arrived and quests.act2_creatures_L8_SJ.actors["20"].present)
 assert(quests.l9_statue_walk.fight_done)
 var effects:Dictionary=input.state.inventory.item_effects
 assert(effects.dampened and "monastery:item70:Dampen_charm" in effects.spent)
 assert("monastery:item70:Dampen_charm" not in input.state.inventory.collected)
 print("PASS act2_silverleaf_earned_loop_test milestone1:29 continuous earned stages, unchanged source, hashed saves, Dawn charm spent, statue/flood/shore/Dawn20/closure retained; nine-leaf return is later work")
 quit()
