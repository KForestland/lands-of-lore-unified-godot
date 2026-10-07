extends "res://scripts/lol2/jungle_village_gate.gd"
const FollowState = preload("res://scripts/lol2/jungle_followup_state.gd")
var was_arming := false
func _init() -> void:
	asset_root = "res://assets/lol2/generated/jungle_followup/"
func state() -> Dictionary:
	var village = get_parent().village_gate.state()
	if not village.has("followup"): village.followup = FollowState.initial()
	return village.followup
func in_arming_region() -> bool:
	var player: CharacterBody3D = get_parent().player
	var foot: float = player.position.y-32.0
	if foot < float(data.arming_floor.min())-2 or foot > float(data.arming_floor.max())+2: return false
	var polygon := PackedVector2Array()
	for p in data.arming_polygon: polygon.append(Vector2(p[0],p[1]))
	return Geometry2D.is_point_in_polygon(Vector2(player.position.x,player.position.z),polygon)
func restore() -> void:
	super.restore()
	if available: was_arming = in_arming_region()
func check_contact() -> bool:
	var parent = get_parent()
	if not available or get_tree().paused or parent.flying or parent.health <= 0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not parent.player.is_on_floor(): return false
	var arm := in_arming_region()
	var speech := inside()
	var arm_enter := arm and not was_arming
	var speak_enter := speech and not was_inside
	was_arming = arm
	was_inside = speech
	var village = parent.village_gate.state()
	if arm_enter and FollowState.can_arm(state(),int(village.shared29)):
		state().local18 = 1
		parent.followup_dialogue.restore()
	if not speak_enter: return false
	if FollowState.can_speak(state(),int(parent.village_dialogue.state().local46)):
		state().local18 = 2
		parent.followup_dialogue.begin()
		return true
	# Source alternate owners hide the villager; they do not play normal speech.
	if state().shared18 == 1: state().local18 = 40
	if parent.village_dialogue.state().local46 == 1: state().local18 = 50
	parent.followup_dialogue.restore()
	return false
func advance(delta: float) -> void:
	if not int(state().local18) in [2,40,50]: return
	advance_toward(1.2 if state().local18 == 2 and state().speech < FollowState.DURATION else 0.0,delta)
