extends "res://tests/helpers/g15_spell_input.gd"
## Pinned game-written component checkpoint, not an unaided earned walk.
## One living-actor fixture proves the web is not held by the Ruloi (native control:103), then real E enters.
const Journal=preload("res://scripts/lol2/my_journal.gd")
func _initialize():main.call_deferred()
func main():
 if not await boot_legacy("res://tmp/l13_belial_ring_qualified_save.json","2801b3e6957b91b0a578bd7873d9f266bc81cda8f09ed91c305015ee14541aab","lol2-restoration-map-L13_RC","res://scenes/lol2/maps/L13_RC.tscn"):return
 scene.act2_creatures.set_physics_process(false)
 var entry=scene.get_node("L13Belial")
 if not await look(entry.WEB+Vector3.UP*32):return
 if not require(entry.near_web() and scene.get_node("L13Prison").all_ruloi_dead(),"Checkpoint grounded at the genuine completed-prison web"):return
 # Native control:103 (group 8770 under local 0x0E == 0) has no Ruloi predicate (owner F10 01-22-38, lead 2026-11-16):
 # with a Ruloi alive the web offers its entry; the all-Ruloi count belongs to the maidens.
 scene.act2_creatures.state.actors["21"].health=1
 await frames(10)
 if not require(scene.interface_hud.hint.text=="E - pass the web" and entry.can_enter(),"A living Ruloi does not hold the web; the exact E action shows"):return
 # Restore the checkpoint's original zero before the entry and disk cycle (a living hostile refuses F5).
 scene.act2_creatures.state.actors["21"].health=0
 await frames(10)
 await tap(KEY_E)
 if not require(entry.playing and paused,"Actual E still starts original movie31, never intercepted by hint"):return
 await tap(KEY_ESCAPE);await frames(10)
 if not require(entry.state().entered and not paused and hp()>0 and scene.resets==0,"Actual movie skip retains original arena admission alive"):return
 if not require(Journal.notes(scene).count("l13_action_web_pass")==1 and Journal.notes(scene).count("l13_action_web_living")==0,"Web entry Journal once, no living-Ruloi note"):return
 if not await disk_cycle("web_action_hints"):return
 if not require(scene.get_node("L13Belial").state().entered and Journal.notes(scene).count("l13_action_web_pass")==1,"Actual F5/F9 retains the note and original entry"):return
 print("PASS web entry with a Ruloi alive (native control103 has no Ruloi predicate), original movie31/realEscape, F5/F9 one note each; pinned legacy component, actor-health/NPC-hold fixtures, ordinary1/60")
 quit()
