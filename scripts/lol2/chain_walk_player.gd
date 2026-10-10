extends CharacterBody3D
## Development-scene controller in floor-review units (1/64 native units).
const EYE_HEIGHT := 0.65
var active := false
var view_pitch := 0.0
var test_direction := Vector2.ZERO
var automated := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.125
	capsule.height = 0.75
	shape.shape = capsule
	shape.position.y = 0.375
	add_child(shape)
	floor_snap_length = 0.1
	safe_margin = 0.002

func _physics_process(delta: float) -> void:
	if not active:
		return
	var axis := test_direction if automated else Vector2.ZERO
	if not automated and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		axis = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := basis * Vector3(axis.x, 0, axis.y).normalized()
	velocity.x = direction.x * 1.25
	velocity.z = direction.z * 1.25
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.0 * delta
	move_and_slide()
