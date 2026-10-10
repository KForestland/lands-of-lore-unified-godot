extends Node
## Keeps the original raster panorama attached to the active camera, including
## saved map scenes. Mouse pitch is converted to a native vertical look shift.
@export var environment_path: NodePath
var camera_override: Camera3D
var projection_override := Vector2(-1, -1)

func _process(_delta: float) -> void:
	var camera := camera_override if is_instance_valid(camera_override) else get_viewport().get_camera_3d()
	var world := get_node_or_null(environment_path) as WorldEnvironment
	if camera == null or world == null: return
	update_sky(world.environment, camera, projection_override)

static func update_sky(environment: Environment, camera: Camera3D, principal_override := Vector2(-1, -1)) -> void:
	if environment == null or environment.sky == null: return
	var material := environment.sky.sky_material as ShaderMaterial
	if material == null or material.get_shader_parameter("native_projection") != true: return
	if material.get_shader_parameter("captured_crop") == true: return
	var size := camera.get_viewport().get_visible_rect().size
	if size.x <= 0 or size.y <= 0: return
	var basis := camera.global_basis.orthonormalized()
	var center := camera.unproject_position(camera.global_position - basis.z * 100.0)
	var right := camera.unproject_position(camera.global_position + (basis.x - basis.z) * 100.0)
	var up := camera.unproject_position(camera.global_position + (basis.y - basis.z) * 100.0)
	var scale := Vector2(640.0, 400.0) / size
	var focal := Vector2(right.x - center.x, center.y - up.y) * scale
	center *= scale
	if principal_override.x >= 0: center = principal_override
	var forward := -basis.z
	var heading := fposmod(atan2(forward.x, -forward.z) / TAU, 1.0)
	# A raised native horizon corresponds to looking down. The free camera
	# rotates rather than shears; this conversion preserves the central look.
	var look_center := center.y + focal.y * tan(asin(clampf(forward.y, -0.999, 0.999)))
	material.set_shader_parameter("native_heading", heading)
	material.set_shader_parameter("native_principal_y", roundf(look_center))
	material.set_shader_parameter("captured_focal_pixels", focal)
	material.set_shader_parameter("captured_principal_point", center)
	material.set_shader_parameter("captured_right", basis.x)
	material.set_shader_parameter("captured_up", basis.y)
	material.set_shader_parameter("captured_forward", forward)
