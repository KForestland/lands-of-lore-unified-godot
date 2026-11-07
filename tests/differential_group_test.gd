extends SceneTree
## W8 differential script test (WORKFLOW_PLAN 2026-10-31): the host's staged fields for door 57's group 13798 (opcode 5: selector 3,
## opcode 1: the mode-6 travel word 21845; opcode 198 / 20 run too) against the ORIGINAL code's stores on a synthetic object, executed by the
## bounded native harness (tools/verify_differential_group.py -> docs/differential_group_receipt.json: 0x5D510 and 0x63DAC copied
## instruction by instruction, their outside calls stubbed and logged). Same inputs (mode 6, angle word 21845, selector 0), same bytes.
const Host := preload("res://scripts/lol2/native_script_host.gd")
const RECEIPT := "res://docs/differential_group_receipt.json"
const DOOR := "movable:57"
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECEIPT))
	check(receipt.get("version", 0) == 1 and str(receipt.case_a.entry) == "0x5D510" and str(receipt.case_b.entry) == "0x63DAC" and int(receipt.harness.instructions) > 0, "receipt: native entries 0x5D510 / 0x63DAC, %d original instructions (%s)" % [int(receipt.harness.get("instructions", 0)), str(receipt.harness.get("sha256", "")).left(12)])
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L7_DH.json").is_empty(), "L7_DH loads")
	host.bind_target("0x20:57", DOOR)
	check(int(host.attributes[DOOR].mode) == 6 and int(host.attributes[DOOR].angle_word) == int(receipt.object.angle_word) and host.field(DOOR, "selector_0x3d") == int(receipt.object.selector_before), "the host's door 57 matches the native object image: mode 6, angle word %d, selector %d" % [int(receipt.object.angle_word), int(receipt.object.selector_before)])
	var group: int = int(receipt.case_a.group)
	var hexes := []
	for c in host.groups[host.group_key(1, group)]: hexes.append(str(c.raw_hex))
	check(group == int(receipt.case_b.group) and hexes.has(str(receipt.case_a.command)) and hexes.has(str(receipt.case_b.command)), "group %d holds both native cases' commands (%s)" % [group, hexes])
	var ran: Dictionary = host.execute_group(1, group)
	check(str(ran.status) == "ran", "group %d runs on the host (%s)" % [group, ran.get("reasons", [])])
	check(host.field(DOOR, "selector_0x3d") == int(receipt.case_a.selector_0x3d) and int(receipt.case_a.return_eax) == 1, "DIFF selector +0x3D: host %d == native %d (native returned %d)" % [host.field(DOOR, "selector_0x3d"), int(receipt.case_a.selector_0x3d), int(receipt.case_a.return_eax)])
	check(host.field(DOOR, "travel_0x50") == int(receipt.case_b.travel_0x50) and int(receipt.case_b.mode_byte) == 6 and int(receipt.case_b.return_eax) == 1, "DIFF travel +0x50: host %d == native %d (mode byte kept %d)" % [host.field(DOOR, "travel_0x50"), int(receipt.case_b.travel_0x50), int(receipt.case_b.mode_byte)])
	print("Differential group: %d failures" % failures)
	if failures == 0: print("PASS differential group: door 57 group 13798 (selector 3, travel 21845) diffs clean between the native handlers 0x5D510 / 0x63DAC and the host")
	quit(0 if failures == 0 else 1)
