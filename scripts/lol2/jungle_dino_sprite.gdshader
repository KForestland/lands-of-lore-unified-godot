shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform sampler2D source_palette : source_color, filter_nearest, repeat_disable;
void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 forward = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	int index = int(round(texture(indices, clamp(UV, vec2(0.0), vec2(1.0))).r * 255.0));
	if (index == 0) { discard; }
	ALBEDO = texture(source_palette, vec2((float(index) + 0.5) / 256.0, 0.5)).rgb;
}
