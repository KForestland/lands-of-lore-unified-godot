extends "res://tests/helpers/g15_stored_spell_input.gd"
const Scrolls=preload("res://scripts/lol2/museum_scroll_state.gd")
func _initialize():main.call_deferred()
func main():
 if not require(DisplayServer.get_name()!="headless" and Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"Rendered ordinary1/60"):return
 scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
 scene.introduction_state="complete" # Local presentation fixture; no quest/item teaching.
 root.add_child(scene);current_scene=scene
 await frames(6)
 use_guard=false;await frames(20)
 if not captured():await lclick();await frames(3)
 var owner:Node=scene.scroll_pickups
 if not await stand_at(Vector3(-1937,32,-1128)):return
 if not await look(owner.pickups[4].global_position):quit(1);return
 await tap(KEY_E);await frames(3)
 var id:String=Scrolls.IDS[4]
 if not require(id in scene.carried_collected and owner.state.taken[4],"Real E takes actual Museum Summon source and its receipt"):return
 var magic=scene.starting_magic;magic.set_process(false)
 var mana:int=magic.magic_state().player.mana
 if not await inventory_right_use(id):return
 if not require(id not in scene.carried_collected and owner.state.consumed[4] and id in scene.item_effects.state().spent and magic.magic_state().spellbook.learned==["summon3"] and magic.magic_state().player.mana==mana,"Real rightclick learns Summon, consumes source receipt once, no cast/debit"):return
 if not await museum_disk_cycle():return
 if not require(scene.scroll_pickups.state.taken[4] and scene.scroll_pickups.state.consumed[4] and not scene.scroll_pickups.pickups[4].visible and id in scene.item_effects.state().spent,"Real F5/F9 preserves Museum placement, consumption and no respawn"):return
 print("PASS actual Museum Summon E pickup -> actual I/rightclick learning -> F5/F9 receipts/spent/no respawn; local stand and intro/clock fixtures")
 quit()

func museum_disk_cycle()->bool:
 var path:String=preload("res://scripts/lol2/game_save.gd").slot_path(1)
 var prior:String=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
 await tap(KEY_F5)
 if not require(FileAccess.file_exists(path) and FileAccess.get_sha256(path)!=prior,"Actual Museum F5 writes whole-game slot"):return false
 var before:Node=scene
 await tap(KEY_F9)
 for i in 1800:
  await process_frame
  if current_scene!=before and is_instance_valid(current_scene) and is_instance_valid(current_scene.get("starting_magic")):break
 scene=current_scene;await frames(5)
 return require(scene!=before and hp()>0,"Actual Museum F9 restores living host")
