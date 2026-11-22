extends "res://tests/item_consumables_input_test.gd"
## Genuine item ids and real I/right/3/CtrlQ/F5/F9; ordinary play clock.
const FIRST_WAR:="jungle:magic_shop:War_cluster"
const SECOND_WAR:="jungle:item40:War_cluster"
func main():
 if not await boot_map("L10_DC"):return
 scene.act2_creatures.set_physics_process(false)
 if not await grant_scrolls([FIRST_WAR,SECOND_WAR]):return
 scene.quest_state.jungle_world_items={"version":1,"collected":[40]}
 var Health=preload("res://scripts/lol2/player_health.gd")
 if not await use_food(FIRST_WAR):return
 if not require(scene.starting_magic.health()==36 and Health.limit_for(scene)==36 and FIRST_WAR in scene.item_effects.state().spent,"Actual War Cluster gives guide20% on base30, through the one health owner"):return
 if not await use_food(SECOND_WAR):return
 if not require(SECOND_WAR in scene.carried_collected and scene.starting_magic.health()==36,"An active cluster does not stack or consume another"):return
 if is_instance_valid(scene.inventory):await tap(KEY_ESCAPE)
 # Existing learned-control fixture; the form change itself uses real keys.
 scene.starting_magic.learn_spell_group("control")
 await tap(KEY_3);await tap(KEY_Q,true)
 await frames(12)
 if not require(scene.player_form==2 and scene.starting_magic.health()==36 and Health.limit_for(scene)==36,"Actual form change preserves borrowed health in Lizard form"):return
 if not await disk_cycle("war_cluster"):return
 if not require(scene.player_form==2 and scene.starting_magic.health()==36 and Health.limit_for(scene)==36 and scene.item_effects.state().war_cluster.remaining>0,"F5/F9 admits and preserves the active temporary maximum"):return
 await picture("war_cluster_loaded")
 # Whole effect expires under ordinary live play, with no timer writes/scale change.
 for tick in 4200:
  await physics_frame
  if not scene.item_effects.state().has("war_cluster"):break
 if not require(not scene.item_effects.state().has("war_cluster") and scene.starting_magic.health()==30 and Health.limit_for(scene)==30 and scene.resets==0,"Borrowed six health expires on the ordinary one-minute play clock"):return
 print("PASS War Cluster actual inventory use, no stack, actual Lizard keys, F5/F9 temporary max36, ordinary60s expiry to30, zero recovery; grant/source/book/NPC fixtures")
 quit()
