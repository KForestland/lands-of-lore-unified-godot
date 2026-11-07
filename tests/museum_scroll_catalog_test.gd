extends SceneTree
const S = preload("res://scripts/lol2/museum_scroll_state.gd")
const C = preload("res://scripts/lol2/item_catalog.gd")
const D = preload("res://scripts/lol2/item_definitions.gd")
func _initialize() -> void:
	assert(D.ready())
	for i in 5:
		var id: String = S.IDS[i]
		assert(C.definition(id)==S.DEFINITIONS[i])
		assert(C.admitted(id,"museum") and C.admitted(id,"jungle") and not C.admitted(id,"cave"))
		assert(C.ids("museum").count(id)==1 and C.ids("jungle").count(id)==1)
		assert(not C.entry(id).label.is_empty() and FileAccess.file_exists(C.entry(id).icon))
	assert(C.validate_carried(S.IDS.duplicate(),"museum").is_empty())
	assert(C.validate_carried(S.IDS.duplicate(),"jungle").is_empty())
	assert(not C.validate_carried(S.IDS.duplicate(),"cave").is_empty())
	print("PASS Museum scroll catalog bindings and forward carry admission")
	quit()
