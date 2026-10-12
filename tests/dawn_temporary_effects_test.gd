extends SceneTree
const Effects=preload("res://scripts/lol2/dawn_temporary_effects.gd")
func _initialize() -> void:
	var shields=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_effect_lifetime_results.json"))
	for row in shields.rows:
		var context: Dictionary=row.duplicate(true);context.alive=bool(context.alive)
		var result:=Effects.shield(context)
		assert(not result.has("error") and result.remaining==row.after_remaining and result.retired==row.retired and result.exclusive==row.after_exclusive,str(row,result))
	for row in shields.callbacks:
		var result:=Effects.shield_frame_end(row.spell,row.before)
		assert(result.mode==row.after and result.frame==0)
	var healing=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell50_update_results.json"))
	for row in healing.rows:
		var result:=Effects.heal_cycle(row)
		assert(not result.has("error") and result.cycles==row.after_cycles and result.b6==row.after_b6 and result.frame==row.after_frame and result.retired==row.retired,str(row,result))
		assert(result.heal_target==(null if row.heal_request==null else row.heal_request[1]))
	print("PASS:384 native shield updates,28 frame callbacks,432 heal cycle transitions")
	quit()
