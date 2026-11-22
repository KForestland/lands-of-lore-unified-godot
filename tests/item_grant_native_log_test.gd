extends SceneTree
## S7 actual host/VM business-path vector, deliberately not player input or earned.
const Tables=preload("res://scripts/lol2/item_grant_tables.gd")
func _initialize():run.call_deferred()
func count_requests(prog:Node)->int:
 var count:=0
 for row:Dictionary in prog.native_log:
  if row.get("type","")=="item":count+=1
 return count
func run():
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_d5da60a/areas/manifest.json"))
 var scene:Node3D=load(manifest.areas.L8_SJ.scene).instantiate()
 scene.adapter_exit_seeds=false
 root.add_child(scene);current_scene=scene
 for tick in 2400:
  await process_frame
  if scene.ready_for_review:break
 assert(scene.ready_for_review,"Actual L8 host ready")
 var prog:Node=scene.progression
 prog.native.set_adapter_enabled("opcode3_item_grant",true) # Explicit VM vector; not a newly decoded callee.
 prog.native.set_global(0x223D4,0)
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/native_scripts/L8_SJ.json"))
 var chosen:Dictionary={}
 for group:Dictionary in source.groups:
  if group.commands.size()!=1:continue
  var command:Dictionary=group.commands[0]
  if int(command.opcode)!=3 or int(command.kind)!=1:continue
  var row:=Tables.command("L8_SJ",int(command.file_offset))
  if not chosen.has(row.action):chosen[row.action]=group
 assert(chosen.has("log"),"A supported pure item group is really exercised")
 for action:String in ["log","log"]:
  var group:Dictionary=chosen[action]
  var before:Array=scene.carried_collected.duplicate()
  var packet:Dictionary=scene.quest_state.get("act2_items",{}).duplicate(true)
  var requests:int=count_requests(prog)
  var result:Dictionary=prog.native.execute_group(int(group.stream),int(group.group))
  assert(result.status=="ran" and count_requests(prog)==requests+1,"Original item signal really emitted: "+action)
  assert(scene.carried_collected==before and scene.quest_state.get("act2_items",{})==packet,"Log/owner native requests never add or rewrite pack/history: "+action)
 scene.queue_free();await process_frame
 print("PASS actual L8 host+VM twice emits item signal for a log-only group; both keep original pack/history, explicit gate fixtures, no player-input claim")
 quit()
