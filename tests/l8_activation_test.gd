extends SceneTree
## L8 prop 531 group 7770 and actor 113 kind-4 mode 1.
## Slot 0 stores command byte 5. Arm 3 links when placement word +8 has bit 0x1000.
## Mode 1 matches a nonzero arg_c. Not an area exit.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL l8 activation: ", message)
func row_for(results: Array, group: int) -> Dictionary:
	for row in results:
		if int(row.group) == group:
			return row
	return {}
func _initialize() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(), "L8 source loads")
	host.set_field("actor:113", "byte_0xa8", 0)
	host.set_field("actor:113", "word_0x7c", 123)
	var blocked: Array = host.fire_event("prop:531", 6, {"caller_byte": 0x14})
	var early: Dictionary = row_for(blocked, 7770)
	check(str(early.get("status", "")) == "unhosted" and str(early.get("reasons", [])).contains("local 6"), "group 7770 stays unhosted until local 6 is known (%s)" % [early.get("reasons", [])])
	check(host.field("actor:113", "byte_0xa8") == 0 and host.field("actor:113", "bit_0x16_0x01") == -1, "a refused predicate must not store slot 0 or the link")
	host.set_local(6, 0)
	var rejected: Array = host.fire_event("prop:531", 6, {"caller_byte": 0x14})
	var closed: Dictionary = row_for(rejected, 7770)
	check(str(closed.get("status", "")) == "rejected", "local 6 = 0 rejects predicate 97 (%s)" % [closed.get("status", "")])
	# Earn the permission through the actual temple-approach region, rather than
	# injecting local6=1. The local6=0 setup above is this subsystem's fresh input.
	host.set_global(0x223D6, 0)
	var approach: Array = host.fire_event("region:1514", 2, {})
	var visit: Dictionary = row_for(approach, 1044)
	check(str(visit.get("status", "")) == "ran" and host.locals.get(6) == 1, "temple approach group1044 earns local6 (%s)" % [visit])
	var opened: Array = host.fire_event("prop:531", 6, {"caller_byte": 0x14})
	var ran: Dictionary = row_for(opened, 7770)
	check(str(ran.get("status", "")) == "ran", "group 7770 runs (%s)" % [ran.get("reasons", [])])
	check(host.field("actor:113", "byte_0xa8") == 7 and host.field("actor:113", "byte_0xa9") == 7, "slot 0 stores command byte 5 at +0xA8 and +0xA9")
	check(host.field("actor:113", "bit_0xb8_0x01") == 1 and host.field("actor:113", "word_0x7c") == 0, "slot 0 sets +0xB8 bit 0 and clears word +0x7C")
	check(host.field("actor:113", "bit_0x15_0x10") == 0 and host.field("actor:113", "bit_0x16_0x01") == 1 and host.field("actor:113", "bit_0x17_0x20") == 1 and host.field("actor:113", "dword_0x0c") == 0, "arm 3 links actor 113 from placement bit 0x1000")
	var held = Host.new()
	check(held.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(), "second L8 source loads")
	held.set_local(6, 1)
	held.set_field("actor:113", "byte_0xa8", 0x0F)
	held.set_field("actor:113", "word_0x7c", 123)
	var skipped: Array = held.fire_event("prop:531", 6, {"caller_byte": 0x14})
	var skip: Dictionary = row_for(skipped, 7770)
	check(str(skip.get("status", "")) == "ran" and held.field("actor:113", "byte_0xa8") == 0x0F and held.field("actor:113", "word_0x7c") == 123 and held.field("actor:113", "bit_0x16_0x01") == 1, "A8 0x0F skips slot 0 and arm 3 still links (%s)" % [skip.get("status", "")])
	var cleared = Host.new()
	check(cleared.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(), "third L8 source loads")
	cleared.set_local(6, 1)
	cleared.set_field("actor:113", "byte_0xa8", 0)
	cleared.set_field("actor:113", "bit_0x15_0x10", 0)
	var quiet_link: Array = cleared.fire_event("prop:531", 6, {"caller_byte": 0x14})
	var quiet_link_row: Dictionary = row_for(quiet_link, 7770)
	check(str(quiet_link_row.get("status", "")) == "ran" and cleared.field("actor:113", "byte_0xa8") == 7 and cleared.field("actor:113", "bit_0x16_0x01") == -1, "bit 0x10 clear writes nothing in arm 3 and slot 0 still stores (%s)" % [quiet_link_row.get("reasons", [])])
	var talk = Host.new()
	check(talk.load_area("res://scripts/lol2/native_scripts/L8_SJ.json").is_empty(), "fourth L8 source loads")
	var quiet: Array = talk.fire_event("actor:113", 4, {"arg_c": 0, "context": "actor:113"})
	for group in [20782, 21132]:
		var quiet_row: Dictionary = row_for(quiet, group)
		check(str(quiet_row.get("status", "")) == "rejected" and str(quiet_row.get("reasons", [])).contains("nonzero"), "group %d mode 1 rejects arg_c 0 (%s)" % [group, quiet_row.get("reasons", [])])
	var used: Array = talk.fire_event("actor:113", 4, {"arg_c": 1, "context": "actor:113"})
	var offered: Dictionary = row_for(used, 20782)
	check(str(offered.get("status", "")) == "unhosted" and str(offered.get("reasons", [])).contains("0x80"), "group 20782 mode 1 admits arg_c 1 and stops at the unread bit (%s)" % [offered.get("reasons", [])])
	var predicated: Dictionary = row_for(used, 21132)
	check(str(predicated.get("status", "")) == "unhosted" and str(predicated.get("reasons", [])).contains("right type 4"), "group 21132 mode 1 admits arg_c 1 and stops on predicate 42 (%s)" % [predicated.get("reasons", [])])
	var key := talk.group_key(1, 980001)
	talk.groups[key] = []
	(talk.objects["actor:113"] as Array).append({"kind": 4, "stream": 1, "group": 980001, "file_offset": -2, "bytes": PackedByteArray([0x0a, 4, 0x71, 0x00, 1, 1, 0, 0, 0, 0]), "predicate": -1})
	var inverted: Array = talk.fire_event("actor:113", 4, {"arg_c": 0, "context": "actor:113"})
	var inverse: Dictionary = row_for(inverted, 980001)
	check(str(inverse.get("status", "")) == "ran", "mode 1 with byte +5 set accepts arg_c 0 (%s)" % [inverse.get("reasons", [])])
	var plain: Array = talk.fire_event("actor:113", 4, {"arg_c": 1, "context": "actor:113"})
	var plain_row: Dictionary = row_for(plain, 980001)
	check(str(plain_row.get("status", "")) == "rejected", "mode 1 with byte +5 set rejects arg_c 1")
	if failures == 0:
		print("PASS L8 activation: group 7770 links actor 113 and slot 0 stores byte 7; kind 4 mode 1 admits a nonzero arg_c")
	quit(0 if failures == 0 else 1)
