extends "res://tests/dark_halls_rix_rescue_input_test.gd"
## Valid-ID item grant and missing-global/talk-failure fault fixtures are explicit.
const MISTS:="act2:L14_HT:item20"
func acquire_spell()->bool:
 var Grants=preload("res://scripts/lol2/item_grants.gd")
 if not check(Grants.grant(scene,MISTS,{"cap":false,"history":"act2_once","sync":true}).ok,"Disclosed actual-ID Mists-scroll grant"):return false
 if not await study(MISTS):return false
 return check(MISTS not in scene.carried_collected and "mists1" in scene.starting_magic.magic_state().spellbook.learned,"Actual study learns Mists; no direct book edit")
func route_name()->String:return "learned Mists1"
func rescue_cast():await key(KEY_4);await charge(KEY_Q)
func fault_checks()->bool:
 # Explicit temporary ray-occlusion fixture; no production terrain changes.
 var blocked:=StaticBody3D.new();blocked.collision_layer=1;blocked.collision_mask=0
 scene.add_child(blocked)
 blocked.global_position=scene.camera.global_position.lerp(scene.creatures.bodies["57"].global_position+Vector3.UP*20,0.5)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,80,30);shape.shape=box;blocked.add_child(shape)
 await ticks(3)
 var health_before:int=scene.creatures.state.actors["57"].health;var mana_before:int=scene.starting_magic.magic_state().player.mana
 if not check(not scene.rix.aimed_spell(),"Actual first-hit obstruction rejects Rix behind a solid"):return false
 await rescue_cast();await ticks(2)
 var no_hit:bool=scene.creatures.state.actors["57"].health==health_before and scene.starting_magic.magic_state().player.mana==mana_before and not scene.rix.state().get("rescued",false)
 blocked.queue_free();await ticks(3)
 if not check(no_hit and scene.rix.aimed_spell(),"Obstructed cast cannot damage or debit, clear ray restored"):return false
 await charge(KEY_Q,true,false);await ticks(2)
 if not check(scene.creatures.state.actors["57"].health==health_before and scene.starting_magic.magic_state().player.mana==mana_before,"Wrong Mists3 charge cannot damage or debit at Rix"):return false
 var old:Dictionary=scene.quest_state.monastery.globals
 scene.quest_state.monastery.erase("globals") # Explicit unavailable-context fault, restored before save.
 var hp:int=scene.creatures.state.actors["57"].health;var mana:int=scene.starting_magic.magic_state().player.mana
 await rescue_cast();await ticks(2)
 var unchanged:bool=scene.creatures.state.actors["57"].health==hp and scene.starting_magic.magic_state().player.mana==mana and not scene.rix.state().get("rescued",false) and scene.interface_hud.hint.text=="Rix cannot be freed just now."
 scene.quest_state.monastery.globals=old
 return check(unchanged,"Unavailable rescue context refuses visibly, no mana/health/story effect")
func after_rescued_load()->bool:
 # An invalid native snapshot is a fault fixture, never written to a slot.
 var native:Dictionary=scene.rix.state().native
 scene.rix.state().native={}
 if not await at_rix():return false
 await key(KEY_E);await ticks(2)
 var shown:bool=scene.interface_hud.hint.text=="Rix cannot speak just now." and not scene.rix.state().get("talked",false)
 scene.rix.state().native=native
 return check(shown,"Failed talk owns E and says why instead of silently passing through")
