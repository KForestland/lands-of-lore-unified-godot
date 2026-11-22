extends "res://tests/helpers/g15_spell_input.gd"
const Save=preload("res://scripts/lol2/game_save.gd")
const INPUT="res://tmp/l13_native_use_inputs/owner_011552.json"
const PIN="9a5c770e59d312c0828783ddd8c49d713b12f44068e506b4a4051fb5a3c8316c"
func _initialize()->void:main.call_deferred()
func load_owner()->bool:
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return false
 if not require(FileAccess.get_sha256(INPUT)==PIN,"Unedited owner F10 SHA256"):return false
 var previous:Node=current_scene
 var error:String=Save.load_file(self,INPUT)
 if not require(error.is_empty(),"Actual whole-game owner save loader: "+error):return false
 use_guard=false
 var deadline:=Time.get_ticks_msec()+60000
 while current_scene==previous and Time.get_ticks_msec()<deadline:await process_frame
 if not require(current_scene!=previous,"Whole-game loader replaced the previous scene before adoption"):return false
 await adopt()
 if not captured():await lclick();await frames(4)
 return require(area=="L13_RC" and hp()>0 and scene.resets==0 and scene.player.is_on_floor(),"Owner stand alive, grounded, no recovery")
func main()->void:
 if not await load_owner():return
 var native=scene.progression.native
 if not require(native.field("prop:193",native.FIELD_BYTE25,0)==0 and native.field("prop:306",native.FIELD_BYTE25,0)==0,"Owner save predates both switch and native relay"):return
 await look(Vector3(-3054,-996.5,-1348));await frames(4)
 await picture("l13_owner193_before")
 var prompt:String=scene.get_node("GenericObjects").hint.text
 await tap(KEY_E);await frames(5)
 print("OWNER193 actualE prompt=",prompt," switch=",native.field("prop:193",native.FIELD_BYTE25,0)," relay306=",native.field("prop:306",native.FIELD_BYTE25,0)," hud=",hud())
 if not require(native.field("prop:193",native.FIELD_BYTE25,0)==1 and native.field("prop:306",native.FIELD_BYTE25,0)==1,"Actual E at owner's switch193 runs group1060 and arms native relay306"):return
 if not require(prompt.contains("switch"),"Aimed source sprite has a use prompt"):return
 if not require(hud()=="The bridge above is already running." and not native.adapters_enabled.get("opcode14_arm5_noop",false),"Already-running bridge is explained and scoped adapter restored"):return
 if not await disk_cycle("native193_armed"):return
 native=scene.progression.native
 if not require(native.field("prop:193",native.FIELD_BYTE25,0)==1 and native.field("prop:306",native.FIELD_BYTE25,0)==1,"F5/F9 keeps switch and relay without refiring events"):return
 if not await load_owner():return
 native=scene.progression.native
 if not require(native.field("prop:193",native.FIELD_BYTE25,0)==0 and native.field("prop:306",native.FIELD_BYTE25,0)==0,"Independent left-click repeat begins with both original flags0"):return
 await look(scene.camera.global_position+Vector3(0,300,-100));await lclick();await frames(2)
 if not require(scene.interface_hud.attack_swing.icon.visible,"Off-target left click keeps ordinary attack"):return
 await ticks(70)
 await look(Vector3(-3054,-996.5,-1348));await lclick();await frames(4)
 native=scene.progression.native
 if not require(native.field("prop:193",native.FIELD_BYTE25,0)==1 and native.field("prop:306",native.FIELD_BYTE25,0)==1 and not scene.interface_hud.attack_swing.icon.visible and not native.adapters_enabled.get("opcode14_arm5_noop",false),"Aimed left click uses the real source switch before attack"):return
 await picture("l13_owner193_used")
 print("PASS owner193 actual E/leftclick/native1060->306, off-target attack, F5/F9 alive0resets, no pose/health/resources/clock aids")
 quit()
