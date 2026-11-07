extends SceneTree
## Headless, actual Jungle host: the quiet route of fix V4 (docs/poison-paint.md).
## 1. With the Confidante met, the Thieves' Den gives Poison Paint; the inventory's Use ("Apply to weapon") puts one
##    coat on the equipped sword (quest packet weapon_poison, Attack ring tinted) and consumes the paint.
## 2. One real generic strike on Kelsrick: the coat is spent, record 30402 fires alone: Kelsrick dies,
##    GV_KELSRICK_DEAD = 1, the Huline alert (village gate shared29) stays 0, the gate passage arms the alarm timer
##    but the alarm never runs (gates open, no arrows, soul unchanged).
## 3. Mauri's second visit plays the quiet Firestorm scene (600/601, no tunnel): Firestorm in the pack.
## 4. Disk save/load keeps the dead Kelsrick, the empty coats and the items.
## 5. A fresh host, no paint: the same strike raises the alert (shared29 = 1).
const State = preload("res://scripts/lol2/thieves_den_state.gd")
const Poison = preload("res://scripts/lol2/weapon_poison.gd")
const Save = preload("res://scripts/lol2/jungle_save.gd")
const FOOT := 32.0
const YARD := Vector3(-2421,32,-5346)
const PAINT := "jungle:thieves_den:Pois_paint"
const FIRESTORM := "jungle:weapon_shop:Firestorm"
## The world gate needs a captured mouse, which the headless display server never reports (as jungle_kelsrick_live_test).
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var on := true
	func world_active() -> bool: return on
const PASSAGE := Vector2(-1412,-5249)
const OUTSIDE := Vector2(-1412,-5140)
var jungle
var den
var ctrl
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
	return ok
func s() -> Dictionary: return den.state()
func lines() -> Array:
	var out: Array = []
	var st := s()
	if not State.script_active(st): return out
	for e in State.script_effects(st.script.handler,st.script.args):
		if e[0] in ["movie","movie_flags"]: out.append(int(e[2]))
		elif e[0] == "reply": out.append("L%d" % int(e[1]))
		elif e[0] == "load_room": out.append(str(e[1]))
	return out
func settle() -> void:
	for i in range(64):
		den.advance(1000.0)
		if not State.active(s()): break
func open(room: String) -> bool:
	for i in range(100000):
		if s().room == room and (State.script_active(s()) or i > 0): return true
		den.advance(0.25)
		if not den.active() and s().room != room: return false
	return s().room == room
func enter_yard() -> bool:
	jungle.player.position = YARD
	den.was_inside = false
	den._process(0.0)
	return den.active() and s().room == "TEXT"
func set_met_confidant(value: int) -> void:
	var c = jungle.get("confidante")
	if c != null and is_instance_valid(c) and c.get("state") is Dictionary and not c.state.is_empty(): c.state.locals["27"] = value
	else: jungle.quest_state.jungle_confidante = {"version":1,"state":{"locals":{"27":value}},"inside":[]}
func to_mauri() -> bool:
	if not check(enter_yard(),"yard entry"): return false
	settle()
	if not check(den.click(Vector2i(400,280)) and open("TCEL"),"boards -> cellar"): return false
	settle()
	if not check(den.click(Vector2i(300,230)) and open("TDOOR"),"cellar door -> slot door"): return false
	settle()
	if not check(den.click(Vector2i(300,250)) and open("TINT"),"knock -> Mauri"): return false
	return true
func leave_den() -> void:
	settle()
	den.leave_room(); open("TCEL"); settle(); den.leave_room(); open("TEXT"); settle(); den.leave_room()
func shared29() -> int: return int(jungle.village_gate.state().shared29) if is_instance_valid(jungle.get("village_gate")) else -1
func soul() -> int: return int(jungle.quest_state.monastery.globals.get("GV_LUTHERS_SOUL",5))
func face_kelsrick() -> bool:
	var p: Vector3 = ctrl.population.bodies["64"].global_position
	for i in range(16):
		var angle := TAU*float(i%8)/8.0; var distance := 60.0 if i < 8 else 35.0
		jungle.player.global_position = p+Vector3(sin(angle)*distance,FOOT+10,cos(angle)*distance)
		await physics_frame
		jungle.camera.look_at(p+Vector3.UP*30)
		await physics_frame
		if ctrl.population.aimed() == "64": return true
	return false
func place(at: Vector2) -> void:
	jungle.player.global_position = Vector3(at.x,FOOT,at.y)
	jungle.player.velocity = Vector3.ZERO
	await physics_frame
func step(seconds: float) -> void:
	var a = jungle.village_alarm
	for i in int(ceil(seconds*30.0)):
		a.advance(1.0/30.0); jungle.village_gate.advance(1.0/30.0)
		if is_instance_valid(jungle.get("bacatta57")): jungle.bacatta57.advance(1.0/30.0)
		if i%10 == 0: await process_frame
func open_jungle() -> bool:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in range(8): await process_frame
	jungle.set_physics_process(false)
	var spells := TestMagic.new(); spells.host = jungle; jungle.add_child(spells); spells.set_process(false); jungle.starting_magic = spells
	den = jungle.thieves_den; ctrl = jungle.kelsrick
	if not check(den != null and den.available and ctrl != null and is_instance_valid(ctrl) and ctrl.population != null,"den media, Kelsrick and the village alarm must be present"): return false
	den.set_process(false)
	for key in ["monastery","magic_shop","weapon_shop"]:
		var other = jungle.get(key)
		if is_instance_valid(other): other.set_process(false)
	for key in ["bacatta57","dino_population","villager_population","village_alarm","bacatta","exit_woman","dawn","actor62","bacatta65","village_gate","village_dialogue","followup_gate","followup_dialogue","world_items","source_pickups","exit_encounter"]:
		var owner = jungle.get(key)
		if owner != null and is_instance_valid(owner): owner.set_physics_process(false); owner.set_process(false)
	ctrl.set_physics_process(false)
	jungle.quest_state.thieves_den = State.initial(); den.restore()
	jungle.quest_state.monastery.globals["GV_KELSRICK_DEAD"] = 0
	set_met_confidant(1)
	return check(jungle.equipped_item == Save.Museum.SWORD and shared29() == 0,"sword equipped, no alert at the start")
func close_jungle() -> void:
	jungle.queue_free()
	await process_frame
	await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	if not await open_jungle(): return finish()
	# 1. Poison Paint from Mauri, then applied through the inventory.
	check(to_mauri(),"quiet route to Mauri"); settle()
	check(den.click(Vector2i(550,165)) and lines() == [502,503],"Poison Paint click"); settle()
	check(PAINT in jungle.carried_collected,"paint in the pack")
	leave_den()
	check(not den.active() and jungle.is_physics_processing(),"out of the den")
	check(jungle.open_inventory() and is_instance_valid(jungle.inventory),"inventory opens")
	check(jungle.use_inventory_item(PAINT),"Apply to weapon")
	if is_instance_valid(jungle.inventory): jungle.inventory.close()
	await process_frame
	check(not PAINT in jungle.carried_collected and Poison.host_coats(jungle) == 1 and int(jungle.quest_state.weapon_poison.paint) == 1,"one coat, paint consumed")
	check(jungle.interface_hud.weapon_tint == Poison.RING_TINT,"Attack ring tinted green")
	check(not jungle.use_inventory_item(PAINT),"no second paint to apply")
	# 2. One strike on Kelsrick.
	ctrl.set_physics_process(true)
	check(await face_kelsrick(),"an open approach to Kelsrick")
	ctrl.advance(1.0/30.0)
	var health_before: int = int(ctrl.state.health)
	check(ctrl.population.aimed() == "64" and ctrl.population.strike(),"generic strike on Kelsrick")
	check(int(ctrl.population.last_poison) == Poison.FLAG_PAINT and Poison.host_coats(jungle) == 0 and jungle.interface_hud.weapon_tint == Color.WHITE,"the coat is spent by the strike")
	ctrl.advance(1.0/30.0)
	check(int(ctrl.state.health) == 0 and int(ctrl.state.selector) == 16 and int(ctrl.state.locals["52"]) == 1 and int(ctrl.state.locals["8"]) == 30,"Kelsrick dies from one coated strike (31122 then sets local8 = 30) (health was %d)" % health_before)
	check(int(jungle.quest_state.monastery.globals.get("GV_KELSRICK_DEAD",0)) == 1,"GV_KELSRICK_DEAD = 1")
	check(shared29() == 0,"no Huline alert")
	check(30402 in ctrl.state.hit_latches and not 30456 in ctrl.state.hit_latches,"30402 fired, 30456 never")
	for i in range(60): ctrl.advance(1.0/30.0)
	check(shared29() == 0 and int(ctrl.state.health) == 0,"still dead and quiet after a while")
	# The gate passage arms the alarm timer; without the alert it never runs.
	var a = jungle.village_alarm
	var soul_before := soul()
	await place(OUTSIDE); await step(0.1)
	await place(PASSAGE); await step(0.1)
	check(a.running(216),"passage arms control216 timer1")
	await place(OUTSIDE); await step(7.0)
	# No alarm command reached the gate leaves (78/79 keep no target), no arrows, no soul penalty, no alert.
	check(a.movable_target(78) == -1 and a.movable_target(79) == -1 and a.fired_arrows == 0 and soul() == soul_before and shared29() == 0,"alarm inert: no gate command, no arrows, soul unchanged (target78 %d, arrows %d, soul %d/%d, alert %d)" % [a.movable_target(78),a.fired_arrows,soul(),soul_before,shared29()])
	# 3. Mauri's quiet Firestorm scene.
	check(to_mauri() and lines() == [600,"L600",601],"second visit: the quiet Firestorm scene: %s" % [lines()])
	settle()
	check(FIRESTORM in jungle.carried_collected and int(s().flags["18"]) == 0,"Firestorm granted, no tunnel")
	leave_den()
	# 4. Save and reload.
	var path := "user://tests/kelsrick_silent_kill.json"
	check(jungle.quicksave(path).is_empty(),"save")
	check(jungle.quickload(path).is_empty(),"load")
	den = jungle.thieves_den; ctrl = jungle.kelsrick
	check(int(ctrl.state.health) == 0 and int(jungle.quest_state.monastery.globals.get("GV_KELSRICK_DEAD",0)) == 1 and Poison.host_coats(jungle) == 0 and FIRESTORM in jungle.carried_collected and shared29() == 0,"reload keeps the dead Kelsrick, empty coats, Firestorm and no alert")
	var forged: Dictionary = Save.read_save(path).state
	forged.quests.weapon_poison = {"version":1,"paint":5,"sac":5}
	check(not jungle.apply_save(forged).is_empty(),"ten coats in a save are rejected")
	DirAccess.remove_absolute(path)
	await close_jungle()
	# 5. The loud kill without paint still alerts.
	if not await open_jungle(): return finish()
	ctrl.set_physics_process(true)
	check(await face_kelsrick(),"approach again")
	ctrl.advance(1.0/30.0)
	check(ctrl.population.aimed() == "64" and ctrl.population.strike(),"uncoated strike")
	check(int(ctrl.population.last_poison) == 0,"no coat spent")
	ctrl.advance(1.0/30.0)
	check(shared29() == 1 and int(ctrl.state.owner_state) == 40 and int(ctrl.state.health) > 0,"the loud strike raises the alert and wakes Kelsrick")
	await close_jungle()
	finish()
func finish() -> void:
	if failures:
		push_error("FAIL: %d silent kill checks" % failures)
		quit(1)
		return
	print("PASS kelsrick silent kill: den paint -> Apply to weapon (one coat, ring tinted) -> one coated strike kills Kelsrick with GV_KELSRICK_DEAD and no Huline alert (alarm timer armed, inert) -> Mauri's quiet Firestorm -> disk save/load; an uncoated strike still alerts")
	quit()
