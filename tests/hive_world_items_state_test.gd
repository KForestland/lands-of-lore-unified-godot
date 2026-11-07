extends SceneTree
## Hive original rows 5-9: catalog binding, scope, save-history validation and old-save default.
const S = preload("res://scripts/lol2/hive_world_items_state.gd")
const C = preload("res://scripts/lol2/item_catalog.gd")
const D = preload("res://scripts/lol2/item_definitions.gd")
const Q = preload("res://scripts/lol2/act_one_quest_state.gd")
const N = preload("res://scripts/lol2/act_one_item_names.gd")
func _initialize() -> void:
	assert(D.ready())
	assert(S.ROWS == [5,6,7,8,9] and 4 not in S.ROWS and 10 not in S.ROWS)
	for i in S.ROWS.size():
		var id: String = S.IDS[i]
		assert(D.by_identity(S.IDENTITIES[i]) == S.DEFINITIONS[i] and D.name(S.DEFINITIONS[i]).strip_edges() == S.NAMES[i])
		assert(C.definition(id) == S.DEFINITIONS[i] and C.definition_name(id) == S.NAMES[i] and N.source_name(id) == S.NAMES[i])
		assert(C.slot(id) == "" and C.use_kind(id) == "" and C.label(id) == D.label(S.DEFINITIONS[i]))
		assert(FileAccess.file_exists(C.icon(id)) and FileAccess.file_exists(C.inventory_icon(id)))
		assert(C.admitted(id,"jungle") and not C.admitted(id,"museum") and not C.admitted(id,"cave"))
		assert(C.ids("jungle").count(id) == 1)
	assert(C.validate_carried(S.IDS.duplicate(),"jungle").is_empty())
	assert(not C.validate_carried(S.IDS.duplicate(),"museum").is_empty())
	# History: absent (older saves) is valid and means every row is present.
	var quests: Dictionary = Q.initial()
	assert(not quests.has(S.KEY) and Q.validate(quests).is_empty())
	assert(S.rows_of(null) == [])
	for good in [{"version":1,"collected":[]},{"version":1,"collected":[5,9]},{"version":1,"collected":[6.0,7.0]}]:
		quests[S.KEY] = good
		assert(Q.validate(quests).is_empty(), str(good))
	for bad in [[], {"version":2,"collected":[]}, {"version":1,"collected":[4]}, {"version":1,"collected":[10]}, {"version":1,"collected":[5,5]}, {"version":1,"collected":[5.5]}, {"version":1,"collected":["5"]}, {"version":1,"collected":[],"x":1}]:
		quests[S.KEY] = bad
		assert(not Q.validate(quests).is_empty(), str(bad))
	assert(S.rows_of({"version":1,"collected":[6.0,8.0]}) == [6,8])
	print("PASS Hive world items rows5-9 catalog bindings, Jungle scope, history validation and old-save default")
	quit()
