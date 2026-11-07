// Verified source fields and palette rows, with modern per-fragment distance.
uniform bool source_lighting = false;
uniform sampler2D shade_table : filter_nearest, repeat_disable;
uniform bool use_vertex_light = true;
uniform vec4 sector_light = vec4(63.0, 9999.0, 9999.0, 128.0);
uniform bool magic_light = false;
uniform float magic_radius = 240.0;
varying vec4 surface_light;

int shade_index(int index, float distance_from_eye) {
	if (!source_lighting) { return index; }
	float delta = max(0.0, distance_from_eye - surface_light.y);
	float fade = delta <= 0.0 ? 1.0 : (surface_light.z <= 0.0 ? 0.0 : clamp(1.0 - delta / surface_light.z, 0.0, 1.0));
	float level = clamp(surface_light.x * fade * surface_light.w / 128.0, 0.0, 63.0);
	if (magic_light) {
		float local = 1.0 - smoothstep(magic_radius * 0.15, magic_radius, distance_from_eye);
		level = mix(level, 63.0, local);
	}
	return int(round(texture(shade_table, vec2((float(index) + 0.5) / 256.0, (floor(level) + 0.5) / 64.0)).r * 255.0));
}
