extends SceneTree
## Headless: the Thieves' Den planner against the DLL source contract, and the saved chain state without the scene.
## 1. Contract (scripts/lol2/thieves_den_source.json, tools/verify_thieves_den_sources.py): per room, the planner's
##    hotspot/sprite/actor geometry, placements, every movie request it can emit over all handler inputs, the flags it
##    sets/clears, the items it gives and the rooms it names equal the DLL's call lists. No planner request is invented
##    and no DLL request is left out.
## 2. State: the quiet route (yard, cellar intro once, password door, Mauri's first visit, both free items, farewell,
##    second visit), the negative door (one of 509/510/511, dead until the cellar is left), both refusals (Kelsrick
##    dead before Mauri; Firestorm owned without admission), the Firestorm scene (+ item, +XP effect, flags 63/308, no
##    tunnel without alert), both alert escapes (free tunnel after the kill; the price: a non-magic item refused, a
##    magic item taken), the coin eviction, Damon's death, the fourth-visit silence, saves (round trip, forged, legacy).
const Den = preload("res://scripts/lol2/thieves_den.gd")
const State = preload("res://scripts/lol2/thieves_den_state.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
	return ok
static func key(effect: Array) -> String: return "%d:%d:%d" % [int(effect[1]),int(effect[2]),int(effect[3])]
static func same(a: Dictionary, b: Dictionary) -> bool:
	var x: Array = a.keys().map(func(k): return str(k)); x.sort()
	var y: Array = b.keys().map(func(k): return str(k)); y.sort()
	return x == y
func flags_of(ids: Array, mask: int) -> Dictionary:
	var flags := {}
	for i in ids.size(): flags[str(ids[i])] = (mask>>i)&1
	return flags
## Every effect list a room's handlers can produce, over the inputs that matter to each handler.
func planner_effects(room: String) -> Array:
	var out: Array = []
	match room:
		"TEXT":
			out.append_array([Den.text_setup().effects,Den.text_leave().effects,Den.text_first_update().effects])
			for h in range(8): out.append(Den.text_click(h).effects)
		"TCEL":
			for m in range(2): out.append(Den.tcel_setup(flags_of([17],m)).effects)
			for h in range(8): out.append(Den.tcel_click(h).effects)
			out.append(Den.tcel_leave().effects)
		"TDOOR":
			out.append_array([Den.tdoor_setup().effects,Den.tdoor_leave().effects])
			for m in range(16):
				for met in [false,true]:
					for dead in [false,true]:
						for draw in range(4):
							for h in range(2): out.append(Den.tdoor_click(h,met,dead,flags_of([270,63,271,28],m),draw).effects)
		"TINT":
			for m in range(4): out.append(Den.tint_setup(flags_of([21,22],m)).effects)
			for m in range(4):
				for s in range(2): out.append(Den.tint_sprite(s,flags_of([21,22],m)).effects)
			for m in range(8):
				for alert in [false,true]:
					for h in range(8): out.append(Den.tint_hotspot(h,flags_of([18,20,23],m),alert).effects)
			for m in range(2):
				for holding in [false,true]:
					for magic in [false,true]:
						for bit in [false,true]: out.append(Den.tint_offer(0,flags_of([19],m),holding,magic,bit).effects)
			for m in range(2): out.append(Den.tint_attack(flags_of([27],m)).effects)
			for m in range(32): out.append(Den.tint_leave(flags_of([23,24,25,19,18],m)).effects)
			for m in range(64):
				for dead in [false,true]:
					for alert in [false,true]:
						for met in [false,true]: out.append(Den.tint_first_update(flags_of([28,25,24,23,308,63],m),dead,alert,met).effects)
			out.append(Den.tint_timer().effects)
	return out
func contract(source: Dictionary) -> void:
	for room in Den.ROOMS:
		var r: Dictionary = source.rooms[room]
		var requests := {}
		var set_flags := {}
		var cleared := {}
		var items := {}
		var rooms := {}
		var hotspots := {}
		var sprites := {}
		var places := {}
		var headings := {}
		for effects in planner_effects(room):
			for e in effects:
				match e[0]:
					"movie", "movie_flags", "idle": requests[key(e)] = true
					"set_flag": set_flags[int(e[1])] = true
					"clear_flag": cleared[int(e[1])] = true
					"give_item": items[str(e[1])] = true
					"room": rooms[str(e[1])] = true
					"load_room": rooms[str(e[1])] = true
					"hotspot": hotspots[int(e[1])] = [e[2],e[3],e[4],e[5]]
					"show_sprite": sprites[int(e[1])] = [e[2],e[3],e[4]]
					"place": places["%d,%d" % [int(e[1]),int(e[2])]] = true
					"set_heading": headings[int(e[1])] = true
		var want_requests := {}
		for k in r.requests: want_requests[k] = true
		check(same(requests,want_requests),"%s requests: planner %s / DLL %s" % [room,requests.keys(),want_requests.keys()])
		var want := {}
		for f in r.flags.set: want[int(f)] = true
		check(same(set_flags,want),"%s set flags: planner %s / DLL %s" % [room,set_flags.keys(),want.keys()])
		want = {}
		for f in r.flags.cleared: want[int(f)] = true
		check(same(cleared,want),"%s cleared flags: planner %s / DLL %s" % [room,cleared.keys(),want.keys()])
		want = {}
		for n in r.items_given: want[str(n)] = true
		check(same(items,want),"%s items: planner %s / DLL %s" % [room,items.keys(),want.keys()])
		want = {}
		for n in r.rooms: want[str(n).to_upper().trim_suffix("_")] = true
		var named := {}
		for n in rooms: named[str(n).to_upper().trim_suffix("_")] = true
		check(same(named,want),"%s rooms: planner %s / DLL %s" % [room,named.keys(),want.keys()])
		want = {}
		for h in r.hotspots: want[int(h.index)] = [int(h.rect[0]),int(h.rect[1]),int(h.rect[2]),int(h.rect[3])]
		check(str(hotspots) == str(want),"%s hotspots: planner %s / DLL %s" % [room,hotspots,want])
		want = {}
		for s in r.shape_hotspots: want[int(s.index)] = [int(s.x),int(s.y),int(s.frame)]
		check(str(sprites) == str(want),"%s sprites: planner %s / DLL %s" % [room,sprites,want])
		want = {}
		for p in r.placements: want["%d,%d" % [int(p.x),int(p.y)]] = true
		check(same(places,want),"%s placements: planner %s / DLL %s" % [room,places.keys(),want.keys()])
		want = {}
		for h in r.headings: want[int(h.heading)] = true
		check(same(headings,want),"%s headings: planner %s / DLL %s" % [room,headings.keys(),want.keys()])
		if Den.NPC.has(room):
			var a: Dictionary = r.actors[0]
			check(Den.NPC[room] == [int(a.index),int(a.speaker),int(a.x),int(a.y),int(a.width),int(a.height)],"%s actor rect" % room)
	# Luther's replies (DEVIATIONS row 2): exactly the 0x80-flagged TINT lines have a reply entry in the archive.
	var flagged := {}
	for effects in planner_effects("TINT"):
		for e in effects:
			if e[0] == "movie_flags" and int(e[4]) & 0x80: flagged[str(int(e[2]))] = true
	var replies := {}
	for line in source.rooms.TINT.luther_replies: replies[line] = true
	for line in source.rooms.TINT.ambiguous_replies: replies[line] = true
	check(same(replies,flagged),"Luther replies %s / flagged lines %s" % [replies.keys(),flagged.keys()])

## ---- state scenarios -------------------------------------------------------------------------------------------------
## Every request runs its instant effects at once, as the host does; `open` steps the clock until the named room's
## script has started (its lines are then listed by movies()); `settle` runs the clock to idle.
var host_log: Array = []
var ctx := {}
func act(s: Dictionary, ok: bool) -> bool:
	host_log.append_array(State.advance(s,0.0,ctx))
	return ok
func enter(s: Dictionary) -> bool: return act(s,State.enter(s,ctx))
func click(s: Dictionary, hotspot: int) -> bool: return act(s,State.click_hotspot(s,hotspot,ctx))
func sprite(s: Dictionary, id: int) -> bool: return act(s,State.click_sprite(s,id))
func offer(s: Dictionary, id: String, magic: bool) -> bool: return act(s,State.offer(s,id,magic))
func attack(s: Dictionary) -> bool: return act(s,State.attack(s))
func leave(s: Dictionary) -> bool: return act(s,State.leave(s))
func settle(s: Dictionary) -> void:
	for i in range(64):
		host_log.append_array(State.advance(s,1000.0,ctx))
		if not State.active(s): break
func open(s: Dictionary, room: String) -> bool:
	for i in range(100000):
		if s.room == room and (State.script_active(s) or i > 0): return true
		host_log.append_array(State.advance(s,0.25,ctx))
		if not State.active(s) and s.room != room: return false
	return s.room == room
func movies(s: Dictionary) -> Array:
	# Lines of the script now running, in order (movie/movie_flags/reply/load_room).
	var out: Array = []
	if not State.script_active(s): return out
	for e in State.script_effects(s.script.handler,s.script.args):
		if e[0] in ["movie","movie_flags"]: out.append(int(e[2]))
		elif e[0] == "reply": out.append("L%d" % int(e[1]))
		elif e[0] == "load_room": out.append(str(e[1]))
	return out
func to_door(s: Dictionary) -> bool:
	if not check(enter(s) and s.room == "TEXT","enter TEXT"): return false
	settle(s)
	if not check(click(s,0) and open(s,"TCEL"),"yard boards -> cellar"): return false
	settle(s)
	if not check(click(s,2) and open(s,"TDOOR"),"cellar door -> slot door"): return false
	settle(s)
	return true
func to_mauri(s: Dictionary) -> bool:
	if not to_door(s): return false
	if not check(click(s,0) and open(s,"TINT"),"the door -> Mauri"): return false
	return true
func back_to_mauri(s: Dictionary) -> bool:
	# From inside TINT: leave to the cellar, the door, and in again.
	settle(s)
	if not check(leave(s) and open(s,"TCEL"),"leave to the cellar"): return false
	settle(s)
	if not check(click(s,2) and open(s,"TDOOR"),"door again"): return false
	settle(s)
	return check(click(s,0) and open(s,"TINT"),"in again")
func scenarios() -> void:
	var quiet := {"kelsrick_dead":false,"alert":false,"met_kelsrick":false,"met_confidant":true,"firestorm":false}
	ctx = quiet
	# Quiet route.
	var s := State.initial()
	check(enter(s) and s.room == "TEXT" and not State.script_active(s),"yard opens from region 3642 (setup and first update are instant)")
	settle(s)
	check(not State.enter(s,ctx),"no re-entry while open")
	check(not click(s,3),"the yard has one hotspot")
	check(click(s,0) and open(s,"TCEL") and s.script.handler == "tcel_setup" and movies(s) == ["CELLAR"],"CELLAR walk-in on the first visit: %s" % [movies(s)])
	check(State.validate(s).is_empty(),"mid-intro save validates")
	settle(s)
	check(int(s.flags["17"]) == 0,"flag 17 cleared after the intro")
	check(click(s,0) and movies(s) == [26],"front barrel cue 2:26")
	settle(s)
	check(not click(s,4),"shelf bottles do nothing")
	check(click(s,2) and open(s,"TDOOR") and int(s.flags["131"]) == 0,"the door room, dead flags clear")
	settle(s)
	check(click(s,0) and movies(s) == [475,476],"password: 475, Luther 476: %s" % [movies(s)])
	check(State.validate(s).is_empty(),"mid-door save validates")
	check(open(s,"TINT") and int(s.flags["271"]) == 1 and s.script.handler == "tint_setup","admitted into Mauri's den")
	var first := movies(s)
	check(first.slice(0,6) == [401,477,"L477",478,"L478",479] and 493 not in first and 494 not in first and 498 not in first and first.slice(first.size()-2) == [500,501],"first visit lines: %s" % [first])
	check(int(s.flags["28"]) == 1,"Mauri met at the start of the first update")
	settle(s)
	check(int(s.flags["29"]) == 1 and int(s.flags["30"]) == 1 and int(s.flags["31"]) == 1,"first-visit markers")
	check(Den.visible_sprites(s.flags) == [0,1],"both items on the shelf")
	host_log.clear()
	check(sprite(s,0) and movies(s) == [502,503],"Poison Paint: 502, 503")
	settle(s)
	check(["give_item","123-Pois paint",0] in host_log and int(s.flags["21"]) == 1 and Den.visible_sprites(s.flags) == [1],"Poison Paint granted once")
	check(not sprite(s,0),"the bottle is gone")
	host_log.clear()
	check(sprite(s,1) and movies(s) == [29],"Skull Key: cue 2:29")
	settle(s)
	check(["give_item","93-Skull key",0] in host_log and int(s.flags["22"]) == 1 and Den.visible_sprites(s.flags).is_empty(),"Skull Key granted once")
	check(click(s,7) and movies(s) == [26],"sacks: cue 2:26")
	settle(s)
	check(click(s,1) and movies(s) == [993,506,992],"weapon crate warning")
	settle(s)
	check(not click(s,0) and not click(s,4),"the doorway and the shelf say nothing on the first visit")
	check(offer(s,"",false) and movies(s) == [504],"empty hand on Mauri: 504")
	settle(s)
	check(not offer(s,"jungle:thieves_den:Skull_key",false),"a non-magic item: nothing")
	host_log.clear()
	check(leave(s) and movies(s) == [507,508],"first farewell 507/508")
	check(open(s,"TCEL") and int(s.flags["23"]) == 1 and int(s.flags["17"]) == 0 and not State.script_active(s),"back in the cellar, visit 1 counted, no intro replay")
	check(click(s,2) and open(s,"TDOOR"),"door again")
	settle(s)
	check(click(s,0) and s.room == "TINT" and movies(s) == [515,516,"L516",517,"L517",518],"the admitted door opens silently; second visit lines: %s" % [movies(s)])
	settle(s)
	check(click(s,0) and movies(s) == [519],"doorway on the second visit: 519")
	settle(s)
	# Coin eviction: the first click warns, the second throws Luther out of the whole den.
	check(click(s,5) and movies(s) == [993,506,992] and int(s.flags["20"]) == 1,"coins once: warning")
	settle(s)
	host_log.clear()
	check(click(s,5) and movies(s) == [993,994],"coins twice: 993, 994")
	settle(s)
	check(s.room == "" and ["exit_room"] in host_log and int(s.flags["23"]) == 1 and int(s.flags["24"]) == 0,"thrown out of the den without a leave: the visit is not counted")
	# Save round trip and validation.
	var copy: Dictionary = JSON.parse_string(JSON.stringify(s))
	check(State.validate(copy).is_empty(),"closed-den save validates")
	var legacy := {"room":"","flags":{}}
	check(State.validate(legacy).is_empty() and State.normalize(legacy).flags.size() == State.FLAGS.size(),"legacy packet normalizes")
	# Owner rule 2026-10-27: journal hints are data beside the flags; every flag they name is a den flag.
	check(State.JOURNAL_HINTS.size() == 6 and State.JOURNAL_HINTS.all(func(h): return h.has("when") and h.has("flag") and h.has("hint") and h.has("enhanced_guard") and (str(h.flag).is_empty() or str(h.flag) in State.FLAGS)),"journal hints are data beside the den flags")
	var forged: Dictionary = JSON.parse_string(JSON.stringify(State.initial()))
	forged.room = "TINT"; forged.flags["21"] = 1; forged.script = {"handler":"tint_sprite","args":{"sprite":0,"flags":State.initial().flags},"cursor":1,"elapsed":0.5}
	check(State.validate(forged).is_empty(),"a mid-pickup save validates")
	forged.flags["21"] = 0
	check(not State.validate(forged).is_empty(),"a mid-pickup save without flag 21 is refused")
	forged = JSON.parse_string(JSON.stringify(State.initial())); forged.room = "TDOOR"; forged.script = {"handler":"tint_attack","args":{"flags":forged.flags.duplicate()},"cursor":2,"elapsed":0.0}
	check(not State.validate(forged).is_empty(),"a script outside its room is refused")
	forged = JSON.parse_string(JSON.stringify(State.initial())); forged.flags["999"] = 1
	check(not State.validate(forged).is_empty(),"an unknown flag is refused")
	# Negative door: the password is Met_Confidant.
	var stranger := quiet.duplicate(); stranger.met_confidant = false
	ctx = stranger
	s = State.initial()
	check(to_door(s),"stranger reaches the door")
	check(click(s,0),"knock without the password")
	var lines := movies(s)
	check(lines.size() == 3 and lines[0] == 475 and lines[1] in [509,510,511] and lines[2] == 476 and int(s.flags["270"]) == 1 and int(s.flags["131"]) == 1,"wrong answer: %s" % [lines])
	settle(s)
	check(s.room == "TDOOR" and not click(s,0),"the door is dead after the wrong answer")
	check(leave(s) and open(s,"TCEL") and int(s.flags["17"]) == 0,"back in the cellar, no intro"); settle(s)
	check(click(s,2) and open(s,"TDOOR") and not click(s,0),"still dead until the cellar is left"); settle(s)
	check(leave(s) and open(s,"TCEL") and leave(s) and open(s,"TEXT") and int(s.flags["270"]) == 0,"leaving the cellar revives the door")
	settle(s)
	# Native: TCEL replays the CELLAR walk-in on every entry from the yard (flag 17 only marks a return from the door).
	check(click(s,0) and open(s,"TCEL") and movies(s) == ["CELLAR"],"down again: the walk-in replays from the yard"); settle(s)
	check(click(s,2) and open(s,"TDOOR"),"door a third time"); settle(s)
	check(click(s,0) and movies(s).size() == 3,"the knock works again")
	settle(s)
	var draws := {}
	for i in range(40):
		var t := State.initial(); t.rng_seed = 1000+i*7919
		to_door(t); click(t,0); draws[movies(t)[1]] = true
	check(draws.size() == 3,"all three wrong answers reachable: %s" % [draws.keys()])
	check(leave(s) and open(s,"TCEL") and leave(s) and open(s,"TEXT"),"stranger leaves")
	settle(s); host_log.clear()
	check(leave(s),"yard leave"); settle(s)
	check(s.room == "" and ["place",-2377,5337,"TEXT"] in host_log and ["set_heading",288] in host_log,"yard leave places Luther at region 3362")
	# Door after the kill: Kelsrick dead before Mauri was met.
	var killer := quiet.duplicate(); killer.kelsrick_dead = true
	ctx = killer
	s = State.initial()
	check(to_door(s) and click(s,0) and movies(s).is_empty() and s.room == "TDOOR" and int(s.flags["271"]) == 0,"refused (sfx 394 only) after the kill without flag 28")
	# Firestorm from Kit'yara without admission: refused.
	var armed := quiet.duplicate(); armed.firestorm = true
	ctx = armed
	s = State.initial()
	check(to_door(s) and int(s.flags["63"]) == 1 and click(s,0) and movies(s).is_empty() and s.room == "TDOOR" and int(s.flags["271"]) == 0,"refused (sfx 394 only) with Firestorm and no admission")
	# Firestorm scene on the second visit after a quiet kill.
	ctx = quiet
	s = State.initial()
	check(to_mauri(s),"met Mauri")
	ctx = killer
	check(back_to_mauri(s) and movies(s) == [600,"L600",601],"Firestorm scene lines: %s" % [movies(s)])
	host_log.clear(); settle(s)
	check(["give_item","9-Firestorm",0] in host_log and ["set_local","Luther_has_firestorm",1] in host_log and ["add_fighting_xp",100] in host_log and ["set_flag",63] in host_log,"Firestorm, local, experience and the shared flag")
	check(int(s.flags["63"]) == 1 and int(s.flags["308"]) == 1 and int(s.flags["18"]) == 0,"flags 63/308, no tunnel without alert")
	check(click(s,0) and movies(s) == [519],"doorway after the scene without alert: 519")
	check(back_to_mauri(s) and not State.script_active(s) and int(s.flags["24"]) == 1,"third entry after the scene: nothing new")
	check(back_to_mauri(s) and int(s.flags["25"]) == 1 and not State.script_active(s),"fourth entry: silent")
	check(back_to_mauri(s) and not State.script_active(s),"fifth entry: silent (native stuck point)")
	# Alert escape (a): alert + Kelsrick dead -> the Firestorm scene with the tunnel, then the doorway.
	var alert_dead := killer.duplicate(); alert_dead.alert = true
	ctx = quiet
	s = State.initial(); to_mauri(s)
	ctx = alert_dead
	check(back_to_mauri(s) and movies(s) == [600,"L600",601,603,"L603",604,"L604",605,606],"alert Firestorm scene: %s" % [movies(s)])
	settle(s)
	check(int(s.flags["18"]) == 1,"the tunnel is free")
	host_log.clear()
	check(click(s,0) and movies(s) == ["TINTTRAN"],"doorway plays TINTTRAN")
	settle(s)
	check(s.room == "" and ["place",-2576,5154,"TINT"] in host_log and ["set_heading",180] in host_log and int(s.flags["18"]) == 0,"outside the palisade, tunnel flag cleared")
	# The tunnel offer lapses when Luther walks out instead.
	ctx = quiet
	s = State.initial(); to_mauri(s)
	ctx = alert_dead
	back_to_mauri(s); settle(s)
	check(leave(s) and movies(s) == [561,"L561",562,"L562",563],"leaving with the tunnel open: 561-563")
	check(open(s,"TCEL") and int(s.flags["18"]) == 0,"tunnel lapsed")
	# Alert escape (b): Kelsrick alive, the price.
	var alert_alive := quiet.duplicate(); alert_alive.alert = true
	ctx = quiet
	s = State.initial(); to_mauri(s)
	ctx = alert_alive
	check(back_to_mauri(s) and movies(s) == [550,551,552,"L552",553,"L553"],"second visit under alert: %s" % [movies(s)])
	settle(s)
	check(click(s,0) and movies(s) == [554,556,"L556",557],"the doorway asks the price")
	settle(s)
	check(int(s.flags["19"]) == 1,"price pending")
	check(not offer(s,"jungle:magic_shop:Fire_crystals_1",false),"a Fire crystal (non-magic): nothing, kept")
	host_log.clear()
	check(offer(s,"monastery:item83:Power_Orb",true) and movies(s) == [558,560,"L560","TINTTRAN"],"the Power Orb pays: %s" % [movies(s)])
	settle(s)
	check(["consume_held","monastery:item83:Power_Orb"] in host_log and s.room == "" and ["place",-2576,5154,"TINT"] in host_log and int(s.flags["19"]) == 0,"orb taken, outside the palisade")
	# A magic item offered without the price pending: taken for 505.
	ctx = quiet
	s = State.initial(); to_mauri(s); settle(s)
	host_log.clear()
	check(offer(s,"jungle:weapon_shop:Firestorm",true) and movies(s) == [505],"magic item without a price: 505")
	settle(s)
	check(["consume_held","jungle:weapon_shop:Firestorm"] in host_log,"and it is gone")
	# The price lapses on leaving.
	s = State.initial(); to_mauri(s)
	ctx = alert_alive
	back_to_mauri(s); settle(s); click(s,0); settle(s)
	check(leave(s) and movies(s) == [561,"L561",562,"L562",563],"leaving with the price pending: 561-563")
	check(open(s,"TCEL") and int(s.flags["19"]) == 0,"price lapsed")
	# Third visit, alive, alert: 575-577 and Luther stays; alive and quiet: thrown out with 525-527.
	ctx = quiet
	s = State.initial(); to_mauri(s); back_to_mauri(s); settle(s)
	check(leave(s) and open(s,"TCEL"),"second leave"); settle(s)
	var third: Dictionary = JSON.parse_string(JSON.stringify(s))
	ctx = alert_alive
	check(click(s,2) and open(s,"TDOOR") and click(s,0) and open(s,"TINT") and movies(s) == [575,"L575",576,"L576",577],"third visit under alert: %s" % [movies(s)])
	settle(s)
	check(s.room == "TINT","stays")
	ctx = quiet
	s = third
	check(click(s,2) and open(s,"TDOOR") and click(s,0) and open(s,"TINT") and movies(s) == [525,526,527],"third quiet visit: 525-527")
	settle(s)
	check(s.room == "TCEL" and int(s.flags["17"]) == 0,"thrown out into the cellar")
	# Damon's death.
	s = State.initial(); to_mauri(s); settle(s)
	host_log.clear()
	check(attack(s) and movies(s) == [993,994] and int(s.flags["27"]) == 1,"attack: 993, 994")
	settle(s)
	check(["damage",-1] in host_log and ["exit_room"] in host_log and s.room == "","Luther dies and the den closes")
	check(not attack(s),"no second attack outside the den")

func run() -> void:
	if not check(State.available(),"thieves_den media manifest missing (tools/prepare_thieves_den_media.py)"): return finish()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/thieves_den_source.json"))
	contract(source)
	scenarios()
	finish()
func finish() -> void:
	if failures:
		push_error("FAIL: %d thieves den state checks" % failures)
		quit(1)
		return
	print("PASS thieves den state: planner matches the four DLL call lists (requests, flags, items, rooms, geometry, placements, replies); quiet route, negative door, both refusals, Firestorm scene, both alert escapes, lapses, evictions, death, stuck point, saves")
	quit()
