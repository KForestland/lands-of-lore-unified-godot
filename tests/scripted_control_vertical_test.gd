extends SceneTree
const Vertical=preload("res://scripts/lol2/scripted_control_vertical.gd")
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_vertical_native.json"))
	assert(fixture.passed and fixture.cases.size()==432)
	for row in fixture.cases:
		assert(Vertical.pitch(int(row.delta),int(row.distance))==row.pitch)
		var result:=Vertical.step(int(row.delta),int(row.distance),int(row.horizontal),int(row.quota),int(row.initial_pitch))
		assert(result.step==row.step and result.pitch==row.next_pitch)
		var saved: Dictionary=JSON.parse_string(JSON.stringify(result))
		assert(saved.step==row.step and saved.pitch==row.next_pitch)
	assert(Vertical.step(0,100,1,1,255)=={"step":0,"pitch":255})
	assert(Vertical.step(1,100,101,1,0).is_empty())
	assert(Vertical.step(1,-1,0,1,0).is_empty())
	assert(Vertical.step(1,100,1,1,256).is_empty())
	print("PASS 432 original integer pitch/fixed interpolation/vertical correction/clamp vectors, zero-height bypass, JSON and invalid inputs. Horizontal movement, collision and completion remain caller-owned.")
	quit()
