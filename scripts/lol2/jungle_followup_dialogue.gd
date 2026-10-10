extends "res://scripts/lol2/jungle_village_dialogue.gd"
const FollowState = preload("res://scripts/lol2/jungle_followup_state.gd")
func _init() -> void:
	asset_root = "res://assets/lol2/generated/jungle_followup_dialogue/"
func state() -> Dictionary:
	return get_parent().followup_gate.state()
func active() -> bool:
	return state().local18 == 2 and state().speech < FollowState.DURATION
func begin() -> bool:
	if not active() or get_tree().paused: return false
	get_parent().player.velocity = Vector3.ZERO
	restore()
	return true
func restore() -> void:
	if not is_instance_valid(audio): return
	audio.stop()
	visible = state().local18 == 1 or active()
	if active():
		_set_frame(mini(500,int(float(state().speech)*15)))
		audio.stream = AudioStreamWAV.load_from_file(asset_root+"section_0.wav")
		audio.play(float(state().speech))
	else: _set_frame(501)
func advance(delta: float) -> void:
	if get_tree().paused or not active() or get_parent().health <= 0: return
	state().speech = minf(FollowState.DURATION,float(state().speech)+maxf(delta,0))
	_set_frame(mini(500,int(float(state().speech)*15)))
	if state().speech == FollowState.DURATION:
		audio.stop()
		visible = false # Source control85 group19638 disables this controller.
