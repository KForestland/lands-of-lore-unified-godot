extends SceneTree
## Backlog 3 item 1 (opcode 21): the operand table from LOLG.DAT, the host's opcode21_movie adapter (a staged movie request
## naming the table entry), the PROVEN out-of-table no-op, refusal with adapters off, and the world-side player mapping.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/movie_table.json"))
	check(int(table.count) == 85 and table.entries.size() == 85 and str(table.entries[29].name) == "flood" and str(table.entries[28].name) == "fishdeth" and str(table.entries[74].name) == "luthrdie", "movie table: 85 names, 29 flood, 28 fishdeth, 74 luthrdie")
	check(str(table.sha256) == "b27a35341c6e877e40b1540b6482748e7a750c605fefe6452431b18a5d766775" and int(table.table_file_offset) == 0x1CF58C, "table pinned to LOLG.DAT at file 0x1CF58C")
	var players: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/movie_players.json"))
	var with_player := 0
	for name in players.players:
		var row: Dictionary = players.players[name]
		check(str(table.entries[int(row.index)].name) == name, "player row %s matches table index %d" % [name, int(row.index)])
		if str(row.player) != "none":
			with_player += 1
			check(FileAccess.file_exists("res://" + str(row.player)), "player script exists: " + str(row.player))
	check(players.players.size() == 19 and with_player == 10, "19 Act 1 movie names mapped, 10 with a player, 9 logged no-ops (%d/%d)" % [players.players.size(), with_player])
	var host = Host.new()
	check(host.movie_table.size() == 85, "host loads the 85-name table")
	check(host.load_area("res://scripts/lol2/native_scripts/L4_HJ.json").is_empty(), "L4_HJ loads")
	# Every L4_HJ group with opcode 21 (456 commands) is accepted by the handler: no group fails for "opcode 21 has no
	# handler". Most of them (432: opcodes 198, 21, 2) still stop at opcode 2 arm 57, which is not this adapter's business.
	var with_21 := 0
	var no_handler := 0
	var ran := 0
	for key in host.groups:
		var has := false
		for c in host.groups[key]: if int(c.opcode) == 21: has = true
		if not has: continue
		with_21 += 1
		var res: Dictionary = host.execute_group(int(str(key).get_slice(":", 0)), int(str(key).get_slice(":", 1)))
		if str(res.status) == "ran": ran += 1
		for reason in res.reasons: if str(reason).contains("opcode 21 has no handler"): no_handler += 1
		host.reset_state()
	check(with_21 == 456 and no_handler == 0, "L4_HJ: %d groups carry opcode 21, none is refused for lack of a handler (%d ran whole)" % [with_21, no_handler])
	# Handler behaviour on synthetic single-command groups (the real groups carry other opcodes).
	var requests: Array = []
	host.movie_request.connect(func(i: int, n: String, b5: int): requests.append([i, n, b5]))
	var g := 900000
	for probe in [[28, 0], [33, 0], [100, 0], [-1, 0]]:
		host.groups[host.group_key(1, g)] = [{"opcode": 21, "kind": 0, "target": 0, "file_offset": -1, "bytes": PackedByteArray([21, 0, 0, 0, int(probe[0]) & 0xFF, int(probe[1])]), "raw_hex": ""}]
		g += 1
	var r: Dictionary = host.execute_group(1, 900000)
	check(str(r.status) == "ran" and r.adapters == ["opcode21_movie"] and requests == [[28, "fishdeth", 0]], "index 28 runs on the adapter and requests fishdeth (%s %s)" % [r.status, requests])
	r = host.execute_group(1, 900001)
	check(str(r.status) == "ran" and requests.size() == 2 and requests[1] == [33, "hw-brdge", 0], "index 33 requests hw-brdge")
	r = host.execute_group(1, 900002)
	check(str(r.status) == "ran" and r.adapters.is_empty() and requests.size() == 2, "index 100 is past the table: a PROVEN no-op, no request, no adapter")
	r = host.execute_group(1, 900003)
	check(str(r.status) == "ran" and r.adapters.is_empty() and requests.size() == 2, "index -1 leaves the index path: no-op")
	host.set_adapters_enabled(false)
	r = host.execute_group(1, 900000)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("opcode 21") and str(r.reasons[0]).contains("fishdeth") and requests.size() == 2, "with adapters off the group is unhosted and names the movie it would play")
	host.set_adapters_enabled(true)
	print("Native host movie: %d failures" % failures)
	if failures == 0: print("PASS native host movie: 85-name table pinned, 19 Act 1 names mapped (10 players), 456 L4_HJ opcode-21 commands accepted, requests on the adapter, refusal with adapters off, no-op past the table")
	quit(0 if failures == 0 else 1)
