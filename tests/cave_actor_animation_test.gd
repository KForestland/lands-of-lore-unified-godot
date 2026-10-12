extends SceneTree

const ActorAnimation = preload("res://scripts/lol2/cave_actor_animation.gd")
var checks := 0
var failures := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func _initialize() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string(ActorAnimation.ROOT + "bearing_fixtures.json"))
	check(fixtures is Array and fixtures.size() == 484, "Native instruction replay fixtures available")
	if not fixtures is Array:
		quit(1)
		return
	for fixture in fixtures:
		check(ActorAnimation.native_bearing(int(fixture.dx), int(fixture.dy)) == int(fixture.bearing), "Bearing matches native instruction replay")
	var animation := ActorAnimation.new()
	check(animation.advance(1.0, true) == 0, "No frames is safe")
	animation.frame_count = 9
	for index in range(1, 10):
		check(animation.advance(0.125, true) == index % 9, "Source frame order and loop")
	animation.advance(0.5, true)
	check(animation.advance(0.5, false) == 0 and animation.elapsed == 0.0, "Stationary state returns to fixed reference pose")
	animation.advance(0.5, true)
	animation.reset()
	check(animation.frame_index == 0 and animation.elapsed == 0.0, "Restart resets animation clock")
	var fast := ActorAnimation.new()
	fast.frame_count = 9
	for i in range(32): fast.advance(1.0 / 32.0, true)
	var slow := ActorAnimation.new()
	slow.frame_count = 9
	for i in range(8): slow.advance(1.0 / 8.0, true)
	check(fast.frame_index == slow.frame_index and fast.frame_index == 8, "Playback is elapsed-time based")
	check(fast.advance(90.0, true) == 8, "Large time steps wrap without overflowing frame array")
	var actions := ActorAnimation.new()
	var load_error := actions.load_assets()
	check(load_error.is_empty(), "Directional and action assets load with checksum checks: " + load_error)
	if not load_error.is_empty():
		quit(1)
		return
	actions.play_action(5)
	actions.advance(0.875, false)
	check(actions.frame_count == 16 and actions.frame_index == 7, "Action advances while actor is stationary")
	actions.play_action(5)
	check(actions.frame_index == 7, "Repeated action request does not restart sequence")
	var action_frame: ImageTexture = actions.textures[7]
	actions.set_view(3)
	check(actions.textures[7] == action_frame, "Camera view change cannot replace active action texture")
	check(actions.attack_impact_frame == 12, "Native event marker loads from source manifest")
	actions.set_action_elapsed(1.375)
	check(actions.frame_index == 11, "Pre-impact clock displays frame eleven")
	actions.set_action_elapsed(1.5)
	check(actions.frame_index == 12, "Impact clock displays frame twelve")
	actions.set_action_elapsed(0.0)
	check(actions.frame_index == 0, "Shared clock restarts repeated action")
	actions.clear_action()
	check(actions.frame_count == 9 and actions.frame_index == 0 and actions.textures == actions.view_textures[3], "Action exit restores selected directional view")
	actions.play_action(14)
	actions.advance(2.6, false)
	check(actions.frame_count == 20 and actions.frame_index == 19 and actions.action_finished(), "Collapse sequence completes without wrapping")
	actions.advance(10.0, false)
	check(actions.frame_index == 19, "Finished collapse stays finished")
	actions.reset()
	check(actions.action_key == -1 and actions.frame_count == 9 and actions.frame_index == 0, "Retry clears action and restores directional animation")
	print("Actor animation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
