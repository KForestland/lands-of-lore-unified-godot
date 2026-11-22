extends "res://tests/dark_halls_rix_rescue_input_test.gd"
## Both Prism scrolls are actual native control pickups, no item grant fixture.
const SECOND:="darkhalls:control975u1:Prsmscrl"
func acquire_spell()->bool:
 if not await super.acquire_spell():return false
 var row:Dictionary=scene.loot.source.controls.filter(func(c):return int(c.control)==975)[0]
 var point:=Vector3(row.position[0],row.position[1],row.position[2])
 for offset in [Vector3(-50,32,0),Vector3(50,32,0),Vector3(0,32,50),Vector3(0,32,-50)]:
  await component_stand(point+offset);await look(point+Vector3.UP*24)
  print("R143_SCROLL stand=",scene.player.position," target=",scene.loot.target().get("control")," crates=",scene.crates._aimed())
  for i in 3:
   await key(KEY_E);await ticks(2)
   if SECOND in scene.carried_collected:break
  if SECOND in scene.carried_collected:break
 if not check(SECOND in scene.carried_collected,"Actual E source975 supplies the second stored Prism scroll"):return false
 return check(scene.item_effects.put_on_belt(SECOND,int(scene.item_effects.belt_state().active)),"Explicit carried source scroll belt selection")
func route_name()->String:return "stored Prism5 scroll"
func rescue_cast():await key(KEY_F)
func cast_pack_ok(before:Array)->bool:
 var expected:Array=before.duplicate();expected.erase(SECOND)
 return scene.carried_collected==expected and scene.item_effects.state().spent.count(SECOND)==1
