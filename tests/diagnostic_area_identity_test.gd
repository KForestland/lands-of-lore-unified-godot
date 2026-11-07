extends SceneTree
const D = preload("res://scripts/lol2/dev_diagnostics.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
 push_error(message); print("FAIL diagnostic_area_identity: ",message); quit(1)
func run() -> void:
 for row in [["dark_halls","Dark Halls"],["darker_jungle","Darker Jungle"],["jungle_walkthrough","Jungle"]]:
  change_scene_to_file("res://scenes/lol2/"+row[0]+".tscn")
  for i in range(1500):
   await process_frame
   if current_scene != null and current_scene.get("ready_for_review"): break
  var scene = current_scene
  if scene == null or not scene.get("ready_for_review"): return fail("Area not ready")
  paused = true
  var before: String=JSON.stringify({"quests":scene.quest_state,"inventory":scene.inventory_state()},"",true)
  if D.host_kind(scene) != "Jungle": return fail("Host-state dispatch changed")
  var report: Dictionary=D.capture(scene)
  if report.area != row[1] or report.status != "ready" or report.player.is_empty(): return fail("Wrong diagnostic identity: %s" % report)
  D.record(scene,"area_identity_review","")
  if D.last_operation.area != row[1]: return fail("Operation label wrong")
  var feedback: Dictionary=root.get_node("PlaytestFeedback").capture_context()
  if feedback.area != row[1] or feedback.diagnostics.area != row[1]: return fail("F10 identity wrong")
  if before != JSON.stringify({"quests":scene.quest_state,"inventory":scene.inventory_state()},"",true): return fail("Diagnostics mutated gameplay")
  paused=false
  scene.queue_free();await process_frame;await process_frame
 print("PASS diagnostic_area_identity: Dark Halls/Darker Jungle/Jungle labels, host dispatch preserved, F10 and operation labels correct, gameplay state unchanged")
 quit(0)
