extends RefCounted
## Champion Stone definition 123, handler 4.
## While active, weapon stat 236E4 (controller 23348 member 39C) is 20 higher.
## Activation adds 3600 to timer 23AC1's high word and keeps the low word.
## maintain() subtracts one caller-supplied global 22C54 sample.
## Event 8's schedule is not bound, so this timer is not a duration in seconds.
## Ancient Stone handler 6 is not applied. Cave Aloe handler 9 is owned by
## cave_aloe_effect.gd and the live player_item_controller, outside this stone API.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Ancient = preload("res://scripts/lol2/hive_ancient_stone.gd")
const Aloe = preload("res://scripts/lol2/cave_aloe.gd")
const VERSION := 1
const BONUS := 20
const HIGH_WORD_EXTEND := 3600
const CHAMPION_DEFINITION := 123
const CHAMPION_IDENTITY := 4234311831
const CHAMPION_HANDLER := 4
const CHAMPION_IDS := ["museum:item8:Champion_Stone", "museum:item9:Champion_Stone"]
const ANCIENT_DEFINITION := 68
const ANCIENT_IDENTITY := 3764690106
const ANCIENT_HANDLER := 6
const ALOE_DEFINITION := 110
const ALOE_IDENTITY := 3732130108
const ALOE_HANDLER := 9

static func empty() -> Dictionary:
	return {"version": VERSION, "active": false, "timer": 0}

static func restore(saved: Variant) -> Dictionary:
	var error := _state_error(saved)
	if error != "": return {"error": error}
	return {"state": _canonical(saved)}

static func checkpoint(state: Variant) -> Dictionary:
	var restored := restore(state)
	if restored.has("error"): return restored
	return {"checkpoint": restored.state}

static func is_champion_stone(item_id: Variant) -> bool:
	return item_id is String and item_id in CHAMPION_IDS

static func describe(item_id: Variant) -> Dictionary:
	if not item_id is String: return {"error": "Invalid item id."}
	if is_champion_stone(item_id):
		return {"kind": "champion_stone", "usable": true, "definition": CHAMPION_DEFINITION, "identity": CHAMPION_IDENTITY, "handler": CHAMPION_HANDLER, "reason": ""}
	if item_id == Ancient.ITEM:
		return {"kind": "ancient_stone", "usable": false, "definition": ANCIENT_DEFINITION, "identity": ANCIENT_IDENTITY, "handler": ANCIENT_HANDLER, "reason": "Ancient Stone handler 6 is shared and its effect callee is not verified."}
	if Aloe.valid_item(item_id):
		return {"kind": "cave_aloe", "usable": false, "definition": ALOE_DEFINITION, "identity": ALOE_IDENTITY, "handler": ALOE_HANDLER, "reason": "Cave Aloe healing is handled by the player item controller."}
	return {"kind": "none", "usable": false, "definition": -1, "identity": 0, "handler": -1, "reason": "No verified item effect."}

static func admits(item_id: Variant, gates: Variant) -> Dictionary:
	var parsed := _gates(gates, false)
	if parsed.has("error"): return parsed
	var described := describe(item_id)
	if described.has("error"): return described
	var gate_reason := _gate_reason(parsed)
	var admitted := gate_reason == ""
	var reason := gate_reason
	if reason == "" and not described.usable: reason = str(described.reason)
	return {"admitted": admitted, "usable": admitted and described.usable, "reason": reason, "kind": described.kind}

static func use(state: Variant, inventory: Variant, item_id: Variant, gates: Variant) -> Dictionary:
	var restored := restore(state)
	if restored.has("error"): return restored
	var pack_error := _inventory_error(inventory)
	if pack_error != "": return {"error": pack_error}
	var parsed := _gates(gates, true)
	if parsed.has("error"): return parsed
	var described := describe(item_id)
	if described.has("error"): return described
	var current: Dictionary = restored.state
	var pack: Array = inventory.duplicate()
	var gate_reason := _gate_reason(parsed)
	if gate_reason != "":
		return _rejected(current, pack, described.kind, gate_reason, "admission", 0)
	if described.kind != "champion_stone":
		return _rejected(current, pack, described.kind, str(described.reason), "effect", -1)
	if pack.find(item_id) < 0:
		return _rejected(current, pack, described.kind, "Champion Stone is not in the inventory.", "pack", -1)
	var consumed := int(parsed.gate_223d4) == 0
	if consumed: pack.remove_at(pack.find(item_id))
	var before := BONUS if current.active else 0
	var next := {"version": VERSION, "active": true, "timer": _extend(int(current.timer))}
	return {"applied": true, "reason": "", "rejected_by": "", "kind": "champion_stone", "state": next, "inventory": pack, "consumed": consumed, "activated": before == 0, "bonus_before": before, "bonus": BONUS, "source_result": 1}

static func maintain(state: Variant, delta: Variant) -> Dictionary:
	var restored := restore(state)
	if restored.has("error"): return restored
	if not Numbers._integer(delta, 0xffffffff): return {"error": "Invalid stone timer delta."}
	if not restored.state.active: return {"error": "Inactive Champion Stone has no event 8."}
	var timer := _sub(int(restored.state.timer), int(delta))
	var expired := not _positive(timer)
	return {"state": {"version": VERSION, "active": not expired, "timer": timer}, "expired": expired, "bonus_before": BONUS, "bonus": 0 if expired else BONUS, "timer": timer}

static func melee_bonus(state: Variant) -> Dictionary:
	var restored := restore(state)
	if restored.has("error"): return restored
	return {"bonus": BONUS if restored.state.active else 0}

static func augment_stat39c(base_stat: Variant, state: Variant) -> Dictionary:
	var checked := melee_bonus(state)
	if checked.has("error"): return checked
	if not (base_stat is int or base_stat is float) or not is_finite(float(base_stat)) or float(base_stat) != floor(float(base_stat)) or base_stat < -2147483648 or base_stat > 4294967295:
		return {"error": "Invalid weapon stat."}
	var base := int(base_stat) & 0xffffffff
	var bonus := int(checked.bonus)
	return {"base": base, "bonus": bonus, "stat39c": (base + bonus) & 0xffffffff}

static func _canonical(state: Dictionary) -> Dictionary:
	return {"version": VERSION, "active": state.active, "timer": int(state.timer)}

static func _state_error(state: Variant) -> String:
	if not state is Dictionary or state.size() != 3: return "Invalid Champion Stone state."
	if not Numbers._integer(state.get("version"), VERSION) or int(state.version) != VERSION: return "Invalid Champion Stone state."
	if not state.get("active") is bool: return "Invalid Champion Stone state."
	if not Numbers._integer(state.get("timer"), 0xffffffff): return "Invalid Champion Stone state."
	return ""

static func _inventory_error(inventory: Variant) -> String:
	if not inventory is Array: return "Invalid inventory."
	for entry in inventory:
		if not entry is String: return "Invalid inventory item."
	return ""

static func _gates(gates: Variant, consumption: bool) -> Dictionary:
	if not gates is Dictionary: return {"error": "Invalid use gates."}
	if not gates.get("held") is bool: return {"error": "Invalid held-item gate."}
	if not Numbers._integer(gates.get("gate_223d0"), 0xffffffff): return {"error": "Invalid use gate 223D0."}
	if not Numbers._integer(gates.get("action_flags"), 0xffffffff): return {"error": "Invalid action flags."}
	if not gates.get("caller_bit0") is bool: return {"error": "Invalid caller bit."}
	var parsed := {"held": gates.held, "gate_223d0": int(gates.gate_223d0), "action_flags": int(gates.action_flags), "caller_bit0": gates.caller_bit0}
	if consumption and not gates.has("gate_223d4"): return {"error": "Invalid consumption gate."}
	if gates.has("gate_223d4"):
		if not Numbers._integer(gates.gate_223d4, 255): return {"error": "Invalid consumption gate."}
		parsed.gate_223d4 = int(gates.gate_223d4)
	return parsed

static func _gate_reason(gates: Dictionary) -> String:
	if not gates.held: return "No held item."
	if int(gates.gate_223d0) != 0: return "Use gate 223D0 is set."
	if _bit24(int(gates.action_flags)): return "Action flag 2279A bit 24 is set."
	if gates.caller_bit0: return "Caller byte 42D bit 0 is set."
	return ""

static func _bit24(flags: int) -> bool:
	var eax := flags & 0xffffffff
	eax = (eax << 7) & 0xffffffff
	eax = (eax >> 31) & 0xffffffff
	return eax == 1

static func _extend(timer: int) -> int:
	var low := timer & 65535
	var high := ((timer >> 16) & 65535) + HIGH_WORD_EXTEND
	return low | ((high & 65535) << 16)

static func _sub(timer: int, delta: int) -> int:
	return (timer - delta) & 0xffffffff

static func _positive(timer: int) -> bool:
	return timer > 0 and timer < 2147483648

static func _rejected(state: Dictionary, inventory: Array, kind: String, reason: String, rejected_by: String, source_result: int) -> Dictionary:
	var bonus := BONUS if state.active else 0
	var result := {"applied": false, "reason": reason, "rejected_by": rejected_by, "kind": kind, "state": state, "inventory": inventory, "consumed": false, "activated": false, "bonus_before": bonus, "bonus": bonus}
	if source_result >= 0: result.source_result = source_result
	return result
