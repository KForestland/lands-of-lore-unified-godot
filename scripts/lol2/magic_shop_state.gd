extends RefCounted
const GlobalDefaults = preload("res://scripts/lol2/shared_global_defaults.gd")
## Rashar MAGIC_ room state: entry callbackC9F ordering with a saved modern clock.
## Boundary effects fire once, when the preceding line completes (source order).
## Other handlers (pickup, quip, offer, exit, timer, death) run as saved scripts:
## the effect list is re-derived from the handler and its snapshot inputs.
const Shop = preload("res://scripts/lol2/magic_shop.gd")
const FLAGS := ["46","47","48","49","50","51","52","53","54","55","56","57","58","301"]
const LEGACY_FLAGS := ["49","52","53","54","55","56","57","58"] # Present in every older save.
const LINES := {
	"MAGIC":[400,401,402,403,404,405,406,407,408,409,410,411,412,413,414,416,417,418,419,420,421,422],
	"MAGIC_RETURN":[440,441]}
const FRAMES := {"400":130, "401":69, "402":87, "403":84, "404":80, "405":66, "406":117, "407":17, "408":43, "409":176, "410":68, "411":50, "412":50, "413":51, "414":73, "416":39, "417":56, "418":84, "419":82, "420":52, "421":30, "422":115, "440":19, "441":11}
const SAMPLES := {"400":202124, "401":112454, "402":138914, "403":134504, "404":128624, "405":108044, "406":183014, "407":36014, "408":74234, "409":269744, "410":110984, "411":84524, "412":84524, "413":85994, "414":118334, "416":68354, "417":93344, "418":134504, "419":131564, "420":87464, "421":55124, "422":180074, "440":38954, "441":27194}
# Keyed by the cursor reached: flag53 after404, flag54 after409, host1214 before419,
# host1230 after422.
const BOUNDARIES := {"MAGIC":{5:[["set_flag","53"]],10:[["set_flag","54"]],18:[["mana_debit",1000]],22:[["arm_timer",600]]}}
const MANA_DEBIT := 1000
# Host timer DB4A8 is built with rate0x3C; 600 ticks are treated as ten seconds.
const TIMER_SECONDS := 10.0
# Source group4858 opcode18 flags4: immediate XY, preserve height, bearing0xC000.
const RETURN_POSE := {"x":-1141.0,"z":-5679.0,"bearing":49152}
const ENTRANCE := [Vector2(-1131,-5711),Vector2(-1001,-5711),Vector2(-1000,-5642),Vector2(-1131,-5643)]
const HANDLERS := ["pickup","quip","offer","exit","timer","death"]
# Modern inventory IDs for items Rashar's room gives; fire crystals are three grants.
const ITEMS := {"124-War cluster":["jungle:magic_shop:War_cluster"],"131-Mana foil":["jungle:magic_shop:Mana_foil"],"138-SS5":["jungle:magic_shop:SS5"],
	"57a-Fire crstl":["jungle:magic_shop:Fire_crystals_1","jungle:magic_shop:Fire_crystals_2","jungle:magic_shop:Fire_crystals_3"],
	"28-Dag Light":["jungle:magic_shop:Dag_Light"],"21-Tho fixed":["jungle:magic_shop:Tho_fixed"]}
const OFFER_NAMES := ["12-Tho Broken","10-Th Dagger","83-Power orb"]
const PRESENTATION := ["cursor_hide","cursor_show","stop_loop","hide_sprite","show_sprite","stop_npc"]
static var media_cache: Dictionary = {}

static func initial() -> Dictionary:
	var state := {"room":"","conversation":{"sequence":"","cursor":0,"elapsed":0.0},"flags":{},"timer_armed":false}
	for key in FLAGS: state.flags[key] = 0
	return normalize(state)
## Fills fields introduced after the first MAGIC save format.
static func normalize(state: Dictionary) -> Dictionary:
	for key in FLAGS:
		if not state.flags.has(key): state.flags[key] = 0
	if not state.has("timer_left"): state.timer_left = TIMER_SECONDS if state.get("timer_armed",false) else 0.0
	if not state.has("script"): state.script = idle_script()
	if not state.has("quip_mask"): state.quip_mask = 0
	if not state.has("quip_seed"): state.quip_seed = 20260927
	if not state.has("reward_seed"): state.reward_seed = 324508639
	if not state.has("globals"): state.globals = {"GV_KNOWLEDGE_OF_POWER_ORB":0,"GV_LUTHERS_SOUL":GlobalDefaults.initial_value("GV_LUTHERS_SOUL")}
	if not state.has("pending_items"): state.pending_items = []
	return state
static func idle_script() -> Dictionary:
	return {"handler":"","args":{},"cursor":0,"elapsed":0.0}
static func all_item_ids() -> Array:
	var ids: Array = []
	for name in ITEMS: ids.append_array(ITEMS[name])
	return ids
static func source_name(id: String) -> String:
	for name in ITEMS:
		if id in ITEMS[name]: return name
	return ""

static func duration(sequence: String, index: int) -> float:
	var line := str(LINES[sequence][index])
	return maxf(float(FRAMES[line])/15.0,float(SAMPLES[line])/22050.0)
static func media() -> Dictionary:
	if media_cache.is_empty():
		var offers := "res://assets/lol2/generated/magic_shop_offers/offers.json"
		var speech := "res://assets/lol2/generated/hive_rune_speech/speech.json"
		media_cache = {"clips":{},"sprites":{}}
		var room := "res://assets/lol2/generated/magic_shop/room.json"
		if FileAccess.file_exists(room):
			var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(room)).lines
			for line in lines: media_cache.clips["30:%s:6" % line] = lines[line]
		if FileAccess.file_exists(offers):
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(offers))
			media_cache.clips.merge(data.clips)
			media_cache.sprites = data.sprites
		if FileAccess.file_exists(speech):
			var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(speech)).clips
			for key in lines:
				if str(key).begins_with("2:"): media_cache.clips["%s:24" % key] = lines[key]
	return media_cache
static func clip_key(effect: Array) -> String:
	return "%d:%d:%d" % [int(effect[1]),int(effect[2]),int(effect[3])]
## Seconds a movie request holds the script; requests without shipped media take none.
static func clip_duration(effect: Array) -> float:
	if int(effect[1]) == 30 and FRAMES.has(str(int(effect[2]))):
		var line := str(int(effect[2]))
		return maxf(float(FRAMES[line])/15.0,float(SAMPLES[line])/22050.0)
	return float(media().clips.get(clip_key(effect),{}).get("duration",0.0))
static func is_movie(effect: Array) -> bool:
	return effect[0] in ["movie","movie_flags"]

static func active(state: Dictionary) -> bool:
	var s: Dictionary = state.conversation
	return (not s.sequence.is_empty() and s.cursor < LINES[s.sequence].size()) or script_active(state)
static func conversation_active(state: Dictionary) -> bool:
	var s: Dictionary = state.conversation
	return not s.sequence.is_empty() and s.cursor < LINES[s.sequence].size()
static func script_active(state: Dictionary) -> bool:
	return not str(state.get("script",{}).get("handler","")).is_empty()
static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and value == floorf(value) and value >= low and value <= high
static func _flags_ok(flags: Variant) -> bool:
	if not flags is Dictionary: return false
	for key in flags:
		if not key in FLAGS or not _integer(flags[key],0,1): return false
	return true

## Effects for a saved script; empty when the inputs are not a legal snapshot.
static func script_effects(handler: String, args: Dictionary) -> Array:
	if handler == "quip":
		if not _integer(args.get("line"),0,99) or not int(args.line) in Shop.QUIP_LINES: return []
		return [["movie",2,int(args.line),24]]
	if not _flags_ok(args.get("flags")): return []
	match handler:
		"pickup":
			if not _integer(args.get("sprite"),0,5): return []
			return Shop.pickup(int(args.sprite),args.flags).effects
		"offer":
			if not args.get("held") is String or not args.get("held_id") is String or not args.get("has_broken") is bool or not _integer(args.get("soul"),-1000,1000): return []
			return Shop.offer(args.held,args.flags,args.has_broken,int(args.soul)).effects
		"exit": return Shop.exit_request(args.flags).effects
		"timer": return Shop.timer_expired(args.flags).effects
		"death":
			if not _integer(args.get("message"),6,7) or not _integer(args.get("soul"),-1000,1000): return []
			return Shop.killed(int(args.message),args.flags,int(args.soul)).effects
	return []

static func validate(state: Variant) -> String:
	if not state is Dictionary or not state.get("flags") is Dictionary: return "Invalid magic shop state."
	for key in state.flags:
		if not key in FLAGS: return "Invalid magic shop flag."
	for key in FLAGS:
		if not state.flags.has(key) and key in LEGACY_FLAGS: return "Invalid magic shop flag."
		var value = state.flags.get(key,0)
		if not _number(value) or not (value == 0 or value == 1): return "Invalid magic shop flag."
	var flags: Dictionary = state.flags
	if not state.get("room") is String or not state.room in ["","MAGIC"]: return "Invalid magic shop room."
	if not state.get("timer_armed") is bool: return "Invalid magic shop timer."
	var timer_left = state.get("timer_left",TIMER_SECONDS if state.timer_armed else 0.0)
	if not _number(timer_left) or timer_left < 0 or timer_left > TIMER_SECONDS or (not state.timer_armed and timer_left != 0): return "Invalid magic shop timer."
	for field in ["quip_mask","quip_seed","reward_seed"]:
		if state.has(field) and not _integer(state[field],0,0x1fff if field == "quip_mask" else 0x7fffffff): return "Invalid magic shop history."
	var globals = state.get("globals",{"GV_KNOWLEDGE_OF_POWER_ORB":0,"GV_LUTHERS_SOUL":GlobalDefaults.initial_value("GV_LUTHERS_SOUL")})
	if not globals is Dictionary or globals.size() != 2 or not _integer(globals.get("GV_KNOWLEDGE_OF_POWER_ORB"),0,1) or not _integer(globals.get("GV_LUTHERS_SOUL"),-1000,1000): return "Invalid magic shop globals."
	var pending = state.get("pending_items",[])
	if not pending is Array or pending.size() > 8: return "Invalid magic shop items."
	for name in pending:
		if not name is String or not ITEMS.has(name): return "Invalid magic shop items."
	var s = state.get("conversation")
	if not s is Dictionary or not s.get("sequence") is String or not s.sequence in ["","MAGIC","MAGIC_RETURN"]: return "Invalid magic shop conversation."
	if not _number(s.get("cursor")) or s.cursor != floorf(s.cursor) or s.cursor < 0: return "Invalid magic shop line index."
	if not _number(s.get("elapsed")) or s.elapsed < 0: return "Invalid magic shop clock."
	var error := _validate_script(state,flags,globals)
	if not error.is_empty(): return error
	if s.sequence.is_empty():
		if s.cursor != 0 or s.elapsed != 0: return "Unstarted magic shop line progressed."
		return ""
	var count: int = LINES[s.sequence].size()
	if s.cursor > count: return "Magic shop line index out of range."
	if s.cursor == count:
		if s.elapsed != 0: return "Completed magic shop sequence has a clock."
	elif s.elapsed >= duration(s.sequence,int(s.cursor)): return "Magic shop line already ended."
	if s.cursor < count and state.room != "MAGIC": return "Speaking magic shop room disagrees with save."
	if s.cursor < count and script_active(state): return "Magic shop script overlaps a conversation."
	if s.sequence == "MAGIC":
		if flags["58"] != 1: return "Rashar introduction lacks its start flag."
		for cursor in BOUNDARIES.MAGIC:
			for effect in BOUNDARIES.MAGIC[cursor]:
				if effect[0] == "set_flag" and s.cursor >= cursor and flags[effect[1]] != 1: return "Rashar introduction lost a completed flag."
		if s.cursor < count and state.timer_armed: return "Rashar timer armed during introduction."
	return ""
static func _validate_script(state: Dictionary, flags: Dictionary, globals: Dictionary) -> String:
	if not state.has("script"): return ""
	var script = state.script
	if not script is Dictionary or not script.get("handler") is String or not script.get("args") is Dictionary: return "Invalid magic shop script."
	if script.handler.is_empty():
		if not script.args.is_empty() or script.get("cursor") != 0 or script.get("elapsed") != 0: return "Idle magic shop script progressed."
		return ""
	if not script.handler in HANDLERS: return "Invalid magic shop script."
	if state.room != "MAGIC": return "Magic shop script outside the room."
	var effects := script_effects(script.handler,script.args)
	if effects.is_empty(): return "Invalid magic shop script inputs."
	if not _integer(script.get("cursor"),0,effects.size()-1) or not _number(script.get("elapsed")) or script.elapsed < 0: return "Invalid magic shop script cursor."
	var current: Array = effects[int(script.cursor)]
	# Scripts only persist while a movie holds them.
	if not is_movie(current) or script.elapsed >= clip_duration(current): return "Magic shop script already moved on."
	var timer = null
	for index in range(int(script.cursor)):
		var effect: Array = effects[index]
		if effect[0] == "set_flag" and int(flags.get(str(effect[1]),0)) != 1: return "Magic shop script lost a completed flag."
		if effect[0] == "set_global" and effect[1] == "GV_KNOWLEDGE_OF_POWER_ORB" and int(globals.GV_KNOWLEDGE_OF_POWER_ORB) != 1: return "Magic shop script lost completed knowledge."
		if effect[0] in ["stop_timer","arm_timer"]: timer = effect[0] == "arm_timer"
	if timer != null and state.timer_armed != timer: return "Magic shop script disagrees with its timer."
	return ""

## Region2636 event2 admission. Returns false while any line is still playing.
## An expired host deadline preempts the first-update callback (message10 first).
static func enter(state: Dictionary) -> bool:
	normalize(state)
	if active(state) or state.room != "": return false
	state.room = "MAGIC"
	# Setup handler47C then host F14CC: region trigger bits reset, history kept.
	state.quip_mask = int(state.quip_mask) & 255
	state.conversation = {"sequence":"","cursor":0,"elapsed":0.0}
	# Room update checks the stale host deadline before the first-update callback.
	# Its leading effects are instant and host-free; exit follows line431.
	if state.timer_armed and float(state.timer_left) <= 0.0:
		begin(state,"timer",{"flags":state.flags.duplicate()})
		if script_active(state): return true # Dead Rashar: host stop only, entry continues.
	var plan := Shop.entry(state.flags)
	for flag in plan.set_flags:
		# Only flag58 precedes the first movie; 53/54 follow their lines.
		if str(flag) == "58": state.flags["58"] = 1
	var sequence := ""
	if plan.dialogue == LINES.MAGIC_RETURN: sequence = "MAGIC_RETURN"
	elif not plan.dialogue.is_empty(): sequence = "MAGIC"
	state.conversation = {"sequence":sequence,"cursor":0,"elapsed":0.0}
	return true
## Message8: source exit request advances the visit flags, then leaves.
static func leave(state: Dictionary) -> bool:
	normalize(state)
	if state.room != "MAGIC" or active(state): return false
	begin(state,"exit",{"flags":state.flags.duplicate()})
	return state.room == ""
## Starts a handler script and applies its leading instant effects.
static func begin(state: Dictionary, handler: String, args: Dictionary) -> Array:
	normalize(state)
	if state.room != "MAGIC" or active(state) or script_effects(handler,args).is_empty(): return []
	state.script = {"handler":handler,"args":args,"cursor":0,"elapsed":0.0}
	return advance(state,0.0)
## Advances the saved clock; returns host effects in source order.
static func advance(state: Dictionary, delta: float) -> Array:
	var host_effects: Array = []
	if not is_finite(delta) or delta < 0: return host_effects
	var s: Dictionary = state.conversation
	while conversation_active(state) and delta > 0:
		var remaining := duration(s.sequence,int(s.cursor))-float(s.elapsed)
		if delta < remaining:
			s.elapsed = float(s.elapsed)+delta
			delta = 0.0
			break
		delta -= remaining
		s.cursor = int(s.cursor)+1
		s.elapsed = 0.0
		for effect in BOUNDARIES.get(s.sequence,{}).get(int(s.cursor),[]):
			match effect[0]:
				"set_flag": state.flags[effect[1]] = 1
				"arm_timer":
					state.timer_armed = true
					state.timer_left = TIMER_SECONDS
				_: host_effects.append(effect)
	if conversation_active(state): return host_effects
	host_effects.append_array(_advance_script(state,delta))
	return host_effects
static func _advance_script(state: Dictionary, delta: float) -> Array:
	var host_effects: Array = []
	if not script_active(state): return host_effects
	var script: Dictionary = state.script
	var effects := script_effects(script.handler,script.args)
	while script_active(state):
		if int(script.cursor) >= effects.size():
			state.script = idle_script()
			break
		var effect: Array = effects[int(script.cursor)]
		if is_movie(effect):
			var remaining := clip_duration(effect)-float(script.elapsed)
			if delta < remaining:
				script.elapsed = float(script.elapsed)+delta
				break
			delta -= remaining
			script.cursor = int(script.cursor)+1
			script.elapsed = 0.0
			continue
		script.cursor = int(script.cursor)+1
		match effect[0]:
			"set_flag": state.flags[str(effect[1])] = 1
			"set_global":
				state.globals[effect[1]] = int(effect[2])
				host_effects.append(effect)
			"stop_timer":
				state.timer_armed = false
				state.timer_left = 0.0
			"arm_timer":
				state.timer_armed = true
				state.timer_left = TIMER_SECONDS
			"exit_room":
				state.room = ""
				host_effects.append(effect)
			"consume_held": host_effects.append(["consume_held",script.args.get("held_id","")])
			_:
				if not effect[0] in PRESENTATION: host_effects.append(effect)
	return host_effects
## Host timer: runs in world and room time. Returns true once the deadline passes.
static func tick_timer(state: Dictionary, delta: float) -> bool:
	if not state.get("timer_armed",false) or not is_finite(delta) or delta <= 0: return false
	var before := float(state.timer_left)
	state.timer_left = maxf(0.0,before-delta)
	return before > 0.0 and state.timer_left <= 0.0
## In-room expiry (message10) once no movie is holding the room.
static func poll_timer(state: Dictionary) -> Array:
	if state.room != "MAGIC" or active(state) or not state.timer_armed or float(state.timer_left) > 0.0: return []
	return begin(state,"timer",{"flags":state.flags.duplicate()})
## Message4 through host F133C with a saved LCG standing in for the native RNG.
static func click_region(state: Dictionary, region: int) -> Array:
	normalize(state)
	if state.room != "MAGIC" or active(state): return []
	var plan := Shop.region(region)
	if plan.handled == 0: return []
	var bit := int(plan.effects[0][1])
	var seed := int(state.quip_seed)
	var draws: Array = []
	var seeds: Array = [seed]
	for index in range(16):
		seed = (1103515245*seed+12345)&0x7fffffff
		draws.append(seed%8)
		seeds.append(seed)
	var result := Shop.quip_plan(int(state.quip_mask),bit,draws)
	if result.has("error"): return []
	state.quip_mask = result.mask
	state.quip_seed = seeds[result.draws_used]
	if int(result.line) == 0: return []
	return begin(state,"quip",{"line":int(result.line)})
## Message3 for one sprite; returns [handled, host effects].
static func click_sprite(state: Dictionary, sprite: int) -> Array:
	normalize(state)
	if state.room != "MAGIC" or active(state) or not sprite in Shop.visible_sprites(state.flags): return [false,[]]
	if Shop.pickup(sprite,state.flags).handled == 0: return [false,[]]
	return [true,begin(state,"pickup",{"sprite":sprite,"flags":state.flags.duplicate()})]
## Message5 with the hand item; `held_id` is the modern inventory entry, if any.
static func offer(state: Dictionary, held: String, held_id: String, has_broken: bool) -> Array:
	normalize(state)
	if state.room != "MAGIC" or active(state) or Shop._f(state.flags,52): return []
	return begin(state,"offer",{"held":held,"held_id":held_id,"has_broken":has_broken,"soul":int(state.globals.GV_LUTHERS_SOUL),"flags":state.flags.duplicate()})
## Messages6/7 (no Godot input is bound to these yet).
static func kill(state: Dictionary, message: int) -> Array:
	normalize(state)
	if Shop._f(state.flags,52): return []
	return begin(state,"death",{"message":message,"soul":int(state.globals.GV_LUTHERS_SOUL),"flags":state.flags.duplicate()})
