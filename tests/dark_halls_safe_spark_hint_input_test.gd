extends "res://tests/helpers/act1_owner_object_input.gd"
## Unchanged owner's corridor save, real mouse/E/S/ControlQ at 1/60.
## Actors and slot held by the common component helper; no supplied stand,
## health/item/story fixture. S follows the source north/south corridor.
const TOO_CLOSE="Too close - step further back."
func run():
 if not await owner("L7_DH","dh_crates17"):return
 var c:Node=scene.crates
 var target:Vector3=c.center_of(749)+Vector3.UP*(c.half_of(749).y-1)
 await look(target);await ticks(8)
 if not check(c.state_of(749)==1 and c.hint.text==TOO_CLOSE,"Inside the native200 blast, primed crate never invites Spark"):return
 await key(KEY_E);await ticks(2)
 if not check(scene.interface_hud.hint.text==TOO_CLOSE,"E repeats the same near-blast warning"):return
 var found:=false
 var expected:=0
 var distance:=0.0
 for step in 100:
  await look(scene.camera.global_position+Vector3(0,0,-256))
  scene.set_physics_process(true);await hold_key(KEY_S,4);scene.set_physics_process(false)
  await look(target);await ticks(8)
  distance=Vector2(scene.player.position.x-c.center_of(749).x,scene.player.position.z-c.center_of(749).z).length()
  if step%10==0:print("SAFE_HINT_RETREAT step=",step," distance=",distance," player=",scene.player.position," center=",c.center_of(749)," hint=",c.hint.text," short=",c._aimed(true)," far=",c._aimed(true,768,true))
  if "Spark" in c.hint.text:
   expected=c.Rules.damage(c.center_of(749),scene.player.global_position,c._blast_source());found=true;break
  if distance<200 and not check(c.hint.text==TOO_CLOSE,"Every aimed unsafe retreat stand keeps the warning"):return
 print("SAFE_HINT_END found=",found," distance=",distance," expected=",expected," hint=",c.hint.text)
 if not check(found and distance>=200 and expected==0,"Real S reaches the first Spark invitation outside native radius; expected health loss0"):return
 var before:int=scene.starting_magic.health();var at:Vector3=scene.player.position
 await key(KEY_1);await modified_q();await ticks(8)
 print("SAFE_SPARK_FIRST_INVITATION position=",at," distance=",distance," expected=",expected," health_before=",before," health_after=",scene.starting_magic.health()," last_damage=",c.last_damage)
 if not check(c.state_of(749)==2 and c.last_damage==0 and scene.starting_magic.health()==before and scene.resets==0,"Actual ControlQ at first invited stand explodes749 with zero health loss/resets"):return
 var prior:String=FileAccess.get_sha256(Saves.slot_path(10))
 await key(KEY_F5);await ticks(3)
 if not check(Saves.read_document(Saves.slot_path(10)).error.is_empty() and FileAccess.get_sha256(Saves.slot_path(10))!=prior,"Actual F5 writes a fresh safe-blast document"):return
 if not await reload():return
 if not check(scene.crates.state_of(749)==2 and scene.starting_magic.health()==before,"Actual F9 retains safe detonation and health"):return
 print("PASS original corridor real S until first safe Spark line/actual ControlQ/0HP/F5F9, no pose/health/pack edits; actor/slot component aids")
 quit()
