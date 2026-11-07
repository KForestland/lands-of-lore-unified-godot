extends "res://scripts/lol2/native_script_host.gd"
## Expanded predicate paths, verified against original 0x66AB0 instructions with
## relocated jump tables. No missing local/context value is supplied by this class.
## Kept separate until the full quest binder is qualified; existing hosts unchanged.
func _evaluate_predicate(index: int, input: Dictionary, matched: Dictionary) -> Dictionary:
	var result := _quest_predicate(index, input, {})
	if result.has("error"): return _verdict("unhosted", str(result.error))
	return matched if int(result.value) != 0 else _verdict("rejected", "predicate %d is false" % index)

func _quest_operand(kind: int, operand: int, input: Dictionary, stack: Dictionary) -> Dictionary:
	match kind:
		0: return {"value":operand}
		2:
			if not locals_e58.has(operand): return {"error":"shared local %d is not known" % operand}
			return {"value":int(locals_e58[operand])}
		3:
			if not locals.has(operand): return {"error":"local %d is not known" % operand}
			return {"value":int(locals[operand])}
		4: return _quest_predicate(operand, input, stack)
		5:
			if not input.get("context") is String: return {"error":"predicate context not supplied"}
			var ref := resolve(str(input.context))
			if not state.get(ref, {}).has(FIELD_BYTE25): return {"error":"context state is not known: " + ref}
			return {"value":int(state[ref][FIELD_BYTE25])}
	return {"error":"predicate operand type %d not hosted" % kind}

func _quest_predicate(index: int, input: Dictionary, stack: Dictionary) -> Dictionary:
	if index < 0 or index >= predicates.size(): return {"error":"predicate index outside table"}
	if stack.has(index): return {"error":"cyclic predicate graph"}
	var entry: PackedByteArray = predicates[index]
	if entry.size() != 5: return {"error":"malformed predicate"}
	if entry[0] > 7: return {"error":"predicate operator not hosted"}
	stack[index] = true
	# The original evaluates both operands before selecting the operator. No boolean
	# short circuit may hide an unresolved right operand in this host.
	var left := _quest_operand(entry[1], entry[2], input, stack)
	var right := _quest_operand(entry[3], entry[4], input, stack)
	stack.erase(index)
	if left.has("error"): return left
	if right.has("error"): return right
	var a := int(left.value)
	var b := int(right.value)
	var value := false
	match int(entry[0]):
		0: value = a == b
		1: value = a != b
		2: value = a <= b
		3: value = a >= b
		4: value = a > b
		5: value = a < b
		6: value = a != 0 and b != 0
		7: value = a != 0 or b != 0
	return {"value":int(value)}

## Actor opcode13 arm4 at 0xA642F calls vtable+B0(object, command[5], 0),
## then clears word7C. Reuse the selector's explicit spatial adapter; do not
## pretend the unentered frame-restart callees are decoded.
func _op_thirteen_actor(ref: String, command: Dictionary) -> String:
	var bytes: PackedByteArray = command["bytes"]
	if bytes[4] != 4: return super._op_thirteen_actor(ref, command)
	var a8: int = stage_read(ref, "byte_0xa8", UNKNOWN)
	if a8 == 0x0F: return ""
	if a8 == UNKNOWN and not use_adapter("opcode13_actor_a8"):
		return "actor byte +0xA8 is not known (0x0F skips the store)"
	var selector := command.duplicate(true)
	var selector_bytes := bytes.duplicate()
	selector_bytes[0] = 5
	selector_bytes[4] = bytes[5]
	selector_bytes[5] = 0
	selector["opcode"] = 5
	selector["bytes"] = selector_bytes
	var error := _op_selector(self, selector)
	if not error.is_empty(): return error
	stage_write(ref, FIELD_WORD7C, 0)
	return ""
