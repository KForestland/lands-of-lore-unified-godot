extends RefCounted
## Museum Sk-key locks (controls78/87/88/113/114/140-151) and the movable55 SS1 panel: saved state and pure transitions.
## Source: scripts/lol2/museum_key_locks_source.json (tools/prepare_museum_key_locks.py). A lock is "loaded" when it
## holds the key. Mode3 consumes the held key and loads the lock; mode0 empties it and grants exactly one key.
## Only control87 starts loaded, so exactly one key exists: in one lock, or carried (never both, never two).
## The panel holds "68-SS1" while panel_state is 0 and can be reached only while lock114 is loaded.
const LOCKS := [78,87,88,113,114,140,141,142,143,144,145,146,147,148,149,150,151]
const KEY := "museum:control87:Sk_key"
const SS1 := "museum:movable55:SS1"

static func initial() -> Dictionary:
	return {"version":1,"loaded":[87],"panel_state":0}

static func validate(value: Variant, collected: Variant = null) -> String:
	if not value is Dictionary or value.size() != 3: return "Invalid key-lock packet."
	var version = value.get("version")
	if not (version is int or version is float) or version != 1: return "Invalid key-lock version."
	var loaded = value.get("loaded")
	if not loaded is Array or loaded.size() > 1: return "Invalid loaded key locks."
	for id in loaded:
		if not (id is int or id is float) or id != int(id) or int(id) not in LOCKS: return "Invalid loaded key lock."
	var panel = value.get("panel_state")
	# JSON numbers arrive as floats: compare by value, never by Array membership.
	if not (panel is int or panel is float) or not (panel == 0 or panel == 1): return "Invalid SS1 panel state."
	if collected == null: return ""
	if not collected is Array: return "Invalid key-lock inventory."
	# Conservation: the single original key is either in one lock or carried.
	if loaded.size() + collected.count(KEY) != 1: return "Inconsistent Sk key count."
	if collected.count(SS1) > 1 or (int(panel) == 1) != (SS1 in collected): return "Inconsistent SS1 panel item."
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	var ids: Array = []
	for id in value.loaded: ids.append(int(id))
	return {"version":1,"loaded":ids,"panel_state":int(value.panel_state)}

static func is_loaded(state: Dictionary, lock: int) -> bool: return lock in state.loaded

## Source group admission for a lock given the held item; "" when neither original record would run.
static func group(state: Dictionary, lock: int, held: String) -> String:
	if lock not in LOCKS: return ""
	if is_loaded(state, lock): return "take" if held == "" else ""
	return "insert" if held == KEY else ""

## Applies one lock group to state and the carried/hand inventory; returns the effects to present, or [] if refused.
static func run(state: Dictionary, lock: int, inventory: Dictionary) -> Array:
	var held: String = inventory.hand
	var kind := group(state, lock, held)
	if kind == "insert":
		if not KEY in inventory.collected: return []
		inventory.collected.erase(KEY)
		inventory.hand = ""
		state.loaded = [lock]
	elif kind == "take":
		if KEY in inventory.collected: return []
		state.loaded = []
		inventory.collected.append(KEY)
		# The take group grants into the hand cursor, like the Broken Thohan case (control181).
		inventory.hand = KEY
	else:
		return []
	return [kind, lock]

## Movable55 records: mode0 at state0 gives SS1 (state1), mode3 holding SS1 at state1 returns it (state0).
static func panel_group(state: Dictionary, held: String) -> String:
	if not is_loaded(state, 114): return ""
	if int(state.panel_state) == 0 and held == "": return "give"
	if int(state.panel_state) == 1 and held == SS1: return "put_back"
	return ""

static func run_panel(state: Dictionary, inventory: Dictionary) -> String:
	var kind := panel_group(state, inventory.hand)
	if kind == "give":
		if SS1 in inventory.collected: return ""
		inventory.collected.append(SS1)
		inventory.hand = SS1
		state.panel_state = 1
	elif kind == "put_back":
		inventory.collected.erase(SS1)
		inventory.hand = ""
		state.panel_state = 0
	return kind

## Derived target states (control113 selector1 lights sconces117-139; control140 opens grate51 and sets lever53;
## control114 lowers movable55).
static func sconces_lit(state: Dictionary) -> bool: return is_loaded(state, 113)
static func panel_lowered(state: Dictionary) -> bool: return is_loaded(state, 114)
static func gallery_open(state: Dictionary) -> bool: return is_loaded(state, 140)
