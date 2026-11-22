extends RefCounted
## Shared Human C-hold behavior, using the existing Museum dimensions and stand-up clearance query.
const Body = preload("res://scripts/lol2/player_form_body.gd")

static func set_crouch(host: Node3D, want: bool, check_space: bool = true) -> bool:
	var form: int = int(host.player.get_meta("lol2_form", int(host.get("player_form")) if host.get("player_form") != null else 0))
	var applied: bool = Body.apply(host.player, host.camera, form, check_space, want)
	if applied: host.crouched = want
	return applied

static func update(host: Node3D) -> void:
	if preload("res://scripts/lol2/player_food_effects.gd").sleeping(host):return
	var form: int = int(host.player.get_meta("lol2_form", int(host.get("player_form")) if host.get("player_form") != null else 0))
	var want: bool = Input.is_physical_key_pressed(KEY_C) and form == 0 and not host.flying and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not host.get_tree().paused
	# Forced save/form restores rebuild the shape before the first physics tick. Reconcile posture
	# from the body, then fit a Human under a low saved ceiling even when C is already released.
	host.crouched = bool(host.player.get_meta("lol2_crouched", host.crouched))
	if bool(host.player.get_meta("lol2_pose_recheck", false)):
		if form != 0:
			host.player.remove_meta("lol2_pose_recheck")
		else:
			var fitted: bool = set_crouch(host, want)
			if not fitted: fitted = set_crouch(host, true)
			if fitted: host.player.remove_meta("lol2_pose_recheck")
	# A save or form change may have rebuilt the body since the last C tick.
	var shape: CollisionShape3D = host.player.get_child(0) as CollisionShape3D
	var rebuilt: bool = want and bool(host.crouched) and shape != null and not is_equal_approx(float(shape.shape.height), Body.CROUCH_HEIGHT)
	if want != bool(host.crouched) or rebuilt: set_crouch(host, want)
