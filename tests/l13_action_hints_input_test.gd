extends "res://tests/helpers/g15_world_spell_input.gd"
## Receiver census component: explicit stand placement and NPC hold, not a walk.
const Hints=preload("res://scripts/lol2/l13_action_hint_targets.gd")
const Combat=preload("res://scripts/lol2/player_combat.gd")
const Journal=preload("res://scripts/lol2/my_journal.gd")
var provider:=Hints.new()
func _initialize():main.call_deferred()
func vantage(receiver:Node3D,aim:Vector3)->Variant:
 var space=scene.get_world_3d().direct_space_state
 for radius in [110.0,160.0,220.0]:
  for turn in 24:
   var theta=TAU*float(turn)/24.0
   var p=aim+Vector3(cos(theta)*radius,0,sin(theta)*radius)
   var q=PhysicsRayQueryParameters3D.create(p+Vector3.UP*24,p-Vector3.UP*640,1,[scene.player.get_rid(),receiver.get_rid()])
   var floor_hit=space.intersect_ray(q)
   if floor_hit.is_empty():continue
   var eye:Vector3=floor_hit.position+Vector3.UP*42
   var ray=space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,aim,3,[scene.player.get_rid()]))
   if not ray.is_empty() and ray.collider==receiver:return floor_hit.position+Vector3.UP*32
 return null
func aim_receiver(receiver:Node3D,aim:Vector3,kind:String)->bool:
 var p=vantage(receiver,aim)
 if not require(p!=null,"Visible real-floor component stand for "+kind):return false
 if not await stand_at(p):return false
 if not await look(aim):return false
 await frames(8)
 return require(provider.pick(scene).get("kind")==kind,"Actual first-hit ray selects "+kind)
func main():
 if not await boot_map("L13_RC"):return
 scene.act2_creatures.set_physics_process(false)
 await tap(KEY_1)
 var spires=scene.get_node("L13Spires")
 for id in spires.receivers:
  if not await aim_receiver(spires.receivers[id],spires.aims[id],"spire"):return
  var mana:int=scene.starting_magic.magic_state().player.mana
  await tap(KEY_E);await frames(2)
  if not require(scene.interface_hud.hint.text=="The spire is dark. Cast Spark at it." and str(id) not in spires.state().lit and scene.starting_magic.magic_state().player.mana>=mana,"Real E explains dark spire %s without casting: hint=%s lit=%s mana=%s->%s" % [str(id),scene.interface_hud.hint.text,str(spires.state().lit),str(mana),str(scene.starting_magic.magic_state().player.mana)]):return
  await tap(KEY_Q);await frames(45)
  if not require(str(id) in spires.state().lit,"Real Q lights spire "+str(id)):return
  print("SPIRE_GREEN ",id)
 if not require(Journal.notes(scene).count("l13_action_spire")==1,"All seventeen spires share one Journal sentence"):return
 var basin=scene.get_node("L13Eggs")
 var eye_floor=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3270,80,4330),Vector3(-3270,-300,4330),1,[scene.player.get_rid()]))
 if not require(not eye_floor.is_empty(),"Original eye-switch approach floor"):return
 if not await stand_at(eye_floor.position+Vector3.UP*32):return
 if not await look(basin.EYE):return
 await tap(KEY_E);await frames(8)
 if not require(basin.state().eye_open,"Actual E still opens the original eye switch"):return
 if not await aim_receiver(basin.receiver,basin.receiver.global_position,"vent"):return
 await tap(KEY_E);await frames(2)
 if not require(scene.interface_hud.hint.text=="The central fixture can be broken with Spark (1, then Q)." and not basin.state().vent_broken,"Real E names Spark without breaking the fixture"):return
 await tap(KEY_Q);await frames(45)
 if not require(basin.state().vent_broken and Journal.notes(scene).count("l13_action_egg_fixture")==1,"Actual Q breaks the vent; Journal sentence once"):return
 var lift=scene.get_node("L13Elevator")
 if not await aim_receiver(lift.brain_receiver,lift.aim(),"lift"):return
 await tap(KEY_Q);await frames(3)
 if not require(lift.state().started and lift.state().motion.remaining!=0,"Hint leaves actual Spark elevator action intact"):return
 if not require(Journal.notes(scene).count("l13_action_lift")==1 and hp()>0 and scene.resets==0,"Lift hint Journal once, alive and zero recovery"):return
 print("PASS real mouse/E/Q all17 dark spires, original real-E eye / vent and Spark lift; disclosed component stands/NPC hold; ordinary1/60")
 quit()
