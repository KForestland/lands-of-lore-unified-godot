extends SceneTree
const Save=preload("res://scripts/lol2/game_save.gd")
const V1:="res://tests/fixtures/game_save_v1.json"
const SHA:="6caa21500c0d4bbf278f6ad03b912b196e265224cbfcab981a708988fffa4d9b"
func _initialize()->void:run.call_deferred()
func run()->void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	assert(FileAccess.get_sha256(V1)==SHA,"actual version-1 writer fixture is immutable")
	var bytes:=FileAccess.get_file_as_bytes(V1)
	var old:Dictionary=JSON.parse_string(bytes.get_string_from_utf8());assert(old.version==1)
	var result:=Save.migrate(old);assert(result.error.is_empty() and result.state.version==Save.CURRENT)
	assert(old.version==1 and old.session.has("adapter_exit_seeds"),"migration does not mutate caller")
	assert(result.state.session.options.adapter_exit_seeds==old.session.adapter_exit_seeds)
	assert(not result.state.session.has("adapter_exit_seeds"))
	for key in old:
		if key not in ["version","session","native_bank"]:assert(old[key]==result.state[key],"only actual options shape migrated: "+key)
	assert(result.state.has("native_globals"),"Current envelope owns global cells once")
	for area in result.state.native_bank:assert(result.state.native_bank[area].locals_e58.is_empty(),"Legacy global cells promoted from per-area copies")
	for area in old.native_bank:
		for field in old.native_bank[area]:
			if field!="locals_e58":assert(result.state.native_bank[area][field]==old.native_bank[area][field],"Old per-level field unchanged: "+field)
	var v2_path:="res://tests/fixtures/g04_inputs/l9_mid_door_v2.json"
	assert(FileAccess.get_sha256(v2_path)=="6da1fd80c67ac9926b20f548129bf6ba742a6a189688df21a78e68d9538cc265","Actual v2 player-input writer remains byte-pinned")
	var v2:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(v2_path));assert(v2.version==2)
	var promoted:=Save.read_document(v2_path)
	assert(promoted.error.is_empty() and promoted.state.version==Save.CURRENT and promoted.state.area_save==v2.area_save,"Actual v2 envelope migrates with unchanged inner player/world packet")
	for area in v2.native_bank:
		for field in v2.native_bank[area]:
			if field!="locals_e58":assert(promoted.state.native_bank[area][field]==v2.native_bank[area][field],"Actual v2 non-global native state unchanged: "+field)
	assert(Save.validate(old).is_empty() and Save.validate(result.state).is_empty())
	assert(Save.migrate(result.state).state==result.state,"current version is idempotent")
	var future:=old.duplicate(true);future.version=999;assert(Save.validate(future).contains("newer"))
	var broken:=old.duplicate(true);broken.session.erase("adapter_exit_seeds");assert(not Save.validate(broken).is_empty())
	# Keep the old bytes as the primary, then prove a current-version write preserves them unchanged in backup.
	DirAccess.make_dir_recursive_absolute(Save.ROOT)
	var file:=FileAccess.open(Save.slot_path(7),FileAccess.WRITE);file.store_buffer(bytes);file.close()
	assert(Save.read_document(Save.slot_path(7)).state.version==Save.CURRENT)
	assert(Save.write_document(Save.slot_path(7),result.state).is_empty())
	assert(FileAccess.get_file_as_bytes(Save.backup_path(7))==bytes)
	assert(Save.read_document(Save.backup_path(7)).error.is_empty())
	# Inner Cave v1 still has its own independent migration, never an outer-version comparison.
	var cave:Dictionary=result.state.duplicate(true)
	cave.area="L1_DC";cave.scene="res://scenes/lol2/cave_walkthrough.tscn"
	cave.area_save=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_d5da60a/areas/L1_DC_v1.json"))
	assert(Save.validate(cave).is_empty())
	var prepared:=preload("res://scripts/lol2/game_areas.gd").prepare_area("L1_DC",cave.area_save)
	assert(prepared.version==2 and prepared.collected==[] and cave.area_save.version==1)
	print("PASS actual v1 writer fixture -> ordered options/global-cell migrations; immutable old/backup bytes; independent Cave migration; future refusal")
	quit()
