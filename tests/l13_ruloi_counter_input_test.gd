extends "res://tests/helpers/g15_spell_input.gd"
## Lead 2026-11-16: the original HUD's "Remaining Ruloi N/19" (actors 21-39) as a small HUD line in L13 while any Ruloi
## lives. The owner's own L13 F10 (01:15:52, local only, 10 Ruloi alive) through the actual whole-game loader: the line
## says 10/19 and agrees with the maidens' count; the HUD line shows only while one lives. Disclosed: Ruloi deaths are
## written into the creature state (the kill path is covered by the Ruloi combat tests), one, then all.
const Save=preload("res://scripts/lol2/game_save.gd")
const Counter=preload("res://scripts/lol2/l13_ruloi_counter.gd")
const INPUT="res://tmp/l13_native_use_inputs/owner_011552.json"
const PIN="9a5c770e59d312c0828783ddd8c49d713b12f44068e506b4a4051fb5a3c8316c"
func _initialize()->void:main.call_deferred()
func main()->void:
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 if not require(FileAccess.get_sha256(INPUT)==PIN,"Unedited owner F10 SHA256"):return
 var previous:Node=current_scene
 var error:String=Save.load_file(self,INPUT)
 if not require(error.is_empty(),"Actual whole-game owner save loader: "+error):return
 use_guard=false
 var deadline:=Time.get_ticks_msec()+60000
 while current_scene==previous and Time.get_ticks_msec()<deadline:await process_frame
 await adopt()
 if not captured():await lclick();await frames(4)
 if not require(area=="L13_RC","Owner save is the Ruloi Stronghold"):return
 await frames(3)
 var counter:Node=scene.get_node("L13Prison/L13RuloiCounter")
 var actors:Dictionary=scene.act2_creatures.state.actors
 var living:=Counter.remaining(actors)
 var maidens:String=preload("res://scripts/lol2/l13_action_hint_targets.gd").maidens_line(scene)
 print("RULOI counter='",counter.text(),"' maidens='",maidens,"'")
 if not require(living==10 and counter.text()=="Remaining Ruloi 10/19","The HUD line says 10/19 (got '%s')"%counter.text()):return
 if not require(maidens.contains("%d still live"%living),"Same count as the maidens' line"):return
 await picture("l13_ruloi_counter_10")
 var live:Array=[]
 for n in range(21,40):if float(actors.get(str(n),{}).get("health",1))>0:live.append(n)
 actors[str(live[0])].health=0;await frames(2)
 if not require(counter.text()=="Remaining Ruloi 9/19","One Ruloi down: 9/19 (got '%s')"%counter.text()):return
 for n in live:actors[str(n)].health=0
 await frames(2)
 if not require(counter.text()=="","With every Ruloi dead the line goes (got '%s')"%counter.text()):return
 print("PASS l13_ruloi_counter_input: owner save shows 'Remaining Ruloi 10/19', matches the maidens' count, 9/19 after one, gone after all")
 quit()
