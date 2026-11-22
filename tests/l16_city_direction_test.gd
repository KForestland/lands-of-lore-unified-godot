extends SceneTree
const Hints=preload("res://scripts/lol2/l16_journal_hints.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
const Atlas=preload("res://scripts/lol2/atlas_places.gd")
var failures:=0
class Effects:
 extends Node
 var value:Dictionary={"journal":[]}
 func state()->Dictionary:return value
class Host:
 extends Node3D
 var quest_state:Dictionary={}
 var player:Node3D
 var item_effects:Node
 var starting_magic:Node
 var messages:Array=[]
 func save_feedback(message:String)->void:messages.append(message)
func check(ok:bool,label:String)->void:
 if not ok:failures+=1;push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var h:=Host.new();h.player=Node3D.new();h.add_child(h.player);h.item_effects=Effects.new();h.add_child(h.item_effects);root.add_child(h)
 var n:Node=Hints.attach(h);n.set_process(false)
 # Inject completed owner states and approach poses: presentation unit, not an earned walk.
 var cases:Array=[
  [{},Vector3.ZERO,0,"dry_fountain"],
  [{"l16_dry_fountain":{"broken":true}},Vector3.ZERO,1,"glass_pyramid"],
  [{"l16_greenhouse":{"silverleaf":"earned-leaf"}},Vector3.ZERO,2,"glass_pyramid"],
  [{"l16_greenhouse":{"opened":true}},Vector3.ZERO,3,"canal"],
  [{"l16_greenhouse":{"opened":true}},Vector3(490,32,12000),4,"oil_stair"],
  [{"l16_greenhouse":{"opened":true}},Vector3(-1273,32,13725),5,"oil_court"],
  [{"l16_se_oil":{"burned":true}},Vector3.ZERO,6,"oil_court"],
  [{"act2_items":{"collected":["act2:L16_CA:item24"]}},Vector3.ZERO,7,"dragon_room"],
  [{"l16_dragon_room":{"chopped":true}},Vector3.ZERO,8,"cavern_door"]]
 for c in cases:
  h.quest_state=c[0].duplicate(true);h.player.position=c[1]
  var before:=JSON.stringify(h.quest_state);var id:String=Hints.ROAD[c[2]].when
  n.check_road();var count:=h.messages.size();n.check_road()
  check(Journal.notes(h).count(id)==1 and h.messages.size()==count,"stage once "+id)
  check(before==JSON.stringify(h.quest_state),"no puzzle mutation "+id)
  var plot:=Atlas.active_plot("L16_CA",Journal.notes(h),h.quest_state)
  check(plot.size()==1 and plot[0].place==c[3],"one correct next pin "+id)
 # Saved journal survives a recreated presentation owner, without replaying a sentence.
 var saved:Dictionary=h.item_effects.value.duplicate(true);n.free();n=Hints.attach(h);n.set_process(false);h.item_effects.value=saved
 var count:=h.messages.size();n.check_road();check(h.messages.size()==count,"reload once-only")
 for row in [[Vector3(-3754.9,32,13400.4),Hints.WEST],[Vector3(15556,32,4123),Hints.STARRY]]:
  h.player.position=row[0];n.check_road();count=h.messages.size();n.check_road()
  check(Journal.notes(h).count(row[1])==1 and h.messages.size()==count,"approach line once "+row[1])
 h.quest_state={"l16_dragon_room":{"chopped":true,"pad_seen":true}}
 check(Atlas.active_plot("L16_CA",Journal.notes(h),h.quest_state).is_empty(),"exit clears main-road pin")
 check(Journal.validate(Journal.notes(h)).is_empty(),"new notes save-valid")
 check(not Journal.hints().l16_one_tower.contains("box"),"legacy note no longer sends player to unfinished tower")
 h.free()
 if failures==0:print("PASS City direction: nine stages + west bank/starry, once-only reload, one next Atlas pin, no quest writes")
 quit(1 if failures else 0)
