shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
#include "map_lighting.gdshaderinc"
#include "map_sector_visibility.gdshaderinc"
// Packed RGB matches indexed_remap_layer. active_view is the camera mask
// shifted once: cull_mask 1|(source_id<<1) makes every layer-1 mesh visible
// and distinguishes the pass without a per-frame uniform.
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform sampler2D shadow_mask : filter_nearest, repeat_disable;
uniform bool has_shadow_mask = false;
uniform bool legacy_shadow = false;
uniform bool sprite = false;
uniform bool cutout = false;
uniform bool front_faces_only = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform int source_id = 0;
varying flat int active_view;

void vertex() {
    sector_admitted = sector_visibility_value(CUSTOM1.x);
	surface_light = use_vertex_light ? CUSTOM0 : sector_light;
	active_view = int(CAMERA_VISIBLE_LAYERS >> 1u);
	if (sprite) {
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
		vec3 forward = cross(right, up);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
	}
}

void fragment() {
    if (sector_admitted < 0.5) { discard; }
	if (front_faces_only && !FRONT_FACING) {
		discard;
	}
	vec2 uv = UV * uv_scale + uv_offset;
	uv = sprite ? clamp(uv, vec2(0.0), vec2(1.0)) : fract(uv);
	int index = int(round(texture(indices, uv).r * 255.0));
	bool shadow_sample = false;
	if (has_shadow_mask) {
		int marked = int(round(texture(shadow_mask, uv).r * 255.0));
		if (marked > 0 && index < 2) {
			index = 1;
			shadow_sample = true;
		}
	} else if (legacy_shadow && index == 1) {
		shadow_sample = true;
	}
	// Index 0 is transparent only for declared cutouts. An opaque texel of 0 stays.
	if (cutout && index == 0) {
		discard;
	}
	bool emit = active_view == 0 || active_view == source_id;
	if (!emit) {
		if (sprite && shadow_sample) {
			discard;
		}
		index = 0;
	} else if (active_view == 0 && shadow_sample) {
		discard;
	}
	if (emit && !shadow_sample) { index = shade_index(index, length(VERTEX)); }
	ALBEDO = vec3(
		float(index % 16) * 12.0 + 64.0,
		float(index / 16) * 12.0 + 64.0,
		0.0) / 255.0;
}
