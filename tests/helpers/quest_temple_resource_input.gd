extends "res://tests/helpers/g15_spell_input.gd"
## Legal-loss probe from untouched game-written supplies save. No fresh grant,
## direct position/quest/effect edit, NPC hold, geometry edit or time-scale aid.
const INPUT="res://tests/fixtures/quest_resource_inputs/temple_supplies.json"
const PIN="f83523a56f2884e1b0766dfbf8d6db565bf349737110e65f729080f5de36c196"
const ALOE="act2:L14_HT:item68"
const PAINT="act2:L14_HT:item72"
var mode:String
func case_key()->String:return "control"
func _initialize():main.call_deferred()
func belt_item(id:String)->bool:
 await tap(KEY_I);await frames(3)
 if not require(is_instance_valid(scene.inventory) and paused,"Real I opens inventory"):return false
 var list:ItemList=scene.inventory.item_list
 var index:=-1
 for i in list.item_count:
  if str(list.get_item_metadata(i))==id:index=i;break
 if not require(index>=0,"Original ingredient still in inventory"):return false
 var at:Vector2
 for scroll in 60:
  at=list.get_global_transform_with_canvas()*(list.get_item_rect(index).get_center()-Vector2(0,list.get_v_scroll_bar().value))
  if list.get_global_rect().grow(-3).has_point(at):break
  await button(MOUSE_BUTTON_WHEEL_UP if at.y<list.get_global_rect().position.y else MOUSE_BUTTON_WHEEL_DOWN,list.get_global_rect().get_center());await frames(1)
 if not require(list.get_global_rect().grow(-3).has_point(at),"Real wheel reveals original inventory row"):return false
 await button(MOUSE_BUTTON_RIGHT,at);await frames(2)
 var menu:PanelContainer=scene.inventory.item_menu
 if not require(is_instance_valid(menu) and menu.visible,"Actual item menu"):return false
 await button(MOUSE_BUTTON_LEFT,menu.get_node("Choices/PutOnBelt").get_global_rect().get_center());await frames(3)
 await tap(KEY_ESCAPE);await frames(3)
 for i in 5:
  var value:Dictionary=scene.item_effects.belt_state()
  if preload("res://scripts/lol2/item_belt_state.gd").resolve(value,int(value.active),scene.carried_collected)==id:return true
  await tap(KEY_BRACKETRIGHT);await frames(2)
 return require(false,"Real brackets select original ingredient")
func record(tag:String)->void:
 var folder:="user://tests/resource_audit/";DirAccess.make_dir_recursive_absolute(folder)
 var file:=FileAccess.open(folder+mode+"_"+tag+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"mode":mode,"tag":tag,"position":str(pos()),"health":hp(),"resets":scene.resets,"carried":scene.carried_collected,"items":scene.quest_state.get("act2_items",{}),"ritual":scene.get_node("L14PriestRitual").state(),"effects":scene.item_effects.state(),"hud":hud(),"on_floor":scene.player.is_on_floor()},"  "));file.close()
 var path:String=preload("res://scripts/lol2/game_save.gd").slot_path(1)
 if FileAccess.file_exists(path):DirAccess.copy_absolute(path,folder+mode+"_"+tag+".slot.json")
func main():
 mode=case_key()
 if not require(mode in ["aloe","paint","control"],"Known legal-loss probe"):return
 if not await boot_legacy(INPUT,PIN,"lol2-restoration-map-L14_HT","res://scenes/lol2/maps/L14_HT.tscn"):return
 await ticks(12)
 if not require(scene.player.is_on_floor() and hp()==30 and ALOE in scene.carried_collected and PAINT in scene.carried_collected,"Untouched real supplies stand and full pools"):return
 if not require(scene.quest_state.get("l14_priest_body",{}).get("phase")=="placed" and scene.get_node("L14PriestRitual").state().slots.is_empty(),"Genuine placed body, neither offering used"):return
 record("arrival")
 if not await disk_cycle("resource_baseline_"+mode):return
 if mode!="control":
  var id:String=ALOE if mode=="aloe" else PAINT
  if not await belt_item(id):return
  await tap(KEY_F);await ticks(12)
  if not require(id in scene.carried_collected and id not in scene.item_effects.state().spent,"Real F preserves the still-needed original ingredient"):return
  var sentence:String="You are not hurt." if mode=="aloe" else "Keep this Poison Paint for the Temple priest's ritual."
  if not require(hud()==sentence,"Plain named refusal: "+hud()):return
  await tap(KEY_F);await frames(2)
  if not require(hud()==sentence and id in scene.carried_collected,"Repeated refusal cannot become a generic belt mismatch"):return
  record("consumed")
  if not await disk_cycle("legal_resource_loss_"+mode):return
  if not require(id in scene.carried_collected and id not in scene.item_effects.state().spent,"F9 keeps the protected resource"):return
  record("reloaded_loss")
 var ritual:Node=scene.get_node("L14PriestRitual")
 for bowl:String in ["370","369"]:
  var x:float=2375.0 if bowl=="370" else 2441.0
  if not await walk([[2376,-3400],[2410,-3500],[x,-3570]],"real approach to ritual bowl "+bowl,{"no_fight":true}):quit(1);return
  ritual=scene.get_node("L14PriestRitual")
  if not await look(ritual.BOWLS[bowl]):return
  await frames(12)
  var before:Array=scene.carried_collected.duplicate();var before_state:Dictionary=ritual.state().duplicate(true)
  await tap(KEY_E);await frames(4)
  var missing:bool=false
  if missing:
   var sentence:String="The bowl needs aloe." if mode=="aloe" else "The bowl needs Poison Paint."
   if not require(hud()==sentence and scene.carried_collected==before and ritual.state()==before_state,"Real E names missing ingredient without mutation: "+hud()):return
  else:
   if not require(ritual.Kit.slot(ritual.state(),bowl).committed,"Real E commits actual original ingredient"):return
  await picture("resource_"+mode+"_bowl_"+bowl)
 await ticks(150)
 ritual=scene.get_node("L14PriestRitual")
 if not require(ritual.state().lowered==2.0,"Both offerings required for real floor lowering"):return
 if not await disk_cycle("resource_final_"+mode):return
 record("final")
 if not require(scene.resets==0 and hp()>0,"No fall recovery or revival"):return
 print("PASS RESOURCE_PROTECTION ",mode," original supplies -> actual F/no loss/plain refusal -> F5/F9 -> realW/E both offerings -> real floor lowering -> F5/F9; no supplied resources/pose/story/clock/NPC state.")
 quit()

# Same complete-action save contract as the stored-item harness, without its
# unused stand/learning/grant helpers in this real-input source chain.
func assert_item_action_saveable(context:String)->bool:
 if not is_instance_valid(scene) or not scene.has_method("can_save") or not scene.can_save().is_empty():return true
 var Slots=load("res://scripts/lol2/game_save.gd")
 return require(Slots.validate(Slots.make_document(scene,1)).is_empty(),"Completed item action remains saveable: "+context)
func tap(code:int,ctrl:=false,shift:=false)->void:
 await super.tap(code,ctrl,shift)
 if code in [KEY_E,KEY_F]:assert_item_action_saveable("key "+str(code))
func button(index:int,at:=Vector2(640,360))->void:
 await super.button(index,at)
 if index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:assert_item_action_saveable("mouse "+str(index))
