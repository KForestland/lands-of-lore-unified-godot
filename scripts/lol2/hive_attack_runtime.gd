extends RefCounted
## Executioner attack core, checked against pinned native instruction replay.
## Input uses native timer units. Output requests have no implicit health/audio effects.
## The caller owns AI admission, real-time conversion and synchronous callback effects.
const CONTRACT := "res://assets/lol2/generated/hive_attack/attack.json"
const SAVE_VERSION := 2
var _clips: Dictionary = {}
var _state: Dictionary = {}
var _advancing := false
var _source_adjustments: Dictionary = {}
var _source_ai_adjustments: Dictionary = {}

func _init(supplied_contract: Dictionary = {}) -> void:
	var contract = supplied_contract.duplicate(true) if not supplied_contract.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	assert(contract is Dictionary and contract.version == 1)
	for clip in contract.clips:
		_clips[int(clip.selector)] = clip
	_state = {"version":SAVE_VERSION,"selector":12,"frame":0,"timer":0,
		"reverse":false,"flags":0,"base":0,"gate":false,"frozen":false,"result_total":0,"result_count":0}

static func action_selector(mask: int, mode: int) -> int:
	var effective := 1 if (mode & 3) > 1 else mask & 255
	return 12 if effective & 1 and not effective & 6 else 11

func select_attack(selector: int) -> bool:
	if _advancing or not _clips.has(selector) or selector == int(_state.selector): return false
	_state.selector = selector
	_state.frame = 0
	_state.timer = 0
	return true

func checkpoint() -> Dictionary:
	return {} if _advancing else _state.duplicate(true)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func validate(state: Variant) -> String:
	if not state is Dictionary: return "Invalid attack state."
	if not _integer(state.get("version"),1,SAVE_VERSION): return "Unsupported attack save version."
	var selector = state.get("selector")
	if not _integer(selector,0,255) or not _clips.has(int(selector)): return "Invalid attack selector."
	if not _integer(state.get("frame"),0,int(_clips[int(selector)].frames)-1): return "Invalid attack frame."
	if not _integer(state.get("timer"),0,int(_clips[int(selector)].interval)-1): return "Invalid attack timer."
	for key in ["flags","base"]:
		if not _integer(state.get(key),0,255): return "Invalid attack byte."
	for key in ["reverse","gate","frozen"]:
		if not state.get(key) is bool: return "Invalid attack control flag."
	if int(state.version) == 2:
		if not _integer(state.get("result_total"),0,65535): return "Invalid attack result total."
		if not _integer(state.get("result_count"),0,255): return "Invalid attack result count."
	return ""

func restore(state: Variant) -> String:
	if _advancing: return "Cannot restore during attack feedback."
	var error := validate(state)
	if not error.is_empty(): return error
	var next := {}
	for key in ["version","selector","frame","timer","flags","base"]: next[key] = int(state[key])
	for key in ["reverse","gate","frozen"]: next[key] = state[key]
	next.result_total = int(state.result_total) if int(state.version) == 2 else 0
	next.result_count = int(state.result_count) if int(state.version) == 2 else 0
	next.version = SAVE_VERSION
	_state = next
	return ""

static func validate_feedback(reply: Variant) -> String:
	if not reply is Dictionary: return "Invalid attack feedback."
	if reply.has("callback") and not reply.callback is bool: return "Invalid feedback callback control."
	for key in ["loss","percentage"]:
		if not _integer(reply.get(key),0,4294967295): return "Invalid attack feedback value."
	# Lethal responses require the full target/AI continuation, still unbound.
	if not _integer(reply.get("remaining"),1,4294967295): return "Feedback requires a surviving target."
	return ""

func advance_native(delta: Variant, damage_feedback: Callable = Callable()) -> Dictionary:
	if _advancing: return {"error":"Cannot advance recursively during feedback.","events":[]}
	# Restrict the public contract to nonnegative signed-word deltas. Larger host
	# updates must establish the original clock policy before splitting them.
	if not _integer(delta,0,32767): return {"error":"Invalid native attack delta.","events":[]}
	var before := _state.duplicate(true)
	_advancing = true
	var output: Array = []
	if not _state.frozen:
		_state.timer -= int(delta)
		var clip: Dictionary = _clips[_state.selector]
		var last := int(clip.frames)-1
		while _state.timer < 0:
			_state.timer += int(clip.interval)
			var previous := int(_state.frame)
			if _state.reverse:
				_state.frame = last if previous == 0 else previous-1
			else:
				_state.frame = 0 if previous >= last else previous+1
			var terminal: bool = (previous > 0 and _state.frame == 0) if _state.reverse else (previous < last and _state.frame == last)
			var damage: Dictionary = {}
			for event in clip.events:
				if int(event.frame) != _state.frame: continue
				var raw: PackedByteArray = event.raw_hex.hex_decode()
				if int(event.kind) == 2:
					output.append({"type":"sound","frame":_state.frame,"id":int(raw[2]) | (int(raw[3]) << 8)})
				elif int(event.kind) == 1: damage = event
			if terminal:
				output.append({"type":"terminal","frame":_state.frame,"event":3})
				_state.timer = maxi(0,_state.timer)
			if not damage.is_empty():
				if _state.flags & 16:
					output.append({"type":"adjustment","frame":_state.frame,"operation":8})
				else: _state.flags |= 16
				var raw: PackedByteArray = damage.raw_hex.hex_decode()
				var amount := int(_state.base * int(raw[2]) / 100)
				if _state.flags & 1 and _state.gate and amount > 0:
					output.append({"type":"damage","frame":_state.frame,
						"mask":int(raw[4]) | (int(raw[5]) << 8),"flags":int(raw[6]) | (int(raw[7]) << 8),"amount":amount})
					if damage_feedback.is_valid():
						# Resolver returns data only; no external health/audio side effects.
						var reply = damage_feedback.call(output.back().duplicate(true))
						var error := validate_feedback(reply)
						if not error.is_empty():
							_state = before
							_advancing = false
							return {"error":error,"events":[]}
						if reply.get("callback",true):
							_state.flags |= 8
							if _state.flags & 16 and int(reply.loss) != 0:
								output.append({"type":"adjustment","frame":_state.frame,"operation":7})
								_state.flags &= 239
							_state.result_total = (_state.result_total + int(reply.percentage)) & 65535
							_state.result_count = (_state.result_count + 1) & 255
	_advancing = false
	return {"state":{"selector":_state.selector,"frame":_state.frame,"timer":_state.timer,"flags":_state.flags},"events":output}

static func apply_stat_adjustments(stats: Variant, rows: Variant, events: Variant) -> Dictionary:
	# Explicit caller-supplied30-byte bank and signed rows; no guessed EXEC values.
	if not stats is Array or stats.size() != 30: return {"error":"Invalid attack stat bank."}
	for value in stats:
		if not _integer(value,0,255): return {"error":"Invalid attack stat byte."}
	if not rows is Dictionary or not events is Array: return {"error":"Invalid adjustment input."}
	for key in rows:
		if key not in ["7","8"] or not rows[key] is Array or rows[key].size() != 30: return {"error":"Invalid adjustment row."}
		for value in rows[key]:
			if not _integer(value,-128,127): return {"error":"Invalid signed adjustment."}
	var result: Array = stats.duplicate()
	for event in events:
		if not event is Dictionary or event.get("type") not in ["sound","damage","terminal","adjustment"]: return {"error":"Invalid attack event."}
		if event.type != "adjustment": continue
		if not _integer(event.get("operation"),7,8): return {"error":"Unsupported adjustment operation."}
		var key := str(int(event.operation))
		if not rows.has(key): return {"error":"Missing adjustment row."}
		for i in range(30): result[i] = clampi(int(result[i])+int(rows[key][i]),0,255)
	return {"stats":result}

func apply_executioner_adjustments(stats: Variant, events: Variant) -> Dictionary:
	# Rows recovered from GLOBAL.MIX/global/ai/EXEC/effector.csv. Initial bank
	# remains supplied until the live actor initializer is composed.
	if _source_adjustments.is_empty():
		var path := "res://assets/lol2/generated/hive_attack/adjustments.json"
		if not FileAccess.file_exists(path): return {"error":"Executioner adjustment data is missing."}
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.get("version") != 1 or not data.get("rows") is Dictionary:
			return {"error":"Invalid executioner adjustment data."}
		if not data.rows.has("7") or not data.rows.has("8"): return {"error":"Incomplete executioner adjustment data."}
		# Validate before caching, including all signed row values.
		var probe: Array = []
		probe.resize(30);probe.fill(0)
		if apply_stat_adjustments(probe,data.rows,[]).has("error"): return {"error":"Invalid executioner adjustment rows."}
		_source_adjustments = data.rows.duplicate(true)
	return apply_stat_adjustments(stats,_source_adjustments,events)

static func damage_split(total: Variant, minimum: Variant, first: Variant, second: Variant) -> int:
	for value in [total,minimum,first,second]:
		if not _integer(value,0,255): return -1
	if first == 0: return maxi(int(minimum),1)
	# Native early return bypasses the minimum on this branch.
	if second == 0: return int(total)
	return maxi(int(minimum),int(int(total)*int(first)/(int(first)+int(second))))

func executioner_initial_stats(reduced: bool) -> Dictionary:
	# Explicit incoming A3 condition for reused/supplied actor state.
	var path := "res://assets/lol2/generated/hive_attack/initial_stats.json"
	if not FileAccess.file_exists(path): return {"error":"Executioner initial stat data is missing."}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1: return {"error":"Invalid executioner initial stat data."}
	var validated := apply_stat_adjustments(data.get("stats"),{},[])
	if validated.has("error"): return validated
	if not data.get("copied_tail") is Array or data.copied_tail.size() != 2: return {"error":"Invalid copied stat tail."}
	for value in data.copied_tail:
		if not _integer(value,0,255): return {"error":"Invalid copied stat tail byte."}
	var result := recompute_attack_stats(validated.stats,data.get("total"),data.get("minimum"),reduced)
	if result.has("error"): return result
	result["stats"] = validated.stats
	result["copied_tail"] = data.copied_tail.duplicate()
	return result

func executioner_fresh_stats() -> Dictionary:
	# Verified Hive source-construction pass: actor36 arrives zeroed, A3=0.
	# Creation only. Do not replace restored or subsequently adjusted state.
	var result := executioner_initial_stats(false)
	if result.has("error"): return result
	result["a3"] = 0
	return result

static func recompute_attack_stats(stats: Variant, total: Variant, minimum: Variant, reduced: bool) -> Dictionary:
	# AA3DB uses the persistent bank; final AB053 uses a temporary bank after
	# AI adjustments. Caller supplies the appropriate bank and scheduling.
	# Return derived values without mutating either bank or live state.
	var validated := apply_stat_adjustments(stats,{},[])
	if validated.has("error"): return validated
	var base := damage_split(total,minimum,validated.stats[3],validated.stats[2])
	if base < 0: return {"error":"Invalid executioner damage definition."}
	var reserve := (int(total)-base) & 255
	if reduced:
		base -= int(base/4)
		reserve -= int(reserve/4)
	return {"base":base,"reserve":reserve}


func configure_ai_adjustments(data: Variant) -> String:
	if not data is Dictionary or data.get("version") != 1: return "Invalid AI adjustment data."
	for field in {"goals":14,"conditions":49}:
		var count: int=14 if field=="goals" else 49
		if not data.get(field) is Array or data[field].size()!=count: return "Incomplete AI adjustment data."
		for row in data[field]:
			if not row is Array or row.size()!=30: return "Invalid AI adjustment row."
			for value in row:
				if not _integer(value,-128,127): return "Invalid AI adjustment byte."
	_source_ai_adjustments=data.duplicate(true)
	return ""

func executioner_effective_stats(stats: Variant, goal: Variant, true_conditions: Variant) -> Dictionary:
	# AA208 copies the persistent bank, applies global goal then condition rows
	# in ascending index order, and uses the temporary bank for its final split.
	var validated := apply_stat_adjustments(stats,{},[])
	if validated.has("error"): return validated
	if not _integer(goal,0,255) or not true_conditions is Array:
		return {"error":"Invalid AI adjustment selection."}
	var selected: Array[int] = []
	for condition in true_conditions:
		if not _integer(condition,0,48) or int(condition) in selected:
			return {"error":"Invalid or duplicate AI condition."}
		selected.append(int(condition))
	selected.sort()
	if _source_ai_adjustments.is_empty():
		var path := "res://assets/lol2/generated/hive_attack/ai_adjustments.json"
		if not FileAccess.file_exists(path): return {"error":"Executioner AI adjustment data is missing."}
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		var error:=configure_ai_adjustments(data)
		if not error.is_empty(): return {"error":error}
	var rows: Array = []
	if int(goal) < 14: rows.append(_source_ai_adjustments.goals[int(goal)])
	for condition in selected: rows.append(_source_ai_adjustments.conditions[condition])
	var result: Array = validated.stats
	for row in rows:
		for i in range(30): result[i] = clampi(int(result[i])+int(row[i]),0,255)
	return {"stats":result}

static func executioner_actor_conditions(stats: Variant, feedback: Variant, target_flags: Variant, group: Variant, flags_b8: Variant, flags_b4: Variant) -> Dictionary:
	# Partial predicate evaluator: geometry, player and global conditions must be
	# resolved separately before the caller has a complete effective-stat input.
	var validated := apply_stat_adjustments(stats,{},[])
	if validated.has("error"): return validated
	if not _integer(feedback,0,65535) or not _integer(target_flags,0,255) or not _integer(group,0,255) or not _integer(flags_b8,0,4294967295) or not _integer(flags_b4,0,4294967295):
		return {"error":"Invalid actor condition fields."}
	var conditions: Array[int] = [1 if target_flags != 0 else 2]
	if feedback != 0: conditions.append(3 if feedback < 32768 else 4)
	# The native threshold chain substitutes1000 after a match, making these
	# four bands exclusive rather than four independent less-than comparisons.
	conditions.append(5+int(validated.stats[4])/64)
	conditions.append(45+int(validated.stats[25])/64)
	if group != 255: conditions.append(40)
	if int(flags_b8) & 256: conditions.append(42)
	if int(flags_b4) & 16777216: conditions.append(44)
	conditions.sort()
	return {"conditions":conditions,"evaluated":[1,2,3,4,5,6,7,8,10,11,38,39,40,42,44,45,46,47,48],"complete":false}
