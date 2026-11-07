shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform sampler2D source_palette : source_color, filter_nearest, repeat_disable;
// Ghost views (Dark Halls SHADE, view flags 0x18): the frame bytes are grey intensity ramps, not palette indices
// (33..191); drawn through the palette they are noise. Adapter: a translucent tint whose alpha is the intensity.
uniform bool ghost = false;
uniform vec4 ghost_tint : source_color = vec4(0.62, 0.80, 1.0, 0.85);
void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 forward = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	int index = int(round(texture(indices, clamp(UV, vec2(0.0), vec2(1.0))).r * 255.0));
	if (index == 0) { discard; }
	if (ghost) {
		ALBEDO = ghost_tint.rgb;
		ALPHA = (float(index) / 255.0) * ghost_tint.a;
	} else {
		ALBEDO = texture(source_palette, vec2((float(index) + 0.5) / 256.0, 0.5)).rgb;
	}
}
