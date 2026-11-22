extends "res://tests/generic_l10_oil_rim_input_test.gd"
## Charge proof at the unchanged game-written robot close stand; no pose,
## health, mana or receiver writes. The magic clock is held for exact debits.
const TOWER_INPUT:="res://tmp/r117_inputs/tower_arrival_f5.json"
const TOWER_PIN:="4e5bb0906335a933f94301ffea15e5fb24041da6801611629431ddf560a62247"
func main():
 use_guard=false
 if not await start_from_f2():return
 DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
 if not await reload_stand():return
 var oil:Node=scene.get_node("L10Oil")
 var magic=scene.starting_magic
 magic.set_process(false)
 await tap(KEY_1);await look(oil.AIM);await frames(3)
 if not require(scene.camera.global_position.distance_to(oil.AIM)<384,"Close oil target lies inside basic Spark range"):return
 var query:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.camera.global_position-scene.camera.global_basis.z*384,3,[scene.player.get_rid()])
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
 if not require(not hit.is_empty() and hit.collider==oil.receiver,"Basic ray actually meets the oil receiver; refusal is not a miss"):return
 var health_before:=hp();var mana_before:int=magic.magic_state().player.mana
 await tap(KEY_Q);await frames(4)
 if not require(not oil.burned() and hp()==health_before and magic.magic_state().player.mana==mana_before-1,"Actual charge1 bolt costs1 but cannot ignite close oil or apply blast"):return
 if not require(scene.interface_hud.hint.text=="A stronger Spark is needed.","Actual charge1 oil hit gives one visible plain stronger-Spark hint"):return
 await picture("r117_oil_rejects_close_spark1")
 magic.set_process(true);await ticks(45);magic.set_process(false)
 mana_before=magic.magic_state().player.mana
 await tap(KEY_Q,true);await frames(4)
 if not require(oil.burned() and hp()==maxi(0,health_before-oil.BLAST_DAMAGE) and magic.magic_state().player.mana==mana_before-3,"Actual CtrlQ ignites at charge3 with unchanged20blast and3mana"):return
 if not require(oil.BLAST_DAMAGE==20 and oil.BLAST_RADIUS==240.0,"Blast constants unchanged"):return
 if not require(scene.resets==0 and hp()>0 and scene.player.is_on_floor(),"Charge3 close blast leaves the same supported rim living before any F9"):return
 await picture("r117_oil_accepts_spark3")
 # Same ordinary charge1 on an unchanged original Ruins receiver, from a
 # genuine Tower-arrival F5. Every movement and cast is actual input.
 if not require(FileAccess.get_sha256(TOWER_INPUT)==TOWER_PIN,"Untouched Tower arrival pin"):return
 if not require(DirAccess.copy_absolute(TOWER_INPUT,Slots.slot_path(1))==OK,"Install genuine Tower-arrival F5 for actualF9"):return
 await tap(KEY_F9);await adopt()
 if not require(area=="L9_DR" and scene.resets==0 and hp()>0,"ActualF9 living Ruins Tower arrival"):return
 var tower:Node=scene.get_node("L9Tower")
 if not require(not "1090" in tower.state().orbs,"Original Ruins globe1090 really starts inactive"):return
 if not await walk(fixture("l9_tower_walk.json").ground.points,"Real walk to original Ruins Tower globe"):quit(1);return
 await tap(KEY_1)
 for attempt in 12:
  await act(tower.aims["1090"],"Charge1 on original Ruins Tower globe",KEY_Q)
  if "1090" in tower.state().orbs:break
  await ticks(60)
 if not require("1090" in tower.state().orbs and scene.resets==0 and hp()>0,"Same Q1 still lights original Ruins globe without recovery"):return
 await picture("r117_ruins_globe_still_accepts_spark1")
 print("PASS R117 real Q1 close-oil refusal/Q3 ignition with unchanged costs/blast, same Q1 original Ruins Tower globe works; untouched F5 continuations, ordinary1/60, magic-clock fixture disclosed")
 quit()
