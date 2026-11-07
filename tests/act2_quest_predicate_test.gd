extends SceneTree
const Host = preload("res://scripts/lol2/act2_quest_native_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL quest predicate: ", message)
func _initialize() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://tests/act2_predicate_vectors.json"))
	for row in source.vectors:
		var h = Host.new()
		for entry in row.table: h.predicates.append(str(entry).hex_decode())
		for i in row.local.size(): h.set_local(i, int(row.local[i]))
		for i in row.shared.size(): h.set_local_e58(i, int(row.shared[i]))
		h.set_field("actor:113", "byte_0x25", int(row.context))
		var result = h._evaluate_predicate(int(row.index), {"context":"actor:113"}, {"status":"match"})
		check(result.status == ("match" if int(row.expected) != 0 else "rejected"), "original CPU vector " + str(row))
	var h = Host.new()
	h.predicates.append("0600000309".hex_decode())
	check(h._evaluate_predicate(0, {}, {}).status == "unhosted", "false left must not conceal unknown right")
	h.predicates[0] = "0004000000".hex_decode()
	check(h._evaluate_predicate(0, {}, {}).status == "unhosted", "cycle refused")
	check(h._evaluate_predicate(-1, {}, {}).status == "unhosted", "negative index refused")
	h.predicates[0] = "0005000000".hex_decode()
	check(h._evaluate_predicate(0, {}, {}).status == "unhosted", "missing context refused")
	check(h.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(), "L8 source loads")
	var bytes := "0d02710004090000".hex_decode()
	h.groups[h.group_key(1, 990000)] = [{"opcode":13,"kind":2,"target":113,"file_offset":-1,"bytes":bytes}]
	h.set_field("actor:113", "byte_0xa8", 0)
	h.set_field("actor:113", "word_0x7c", 123)
	var result = h.execute_group(1, 990000)
	check(result.status == "ran" and result.adapters.has("opcode5_spatial"), "arm4 names spatial adapter")
	check(h.state["actor:113"][h.FIELD_BYTE30] == 9 and h.state["actor:113"][h.FIELD_WORD7C] == 0, "arm4 selects byte5 and clears timer")
	h.set_field("actor:113", "byte_0xa8", 15)
	h.set_field("actor:113", "word_0x7c", 123)
	h.set_adapter_enabled("opcode5_spatial", false)
	result = h.execute_group(1, 990000)
	check(result.status == "ran" and h.state["actor:113"][h.FIELD_WORD7C] == 123, "A8=15 skips all changes")
	h.set_field("actor:113", "byte_0xa8", 0)
	result = h.execute_group(1, 990000)
	check(result.status == "unhosted" and h.state["actor:113"][h.FIELD_WORD7C] == 123, "disabled spatial adapter refuses transaction")
	# Actual guard record/group, with explicit subsystem inputs. This is not an
	# earned route: acquisition, NPC presence and caller production remain outside.
	var guard = Host.new()
	check(guard.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(), "guard source loads")
	guard.set_local(9, 0)
	guard.set_local(32, 0)
	guard.set_global(0x223D4, 0)
	var inputs := {"arg_object_identity":3959297008,"arg_c":1,"context":"actor:113"}
	var wrong := inputs.duplicate()
	wrong.arg_object_identity = 1
	var offered: Array = guard.fire_event("actor:113", 4, wrong)
	check(guard.locals[9] == 0, "wrong knife cannot grant admission")
	guard.set_adapter_enabled("opcode5_spatial", false)
	offered = guard.fire_event("actor:113", 4, inputs)
	check(guard.locals[9] == 0, "unhosted animation rolls back earlier permission store")
	guard.set_adapter_enabled("opcode5_spatial", true)
	offered = guard.fire_event("actor:113", 4, inputs)
	var ran := false
	for row in offered:
		if int(row.group) == 20388 and row.status == "ran": ran = true
	check(ran and guard.locals[9] == 1, "source knife-offer group earns local9")
	offered = guard.fire_event("actor:113", 4, inputs)
	for row in offered:
		if int(row.group) in [20320,20388]: check(row.status == "rejected", "repeat gift rejected by native predicates")
	if failures == 0: print("PASS quest predicates match ", source.vectors.size(), " original CPU vectors; unknown inputs and cycles refused")
	quit(0 if failures == 0 else 1)
