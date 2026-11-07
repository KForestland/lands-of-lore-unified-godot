extends RefCounted
## L9/L20 cavebk origin -100 puts the horizon below the image; repeating its final row made vertical stripes.
## Native framebuffer retention is not reproduced. First-pixel fill is an explicit opt-in adapter.
static func apply(host: Node3D, area: String) -> void:
	if area not in ["L9_DR", "L20_BB"]: return
	var world := host.get_node_or_null("JungleSkyEnvironment") as WorldEnvironment
	if world != null and world.environment.sky != null:
		var material := world.environment.sky.sky_material as ShaderMaterial
		if material != null: material.set_shader_parameter("below_image_first_pixel", true)
	var backdrop: Variant = host.get("backdrop_material")
	if backdrop is ShaderMaterial: backdrop.set_shader_parameter("below_image_first_pixel", true)
