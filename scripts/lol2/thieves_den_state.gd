extends RefCounted
## Thieves' Den room chain state (TEXT yard, TCEL cellar, TDOOR slot door, TINT Mauri's den): one saved bank for the
## chain's host flags, the room now open and one saved handler script with a modern clock (the Rashar
## magic_shop_state model). Handler effects are re-derived from the handler name and its snapshot inputs
## (thieves_den.gd), so a saved cursor replays exactly. Host effects (items, experience, placement, the shared
## Firestorm flag/local, Damon's kill) are returned to the caller in source order.
const Den = preload("res://scripts/lol2/thieves_den.gd")
const FLAGS := ["17","18","19","20","21","22","23","24","25","27","28","29","30","31","63","131","132","133","270","271","308"]
const ROOMS := ["","TEXT","TCEL","TDOOR","TINT"]
## Journal hints (owner rule 2026-10-27, data only; VILLAGE_INTENDED_FLOW_20261026 s7). Classic keeps every stuck point
## as the original plays it; each "enhanced_guard" names the Enhanced Edition candidate. "flag" is the den flag (or
## the shared local) whose state the note reads; "" when the note belongs to the world outside the den.
const JOURNAL_HINTS := [
	{"when":"no_confidante_yet","flag":"","hint":"The one who knows the alley's secrets will not show himself until I have heard of Daniel. Kit'yara, the armorer whose hut stands in a glen south-west of the village, may know of him.","enhanced_guard":"Enhanced guard candidate: mark the Confidante's alley once Kit'yara is met"},
	{"when":"hut_smoked_before_password","flag":"131","hint":"Someone in the alley seemed eager to talk before the chief's hut burned; I should have listened.","enhanced_guard":"Enhanced guard candidate: a warning before the fire that the alley talker will be lost"},
	{"when":"password_known_den_unfound","flag":"271","hint":"The word opens a door in a yard on the west side of the village, behind the houses.","enhanced_guard":"none (the yard region3642 is reachable; a map mark in Enhanced)"},
	{"when":"kelsrick_must_die_quietly","flag":"28","hint":"Mauri's paint on a blade would let Kelsrick fall without a sound reaching the guards.","enhanced_guard":"none (the Poison Paint sprite is in the den; Classic as original)"},
	{"when":"village_hostile_gate_shut","flag":"18","hint":"With the village roused, Mauri's tunnel under the den is the only way past the palisade.","enhanced_guard":"Enhanced guard candidate: keep Force gate as the documented fallback when the Confidante is dead (docs/DEVIATIONS.md)"},
	{"when":"firestorm_wanted","flag":"63","hint":"Firestorm: Mauri has a deal in mind, or Kit'yara would part with hers for a Power Orb.","enhanced_guard":"none"}]
const HANDLERS := ["text_setup","tcel_setup","tdoor_setup","tint_setup","text_click","tcel_click","tdoor_click","text_leave","tcel_leave","tdoor_leave","tint_leave","tint_sprite","tint_hotspot","tint_offer","tint_attack"]
## Modern inventory ids for the three grants. Firestorm is the one original definition Kit'yara's shop already grants
## (flag 63 is shared), so the same id is used; the two den items are new Act 1 identities.
const ITEMS := {"123-Pois paint":"jungle:thieves_den:Pois_paint","93-Skull key":"jungle:thieves_den:Skull_key","9-Firestorm":"jungle:weapon_shop:Firestorm"}
const MANIFEST := "res://assets/lol2/generated/thieves_den/rooms.json"
const PRESENTATION := ["cursor_hide","cursor_show","hotspot","actor","idle","load_shapes","show_sprite","hide_sprite","sfx","ambient_start","arm_timer","cancel_timer"]
## Native 0xE8 random(3) at TDOOR 0x5C6 returns 0..3: 0 -> 509, 1 -> 510, else 511. A saved LCG stands in (DEVIATIONS).
const RNG_SEED := 20261027
const REWARD_SEED := 324508639
static var media_cache: Dictionary = {}

static func initial() -> Dictionary:
	var state := {"room":"","flags":{},"script":idle_script(),"next_room":"","rng_seed":RNG_SEED,"reward_seed":REWARD_SEED,"pending_items":[]}
	for key in FLAGS: state.flags[key] = 0
	return state
static func normalize(state: Dictionary) -> Dictionary:
	if not state.has("flags"): state.flags = {}
	for key in FLAGS:
		if not state.flags.has(key): state.flags[key] = 0
	if not state.has("room"): state.room = ""
	if not state.has("script"): state.script = idle_script()
	if not state.has("next_room"): state.next_room = ""
	if not state.has("rng_seed"): state.rng_seed = RNG_SEED
	if not state.has("reward_seed"): state.reward_seed = REWARD_SEED
	if not state.has("pending_items"): state.pending_items = []
	return state
static func idle_script() -> Dictionary:
	return {"handler":"","args":{},"cursor":0,"elapsed":0.0}
static func all_item_ids() -> Array:
	return ITEMS.values()
static func source_name(id: String) -> String:
	for name in ITEMS:
		if ITEMS[name] == id: return name
	return ""
static func flag(state: Dictionary, id: int) -> bool:
	return int(state.flags.get(str(id),0)) != 0

## ---- media / durations -------------------------------------------------------------------------------------------------
static func media() -> Dictionary:
	if media_cache.is_empty():
		media_cache = {"rooms":{},"cues":{},"available":false}
		if FileAccess.file_exists(MANIFEST):
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			media_cache = {"rooms":data.rooms,"cues":data.cues,"available":true}
	return media_cache
static func available() -> bool:
	return media().available
static func clip_key(effect: Array) -> String:
	return "%d:%d:%d" % [int(effect[1]),int(effect[2]),int(effect[3])]
## The staged clip a movie-like effect plays in `room` ({} when none is staged).
static func clip(room: String, effect: Array) -> Dictionary:
	var rooms: Dictionary = media().rooms
	match effect[0]:
		"movie", "movie_flags":
			var key := clip_key(effect)
			if int(effect[1]) == 2 and int(effect[3]) == 24: return media().cues.get(key,{})
			return rooms.get(room,{}).get("clips",{}).get(key,{})
		"load_room":
			for movie in rooms.get(room,{}).get("movies",[]):
				if str(movie.name).ends_with("\\%s.VQA" % effect[1]): return movie
			return {}
		"reply": return rooms.get(room,{}).get("replies",{}).get(str(int(effect[1])),{})
	return {}
static func is_movie(effect: Array) -> bool:
	return effect[0] in ["movie","movie_flags","load_room","reply"]
## Seconds a movie-like effect holds the script; requests without staged media take none.
static func clip_duration(room: String, effect: Array) -> float:
	return float(clip(room,effect).get("duration",0.0))

## ---- scripts -------------------------------------------------------------------------------------------------------------
static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and value == floorf(value) and value >= low and value <= high
static func _flags_ok(flags: Variant) -> bool:
	if not flags is Dictionary: return false
	for key in flags:
		if not key in FLAGS or not _integer(flags[key],0,1): return false
	return true
static func _bool(value: Variant) -> bool: return value is bool
## Luther's reply after a 0x80-flagged line, when TINT.MIX has one (DEVIATIONS row 2).
static func _with_replies(room: String, effects: Array) -> Array:
	if room != "TINT": return effects
	var out: Array = []
	for effect in effects:
		out.append(effect)
		if effect[0] == "movie_flags" and int(effect[4]) & 0x80 and not clip(room,["reply",int(effect[2])]).is_empty(): out.append(["reply",int(effect[2])])
	return out
## Effects for a saved script; empty when the inputs are not a legal snapshot.
static func script_effects(handler: String, args: Dictionary) -> Array:
	var room := handler.get_slice("_",0).to_upper()
	var effects: Array = []
	match handler:
		"text_setup": effects = Den.text_setup().effects+Den.text_first_update().effects
		"tcel_setup":
			if not _flags_ok(args.get("flags")): return []
			effects = Den.tcel_setup(args.flags).effects
		"tdoor_setup": effects = Den.tdoor_setup().effects
		"tint_setup":
			if not _flags_ok(args.get("flags")) or not _bool(args.get("kelsrick_dead")) or not _bool(args.get("alert")) or not _bool(args.get("met_kelsrick")): return []
			effects = Den.tint_setup(args.flags).effects+Den.tint_first_update(args.flags,args.kelsrick_dead,args.alert,args.met_kelsrick).effects
		"text_click":
			if not _integer(args.get("hotspot"),0,7): return []
			effects = Den.text_click(int(args.hotspot)).effects
		"tcel_click":
			if not _integer(args.get("hotspot"),0,7): return []
			effects = Den.tcel_click(int(args.hotspot)).effects
		"tdoor_click":
			if not _integer(args.get("hotspot"),0,7) or not _bool(args.get("met")) or not _bool(args.get("kelsrick_dead")) or not _flags_ok(args.get("flags")) or not _integer(args.get("draw"),0,3): return []
			effects = Den.tdoor_click(int(args.hotspot),args.met,args.kelsrick_dead,args.flags,int(args.draw)).effects
		"text_leave": effects = Den.text_leave().effects
		"tcel_leave": effects = Den.tcel_leave().effects
		"tdoor_leave": effects = Den.tdoor_leave().effects
		"tint_leave":
			if not _flags_ok(args.get("flags")): return []
			effects = Den.tint_leave(args.flags).effects
		"tint_sprite":
			if not _integer(args.get("sprite"),0,1) or not _flags_ok(args.get("flags")): return []
			effects = Den.tint_sprite(int(args.sprite),args.flags).effects
		"tint_hotspot":
			if not _integer(args.get("hotspot"),0,7) or not _flags_ok(args.get("flags")) or not _bool(args.get("alert")): return []
			effects = Den.tint_hotspot(int(args.hotspot),args.flags,args.alert).effects
		"tint_offer":
			if not _flags_ok(args.get("flags")) or not _bool(args.get("holding")) or not _bool(args.get("magic")) or not args.get("held_id") is String: return []
			effects = Den.tint_offer(0,args.flags,args.holding,args.magic,false).effects
		"tint_attack":
			if not _flags_ok(args.get("flags")): return []
			effects = Den.tint_attack(args.flags).effects
		_: return []
	if effects.is_empty(): return []
	return _with_replies(room,effects)
static func script_room(handler: String) -> String:
	return handler.get_slice("_",0).to_upper()
static func script_active(state: Dictionary) -> bool:
	return not str(state.get("script",{}).get("handler","")).is_empty()
static func active(state: Dictionary) -> bool:
	return script_active(state)

## ---- validation ------------------------------------------------------------------------------------------------------------
static func validate(state: Variant) -> String:
	if not state is Dictionary or not state.get("flags") is Dictionary: return "Invalid thieves den state."
	for key in state.flags:
		if not key in FLAGS or not _integer(state.flags[key],0,1): return "Invalid thieves den flag."
	if not state.get("room","") is String or not state.get("room","") in ROOMS: return "Invalid thieves den room."
	if not state.get("next_room","") is String or not state.get("next_room","") in ROOMS: return "Invalid thieves den room."
	for field in ["rng_seed","reward_seed"]:
		if state.has(field) and not _integer(state[field],0,0x7fffffff): return "Invalid thieves den history."
	var pending = state.get("pending_items",[])
	if not pending is Array or pending.size() > 3: return "Invalid thieves den items."
	for name in pending:
		if not name is String or not ITEMS.has(name) or pending.count(name) != 1: return "Invalid thieves den items."
	if not state.has("script"): return ""
	var script = state.script
	if not script is Dictionary or not script.get("handler") is String or not script.get("args") is Dictionary: return "Invalid thieves den script."
	if script.handler.is_empty():
		if not script.args.is_empty() or script.get("cursor") != 0 or script.get("elapsed") != 0: return "Idle thieves den script progressed."
		return ""
	if not script.handler in HANDLERS: return "Invalid thieves den script."
	if state.get("room","") != script_room(script.handler): return "Thieves den script outside its room."
	var effects := script_effects(script.handler,script.args)
	if effects.is_empty(): return "Invalid thieves den script inputs."
	if not _integer(script.get("cursor"),0,effects.size()-1) or not _number(script.get("elapsed")) or script.elapsed < 0: return "Invalid thieves den script cursor."
	var current: Array = effects[int(script.cursor)]
	# Scripts only persist while a movie holds them.
	if not is_movie(current) or script.elapsed >= clip_duration(script_room(script.handler),current): return "Thieves den script already moved on."
	for index in range(int(script.cursor)):
		var effect: Array = effects[index]
		if effect[0] == "set_flag" and int(state.flags.get(str(effect[1]),0)) != 1: return "Thieves den script lost a completed flag."
		if effect[0] == "clear_flag" and int(state.flags.get(str(effect[1]),0)) != 0: return "Thieves den script kept a cleared flag."
	return ""

## ---- entry and handlers ----------------------------------------------------------------------------------------------------
## Region 3642 event 2 (g7338 op12 control134 -> room 44 text_): opens the yard. ctx: kelsrick_dead, alert,
## met_kelsrick, met_confidant (bools), firestorm (bool: the shared flag 63 from Kit'yara's shop).
static func enter(state: Dictionary, ctx: Dictionary) -> bool:
	normalize(state)
	if active(state) or state.room != "": return false
	return _open(state,"TEXT",ctx)
## Loads `room` (callback 1 setup, then callback 9 first update) as one script.
static func _open(state: Dictionary, room: String, ctx: Dictionary) -> bool:
	state.room = room
	if bool(ctx.get("firestorm",false)): state.flags["63"] = 1
	var args := {"flags":state.flags.duplicate()}
	if room == "TINT":
		args.merge({"kelsrick_dead":bool(ctx.get("kelsrick_dead",false)),"alert":bool(ctx.get("alert",false)),"met_kelsrick":bool(ctx.get("met_kelsrick",false))})
	elif room != "TCEL": args = {}
	var handler := room.to_lower()+"_setup"
	state.script = {"handler":handler,"args":args,"cursor":0,"elapsed":0.0}
	return true
## Message 8: Back/Escape.
static func leave(state: Dictionary) -> bool:
	normalize(state)
	if state.room == "" or active(state): return false
	var args := {"flags":state.flags.duplicate()} if state.room == "TINT" else {}
	state.script = {"handler":state.room.to_lower()+"_leave","args":args,"cursor":0,"elapsed":0.0}
	return true
static func _begin(state: Dictionary, handler: String, args: Dictionary) -> bool:
	normalize(state)
	if state.room == "" or active(state) or script_room(handler) != state.room or script_effects(handler,args).is_empty(): return false
	state.script = {"handler":handler,"args":args,"cursor":0,"elapsed":0.0}
	return true
## Message 4 (hotspot click). ctx as enter(); the door also draws from the saved LCG.
static func click_hotspot(state: Dictionary, hotspot: int, ctx: Dictionary) -> bool:
	normalize(state)
	if state.room == "" or active(state): return false
	match state.room:
		"TEXT": return _begin(state,"text_click",{"hotspot":hotspot})
		"TCEL": return _begin(state,"tcel_click",{"hotspot":hotspot})
		"TDOOR":
			var flags: Dictionary = state.flags.duplicate()
			var plan := Den.tdoor_click(hotspot,bool(ctx.get("met_confidant",false)),bool(ctx.get("kelsrick_dead",false)),flags,0)
			if plan.effects.is_empty(): return false
			var draw := 0
			if not bool(ctx.get("met_confidant",false)):
				state.rng_seed = (1103515245*int(state.rng_seed)+12345)&0x7fffffff
				draw = int(state.rng_seed)%4
			return _begin(state,"tdoor_click",{"hotspot":hotspot,"met":bool(ctx.get("met_confidant",false)),"kelsrick_dead":bool(ctx.get("kelsrick_dead",false)),"flags":flags,"draw":draw})
		"TINT":
			var plan := Den.tint_hotspot(hotspot,state.flags,bool(ctx.get("alert",false)))
			if plan.effects.is_empty(): return false
			return _begin(state,"tint_hotspot",{"hotspot":hotspot,"flags":state.flags.duplicate(),"alert":bool(ctx.get("alert",false))})
	return false
## Message 3 (a visible THFSHAPE sprite).
static func click_sprite(state: Dictionary, sprite: int) -> bool:
	normalize(state)
	if state.room != "TINT" or active(state) or not sprite in Den.visible_sprites(state.flags): return false
	return _begin(state,"tint_sprite",{"sprite":sprite,"flags":state.flags.duplicate()})
## Message 5 (Mauri's actor rect with the hand item). `held_id` is the modern inventory entry ("" = empty hand).
static func offer(state: Dictionary, held_id: String, magic: bool) -> bool:
	normalize(state)
	if state.room != "TINT" or active(state): return false
	return _begin(state,"tint_offer",{"flags":state.flags.duplicate(),"holding":not held_id.is_empty(),"magic":magic and not held_id.is_empty(),"held_id":held_id})
## Messages 6/7.
static func attack(state: Dictionary) -> bool:
	normalize(state)
	if state.room != "TINT" or active(state): return false
	return _begin(state,"tint_attack",{"flags":state.flags.duplicate()})

## ---- the clock ---------------------------------------------------------------------------------------------------------------
## Advances the saved script; returns host effects in source order. ctx is needed when a room change opens the next
## room's setup script within the same advance.
static func advance(state: Dictionary, delta: float, ctx: Dictionary = {}) -> Array:
	var host_effects: Array = []
	if not is_finite(delta) or delta < 0: return host_effects
	while script_active(state):
		var script: Dictionary = state.script
		var room := script_room(script.handler)
		var effects := script_effects(script.handler,script.args)
		if int(script.cursor) >= effects.size():
			state.script = idle_script()
			if state.next_room != "":
				_open(state,state.next_room,ctx)
				state.next_room = ""
				continue
			break
		var effect: Array = effects[int(script.cursor)]
		if is_movie(effect):
			var remaining := clip_duration(room,effect)-float(script.elapsed)
			if delta < remaining:
				script.elapsed = float(script.elapsed)+delta
				break
			delta -= remaining
			script.cursor = int(script.cursor)+1
			script.elapsed = 0.0
			continue
		script.cursor = int(script.cursor)+1
		match effect[0]:
			"set_flag":
				state.flags[str(effect[1])] = 1
				# 63 is shared with Kit'yara's WPN room; 28 (Mauri met) and 18 (the tunnel offered while the village is
				# roused) are the moments of two My Journal notes (thieves_den_rooms._apply).
				if int(effect[1]) in [18,28,63]: host_effects.append(effect)
			"clear_flag": state.flags[str(effect[1])] = 0
			"room": state.next_room = str(effect[1])
			"exit_room":
				if state.next_room == "":
					state.room = ""
					host_effects.append(effect)
				else:
					# The next room's setup starts once this script's remaining (instant) effects have run.
					pass
			"take_held_item": host_effects.append(["consume_held",script.args.get("held_id","")])
			"place": host_effects.append(["place",effect[1],effect[2],room])
			_:
				if not effect[0] in PRESENTATION: host_effects.append(effect)
	return host_effects
