extends SceneTree
const Markers = preload("res://scripts/lol2/hive_marker_runtime.gd")
const Conditions = preload("res://scripts/lol2/hive_condition_runtime.gd")
func _initialize() -> void: run.call_deferred()
func fixture(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_"+name+"_native.json"))
func run() -> void:
	for row in fixture("marker_selection"):
		var result := Markers.select_marker(row.previous,row.index,row.actor_state,row.counter)
		assert(not result.has("error"))
		assert(result.selected == row.selected and result.counter == row.expected_counter and result.applied == row.applied)
	var bank := PackedByteArray([255,255,0,128,255,255,1,255,0,0,0,0,0,0,2,0])
	var before := bank.duplicate()
	var records := Markers.resolve_geometry(bank,0,1)
	assert(records.region9.coordinates == [-1,-32768] and records.region9.radius == 1)
	assert(records.point41.coordinates == [0,0] and records.point41.radius == 2)
	var state := Markers.select_marker(1,65535,0,42)
	assert(Markers.resolve_geometry(bank,0,state.selected).point41 == null)
	state = Markers.select_marker(1,65535,15,42)
	assert(Markers.resolve_geometry(bank,0,state.selected).point41.radius == 2)
	var actor: Dictionary = fixture("actor_conditions")[0]
	var player: Dictionary = fixture("player_conditions")[0].context
	var remaining: Dictionary = fixture("remaining_conditions")[0].context.duplicate(true)
	remaining.size_definition = 0
	var core := Conditions.new()
	var result := core.evaluate_with_marker_bank(actor.stats,6,actor,player,remaining,[0,0],bank,1,1,0x127f)
	assert(not result.has("error") and 9 in result.conditions and 41 in result.conditions)
	result = core.evaluate_with_marker_bank(actor.stats,6,actor,player,remaining,[0,0],bank,1,null,0x127f)
	assert(not result.has("error") and 9 in result.conditions and 41 not in result.conditions)
	assert(not result.live_context_bound)
	assert(core.evaluate_with_marker_bank(actor.stats,6,actor,player,remaining,[0,0],bank,2,null,0x127f).has("error"))
	assert(bank == before)
	for invalid in [-1,65536,true,null,0.5]: assert(Markers.select_marker(null,invalid,0,0).has("error"))
	for invalid in [-1,65535,true,0.5]: assert(Markers.select_marker(invalid,0,0,0).has("error"))
	assert(Markers.select_marker(null,0,256,0).has("error"))
	assert(Markers.select_marker(null,0,0,65536).has("error"))
	assert(Markers.resolve_geometry(bank,0,2).has("error"))
	assert(Markers.resolve_geometry(PackedByteArray([0]),0,null).has("error"))
	var loaded := Markers.load_hive_bank()
	assert(not loaded.has("error") and loaded.count == 60 and loaded.bank.size() == 480)
	for index in range(60): assert(not Markers.resolve_geometry(loaded.bank,index,index).has("error"))
	var geometry := PackedByteArray();geometry.resize(224+60*34)
	geometry.encode_u32(0xc4,60);geometry.encode_u32(0xc8,224);geometry.encode_u32(0xdc,geometry.size())
	for i in range(480): geometry[224+i] = loaded.bank[i]
	var extracted := Markers.load_area_geometry(geometry)
	assert(not extracted.has("error") and extracted.bank == loaded.bank)
	extracted.bank[0] = extracted.bank[0]^255
	assert(geometry[224] == loaded.bank[0])
	for pair in [[0xc4,4294967295],[0xc8,0],[0xc8,4294967295],[0xdc,224]]:
		var invalid := geometry.duplicate();invalid.encode_u32(pair[0],pair[1])
		assert(Markers.load_area_geometry(invalid).has("error"))
	assert(Markers.load_area_geometry(PackedByteArray()).has("error"))
	print("PASS:512 native marker transitions; signed record decoding, clear/skip behavior and full condition composition")
	quit(0)
