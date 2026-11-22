extends SceneTree
const Native = preload("res://scripts/lol2/native_script_host.gd")
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_d5da60a/areas/manifest.json"))
	for area in manifest.areas:
		var vm := Native.new()
		assert(vm.load_area("res://scripts/lol2/native_scripts/" + area + ".json").is_empty())
		# Exercise every integer-indexed store, not only default placement fields.
		vm.set_local(3, -12); vm.set_local_e58(52, 65535)
		vm.record_state[123456] = {"byte5": 1, "counter": 300}
		var packet := vm.snapshot()
		assert(Native.snapshot_error(packet).is_empty())
		var json: Dictionary = JSON.parse_string(JSON.stringify(packet, "", true, true))
		vm.reset_state()
		assert(vm.restore(json).is_empty())
		assert(vm.locals[3] == -12 and vm.locals_e58[52] == 65535 and vm.record_state[123456].counter == 300)
		assert(JSON.stringify(vm.snapshot(), "", true, true) == JSON.stringify(packet, "", true, true), area)
		packet.locals["3"] = 42
		assert(vm.locals[3] == -12, "snapshot must be independent")
		var before := vm.snapshot()
		for bad in [{}, {"state":{},"locals":{},"locals_e58":{},"record_state":{},"extra":0}, {"state":{},"locals":{"01":1},"locals_e58":{},"record_state":{}}, {"state":{"x":{"y":NAN}},"locals":{},"locals_e58":{},"record_state":{}}, {"state":{},"locals":{"2":1.5},"locals_e58":{},"record_state":{}}]:
			assert(not vm.restore(bad).is_empty())
			assert(vm.snapshot() == before, "invalid restore must not mutate live state")
		json.locals["3"] = 91
		assert(vm.locals[3] == -12, "restored data must be independent")
	print("PASS native snapshots on all15 levels: JSON integer keys, deep copies, record rewrites and atomic invalid rejection")
	quit()
