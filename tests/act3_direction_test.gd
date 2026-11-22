extends SceneTree
## Presentation unit. Supplied saved owner states; no earned walk or real-input claim.
const Hints=preload("res://scripts/lol2/act3_journal_hints.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
const Atlas=preload("res://scripts/lol2/atlas_places.gd")
var failures:=0
class Effects extends Node:
 var data:Dictionary={"journal":[]}
 func state()->Dictionary:return data
class Magic extends Node:
 var active:=true
 func world_active()->bool:return active
class Hud extends Node:
 var save_notice_remaining:=0.0
class Host extends Node3D:
 var area_id:="L17_HC"
 var quest_state:Dictionary={}
 var player:Node3D
 var item_effects:Node
 var starting_magic:Node
 var interface_hud:Node
 var messages:Array=[]
 func save_feedback(message:String):messages.append(message)
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():run.call_deferred()
func run():
 var h:=Host.new();h.player=Node3D.new();h.add_child(h.player);h.item_effects=Effects.new();h.add_child(h.item_effects);h.starting_magic=Magic.new();h.add_child(h.starting_magic);root.add_child(h)
 var n:Node=Hints.attach(h);n.set_process(false)
 # Same owner packet keys as the earned chains. Each row starts independently.
 var cases:Array=[
  ["L17_HC",{},0], ["L17_HC",{"l17_beast_blade":{"cut":true}},1],
  ["L19_BC",{},0], ["L19_BC",{"l19_belial_horn":{"taken":true}},1],
  ["L19_BC",{"l19_sewer_forms":{"lizard_at_wall":true}},2],
  ["L19_BC",{"l19_sewer_forms":{"switches":[74,75,76]}},3],
  ["L19_BC",{"l19_drain_path":{"door_clicked":true}},4],
  ["L19_BC",{"l19_ghostly_heads":{"shot":[67,69,68,70]}},5],
  ["L19_BC",{"l19_ghostly_heads":{"dragged":true}},6],
  ["L19_BC",{"l19_dawn_curse":{"ruby_offered":true}},7],
  ["L20_BB",{},0], ["L20_BB",{"l19_dawn_curse":{"curse_said":true}},1],
  ["L20_BB",{"l19_dawn_curse":{"glob_entered":true}},2],
  ["L20_BB",{"l19_dawn_curse":{"demons_killed":true}},3],
  ["L20_BB",{"l20_pillars_scotia":{"path_open":true}},4],
  ["L20_BB",{"l20_pillars_scotia":{"trinity":true}},5],
  ["L20_BB",{"l20_armory":{"hacked":true}},6],
  ["L20_BB",{"l20_armory":{"hacked":true,"ball":true}},7],
  ["L20_BB",{"l20_armory":{"stopped":true}},8],
  ["L20_BB",{"l20_faux_draracle":{"killed":true,"keys":[]}},9],
  ["L20_BB",{"l20_faux_draracle":{"killed":true,"keys":[0]}},10],
  ["L20_BB",{"l20_faux_draracle":{"killed":true,"keys":[0,1]}},11],
  ["L20_BB",{"l20_faux_draracle":{"room":true}},12],
  ["L20_BB",{"l20_finale":{"game_finished":true}},13]]
 for c in cases:
  h.area_id=c[0];h.quest_state=c[1].duplicate(true);h.item_effects.data={"journal":[]};h.messages.clear()
  var row:Dictionary=Hints.ROAD[c[0]][c[2]];var before:=JSON.stringify(h.quest_state)
  check(Hints.road_stage(c[0],h.quest_state)==c[2],"actual saved stage "+row.when)
  n.check_road();var count:=h.messages.size();n.check_road()
  check(Journal.notes(h)==[row.when] and h.messages.size()==count and h.messages.back()==row.hint,"once-only visible/Journal line "+row.when)
  check(before==JSON.stringify(h.quest_state),"no quest mutation "+row.when)
  check(row.hint.length()<=240 and row.hint.length()>20,"readable direction length "+row.when)
  var plot:=Atlas.active_plot(c[0],Journal.notes(h),h.quest_state)
  if row.place.is_empty():check(plot.is_empty(),"finished clears pin")
  else:check(plot.size()==1 and plot[0].place==row.place and plot[0].label=="Next: "+str(Atlas.place(c[0],row.place).name),"one named next pin "+row.when)
  check(Journal.validate(Journal.notes(h)).is_empty(),"save-valid direction "+row.when)
 # Recreate owner with saved Journal: no replay; paused arrival does not write.
 n.free();n=Hints.attach(h);n.set_process(false);var count:=h.messages.size();n.check_road();check(h.messages.size()==count,"reload keeps once-only line")
 h.area_id="L19_BC";h.quest_state={};h.item_effects.data={"journal":[]};h.starting_magic.active=false;n.check_road();check(Journal.notes(h).is_empty(),"paused/menu no arrival")
 h.starting_magic.active=true;n.check_road();check(Journal.notes(h)==["l19_road_arrival"],"resume discovers arrival")
 h.interface_hud=Hud.new();h.add_child(h.interface_hud)
 for c in cases:
  h.area_id=c[0];h.quest_state=c[1].duplicate(true);h.item_effects.data={"journal":[]};h.messages.clear()
  h.save_feedback("Current action result");h.interface_hud.save_notice_remaining=3.0
  n.check_road();n.check_road()
  check(h.messages==["Current action result"] and Journal.notes(h).is_empty(),"Direction and Journal notice wait behind active feedback "+str(c[0])+":"+str(c[2]))
  h.interface_hud.save_notice_remaining=0.0;n.check_road();var shown:=h.messages.size();n.check_road()
  check(h.messages.back()==Hints.ROAD[c[0]][c[2]].hint and Journal.notes(h)==[Hints.ROAD[c[0]][c[2]].when] and h.messages.size()==shown,"Deferred current-stage road appears once after feedback expires")
 h.free()
 if failures==0:print("PASS 24 Act3 saved-owner direction stages, arrival notes and named Atlas pins, once-only/load/pause/no quest writes; supplied unit packets")
 quit(1 if failures else 0)
