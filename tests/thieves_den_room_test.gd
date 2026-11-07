extends SceneTree
## Headless, actual Jungle host: the Thieves' Den chain through the room layer's host click router and the shared
## quest banks (docs/thieves-den.md).
## - Region 3642 opens the yard; TEXT's Back places Luther at (-2377, -5337) facing 288 (region 3362).
## - Quiet route with the Confidante met: CELLAR walk-in once, the password door (475, Luther 476), Mauri's first
##   visit, Poison Paint and Skull Key into the pack (new Act 1 ids, saved and reloaded), the farewell, re-entry with
##   the second-visit lines, a mid-line disk save that resumes the same cursor.
## - The door refuses a stranger (one of 509/510/511) and stays dead until the cellar is left.
## - Quiet Kelsrick kill: the Firestorm scene grants "jungle:weapon_shop:Firestorm" once, +100 fighting experience
##   through the shared reward checkpoint, flag 63 mirrored into Kit'yara's shop bank with Luther_has_firestorm.
## - Alert + Kelsrick dead: the free tunnel (TINTTRAN) lands Luther at (-2576, -5154) facing 180, the den closed.
## - Alert + Kelsrick alive: the price; a Fire crystal is kept, the Power Orb is taken and the tunnel opens.
## - F in the den: Damon kills Luther (health 0, the den closed, R recovers).
## - A full pack refuses the shelf items without touching the flags; the pickup works after making room.
const State = preload("res://scripts/lol2/thieves_den_state.gd")
const Den = preload("res://scripts/lol2/thieves_den.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const YARD := Vector3(-2421,32,-5346) # inside region 3642
const PAINT := "jungle:thieves_den:Pois_paint"
const KEY := "jungle:thieves_den:Skull_key"
const FIRESTORM := "jungle:weapon_shop:Firestorm"
const ORB := "monastery:item83:Power_Orb"
var jungle
var den
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
func set_alert(value: int) -> void:
	if is_instance_valid(jungle.get("village_gate")): jungle.village_gate.state().shared29 = value
func set_kelsrick_dead(value: int) -> void:
	jungle.quest_state.monastery.globals["GV_KELSRICK_DEAD"] = value
func to_mauri() -> bool:
	if not check(enter_yard(),"yard entry"): return false
	settle()
	if not check(den.click(Vector2i(400,280)) and open("TCEL"),"boards -> cellar"): return false
	settle()
	if not check(den.click(Vector2i(300,230)) and open("TDOOR"),"cellar door -> slot door"): return false
	settle()
	if not check(den.click(Vector2i(300,250)) and open("TINT"),"knock -> Mauri"): return false
	return true
func back_to_mauri() -> bool:
	settle()
	if not check(den.active() and s().room == "TINT","in the den before leaving"): return false
	den.leave_room()
	if not check(open("TCEL"),"leave to the cellar"): return false
	settle()
	if not check(den.click(Vector2i(300,230)) and open("TDOOR"),"door again"): return false
	settle()
	return check(den.click(Vector2i(300,250)) and open("TINT"),"in again")
func fresh() -> void:
	jungle.quest_state.thieves_den = State.initial()
	den.restore()
	jungle.carried_collected.clear()
	set_kelsrick_dead(0); set_alert(0); set_met_confidant(1)
	if jungle.quest_state.has("weapon_shop"):
		jungle.quest_state.weapon_shop.flags.erase("63"); jungle.quest_state.weapon_shop.locals.erase("Luther_has_firestorm")
func select_hand(id: String) -> bool:
	den._refresh_hand()
	for index in range(den.held.item_count):
		if den.held.get_item_metadata(index) == id:
			den.held.select(index)
			return true
	return false
func experience() -> int:
	return int(jungle.quest_state.get("player_reward_state",{}).get("player",{}).get("experience",-1))
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in range(5): await process_frame
	jungle.set_physics_process(false)
	den = jungle.thieves_den
	if not check(den != null and den.available,"den layer missing or media not staged (tools/prepare_thieves_den_media.py)"): return finish()
	den.set_process(false)
	for key in ["monastery","magic_shop","weapon_shop"]:
		var other = jungle.get(key)
		if is_instance_valid(other): other.set_process(false)
	for key in ["bacatta57","dino_population"]:
		var owner = jungle.get(key)
		if owner != null and is_instance_valid(owner): owner.set_physics_process(false); owner.set_process(false)
	fresh()
	# Entry and the yard's Back.
	check(enter_yard() and not jungle.is_physics_processing() and den.visible,"region 3642 opens the yard")
	settle()
	check(not den.click(Vector2i(100,100)),"a click outside the boards does nothing")
	den.leave_room()
	check(not den.active() and jungle.is_physics_processing(),"Back closes the yard")
	check(is_equal_approx(jungle.player.position.x,-2377) and is_equal_approx(jungle.player.position.z,-5337) and is_equal_approx(jungle.player.position.y,32),"yard leave places Luther at region 3362: %s" % [jungle.player.position])
	check(is_equal_approx(jungle.player.rotation.y,deg_to_rad(198.0)),"facing 288 degrees")
	check(not den.was_inside,"outside the entry polygon after the placement")
	# Quiet route.
	check(to_mauri(),"quiet route reaches Mauri")
	check(lines().slice(0,3) == [401,477,"L477"] and int(s().flags["28"]) == 1,"first visit: %s" % [lines().slice(0,3)])
	check("kelsrick_must_die_quietly" in preload("res://scripts/lol2/my_journal.gd").notes(jungle),"Mauri's first meeting (flag 28) records the quiet-kill My Journal note")
	# Mid-line disk save resumes the same cursor and clock.
	den.advance(1.0)
	var path := "user://tests/thieves_den_room_%d.json" % Time.get_ticks_usec()
	var before: Dictionary = JSON.parse_string(JSON.stringify(s()))
	check(jungle.quicksave(path).is_empty(),"mid-line save")
	den.advance(5.0)
	check(jungle.quickload(path).is_empty(),"mid-line load")
	den = jungle.thieves_den
	check(JSON.parse_string(JSON.stringify(s())) == before and den.active() and den.visible and not jungle.is_physics_processing(),"resume: same cursor and clock")
	settle()
	check(den.click(Vector2i(550,165)) and lines() == [502,503],"Poison Paint click")
	settle()
	check(PAINT in jungle.carried_collected and int(s().flags["21"]) == 1 and not den.sprite_nodes[0].visible and den.sprite_nodes[1].visible,"Poison Paint in the pack, bottle gone")
	check(not den.click(Vector2i(550,165)),"the empty shelf spot is not a hotspot")
	check(den.click(Vector2i(600,150)) and lines() == [29],"Skull Key click")
	settle()
	check(KEY in jungle.carried_collected and int(s().flags["22"]) == 1 and not den.sprite_nodes[1].visible,"Skull Key in the pack, key gone")
	check(Catalog.label(PAINT) == "Pois paint" and Catalog.label(KEY) == "Skull key" and FileAccess.file_exists(Catalog.icon(PAINT)) and FileAccess.file_exists(Catalog.icon(KEY)),"catalog labels and original icons")
	check(Catalog.definition_name(PAINT) == "123-Pois paint" and Catalog.definition_name(KEY) == "93-Skull key","definition names")
	check(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty() and PAINT in jungle.carried_collected and KEY in jungle.carried_collected,"den items survive the disk")
	den = jungle.thieves_den
	settle()
	check(select_hand("") and den.click(Vector2i(400,160)) and lines() == [504],"Mauri with an empty hand: 504")
	settle()
	check(select_hand(KEY) and not den.click(Vector2i(400,160)) and KEY in jungle.carried_collected,"a non-magic item: nothing, kept")
	den.leave_room()
	check(lines() == [507,508],"farewell 507/508")
	check(open("TCEL") and int(s().flags["23"]) == 1 and not State.script_active(s()),"back in the cellar, no walk-in replay")
	check(den.click(Vector2i(300,230)) and open("TDOOR"),"door again"); settle()
	check(den.click(Vector2i(300,250)) and s().room == "TINT" and lines() == [515,516,"L516",517,"L517",518],"silent door, second visit: %s" % [lines()])
	settle()
	den.leave_room(); open("TCEL"); den.leave_room(); open("TEXT"); den.leave_room()
	check(not den.active(),"all the way out")
	# A stranger at the door.
	fresh(); set_met_confidant(0)
	check(enter_yard(),"stranger enters"); settle()
	den.click(Vector2i(400,280)); open("TCEL"); settle(); den.click(Vector2i(300,230)); open("TDOOR"); settle()
	check(den.click(Vector2i(300,250)) and lines().size() == 3 and lines()[1] in [509,510,511] and int(s().flags["270"]) == 1,"wrong answer: %s" % [lines()])
	settle()
	check(not den.click(Vector2i(300,250)) and s().room == "TDOOR","the door is dead")
	den.leave_room(); open("TCEL"); den.leave_room(); open("TEXT")
	check(int(s().flags["270"]) == 0,"revived by leaving the cellar")
	den.leave_room()
	# Quiet kill: the Firestorm scene on the second visit.
	fresh()
	check(to_mauri(),"met Mauri before the kill"); settle()
	set_kelsrick_dead(1)
	var xp := experience()
	check(back_to_mauri() and lines() == [600,"L600",601],"Firestorm scene: %s" % [lines()])
	settle()
	check(FIRESTORM in jungle.carried_collected and jungle.carried_collected.count(FIRESTORM) == 1,"Firestorm in the pack once")
	check(int(jungle.quest_state.weapon_shop.flags.get("63",0)) == 1 and int(jungle.quest_state.weapon_shop.locals.get("Luther_has_firestorm",0)) == 1,"flag 63 and the local mirrored into Kit'yara's bank")
	check(experience() == xp+100 if xp >= 0 else experience() >= 100,"+100 fighting experience: %d -> %d" % [xp,experience()])
	check(int(s().flags["308"]) == 1 and int(s().flags["18"]) == 0,"scene done, no tunnel without the alert")
	check(not "village_hostile_gate_shut" in preload("res://scripts/lol2/my_journal.gd").notes(jungle),"no tunnel note without the alert")
	check(den.click(Vector2i(100,150)) and lines() == [519],"doorway without alert: 519")
	check(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty(),"save with Firestorm validates")
	den = jungle.thieves_den; settle()
	den.leave_room(); open("TCEL"); den.leave_room(); open("TEXT"); den.leave_room()
	# Kit'yara's shop refuses the orb trade after the den's Firestorm (shared flag 63).
	var shop = jungle.weapon_shop
	if is_instance_valid(shop):
		var ws := preload("res://scripts/lol2/weapon_shop_state.gd")
		var probe: Dictionary = jungle.quest_state.weapon_shop.duplicate(true); probe.room = "WPN"; probe.sequence = ""; probe.cursor = 0; probe.elapsed = 0.0
		ws.offer(probe,"83-Power orb")
		check(probe.sequence == "offer_orb_repeat","Kit'yara's orb offer sees the shared Firestorm flag")
	# Alert escape (a): the free tunnel.
	fresh(); check(to_mauri(),"met Mauri"); settle()
	set_kelsrick_dead(1); set_alert(1)
	check(back_to_mauri() and lines() == [600,"L600",601,603,"L603",604,"L604",605,606],"alert scene: %s" % [lines()])
	settle()
	check(int(s().flags["18"]) == 1,"tunnel free")
	check("village_hostile_gate_shut" in preload("res://scripts/lol2/my_journal.gd").notes(jungle),"the tunnel offered with the village roused (flag 18) records its My Journal note")
	check(den.click(Vector2i(100,150)) and lines() == ["TINTTRAN"],"doorway: TINTTRAN")
	den.advance(1.0)
	check(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty() and jungle.thieves_den.state().script.handler == "tint_hotspot","save inside the tunnel walk resumes")
	den = jungle.thieves_den; settle()
	check(not den.active() and jungle.is_physics_processing(),"the den closed after the tunnel")
	check(is_equal_approx(jungle.player.position.x,-2576) and is_equal_approx(jungle.player.position.z,-5154) and is_equal_approx(jungle.player.position.y,2.0) and is_equal_approx(jungle.player.rotation.y,deg_to_rad(90.0)),"outside the palisade at (-2576, -5154) facing 180: %s" % [jungle.player.position])
	# Alert escape (b): the price.
	fresh(); check(to_mauri(),"met Mauri"); settle()
	set_alert(1)
	check(back_to_mauri() and lines() == [550,551,552,"L552",553,"L553"],"second visit under alert: %s" % [lines()])
	settle()
	check(den.click(Vector2i(100,150)) and lines() == [554,556,"L556",557],"the price is asked")
	settle()
	jungle.carried_collected.append("jungle:magic_shop:Fire_crystals_1"); jungle.carried_collected.append(ORB)
	check(select_hand("jungle:magic_shop:Fire_crystals_1") and not den.click(Vector2i(400,160)) and "jungle:magic_shop:Fire_crystals_1" in jungle.carried_collected,"a Fire crystal is refused and kept")
	check(select_hand(ORB) and den.click(Vector2i(400,160)) and lines() == [558,560,"L560","TINTTRAN"],"the Power Orb pays: %s" % [lines()])
	settle()
	check(not ORB in jungle.carried_collected and not den.active() and is_equal_approx(jungle.player.position.x,-2576),"orb gone, outside the palisade")
	# Death.
	fresh(); check(to_mauri(),"met Mauri"); settle()
	check(den.attack(7) and lines() == [993,994],"F in the den: 993, 994")
	settle()
	check(not den.active() and jungle.starting_magic.health() == 0 and jungle.player_fallen(),"Damon kills Luther, the den closes")
	var r := InputEventKey.new(); r.keycode = KEY_R; r.pressed = true
	if is_instance_valid(jungle.dino_population): jungle.dino_population._unhandled_input(r)
	check(jungle.starting_magic.health() > 0 or not is_instance_valid(jungle.dino_population),"R recovers")
	jungle.starting_magic.set_health(30)
	# A full pack: the shelf refuses without touching the flags, then admits after making room.
	fresh(); check(to_mauri(),"met Mauri"); settle()
	var filler: Array = Catalog.ids("jungle").filter(func(id): return id != PAINT and id != KEY)
	while jungle.carried_collected.size() < Catalog.MAX_CARRIED: jungle.carried_collected.append(filler.pop_back())
	check(den.click(Vector2i(550,165)) and int(s().flags["21"]) == 0 and not PAINT in jungle.carried_collected and den.sprite_nodes[0].visible,"full pack: refused, bottle stays")
	jungle.carried_collected.pop_back()
	check(den.click(Vector2i(550,165)) and lines() == [502,503],"after making room: taken")
	settle()
	check(PAINT in jungle.carried_collected,"Poison Paint after the retry")
	den.leave_room(); open("TCEL"); den.leave_room(); open("TEXT"); den.leave_room()
	DirAccess.remove_absolute(path)
	jungle.queue_free()
	await process_frame
	await process_frame
	finish()
func finish() -> void:
	if failures:
		push_error("FAIL: %d thieves den room checks" % failures)
		quit(1)
		return
	print("PASS thieves den room: region 3642 entry, yard placement, quiet route with both items and mid-line disk resume, stranger refused and revived, Firestorm scene (+item, +100 XP, shared flag 63/local), free tunnel to (-2576, -5154), the price (crystal kept, orb taken), Damon's kill with R recovery, full-pack refusal and retry")
	quit()
