shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform bool sprite = false;
uniform bool roof_tint = false;
uniform bool unresolved = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
void vertex() {
    if (sprite) {
        vec3 up = vec3(0.0, 1.0, 0.0);
        vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
        vec3 forward = cross(right, up);
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
    }
}
#include "res://scripts/lol2/cave_light_field.gdshaderinc"
uniform bool lighting_capture = false;
uniform bool mask_capture = false;
void fragment() {
    vec2 uv = UV * uv_scale + uv_offset;
    uv = sprite ? clamp(uv, vec2(0.0), vec2(1.0)) : fract(uv);
    int index = int(round(texture(indices, uv).r * 255.0));
    if (sprite && index == 0) { discard; }
    ALBEDO = vec3(float(index % 16) * 12.0 + 64.0, float(index / 16) * 12.0 + 64.0, unresolved ? 128.0 : roof_tint ? 255.0 : 0.0) / 255.0;
    if (mask_capture) { ALBEDO = vec3(64.0, 64.0, 0.0) / 255.0; }
    if (lighting_capture) {
        if (sprite && index <= 1) { discard; }
        ALBEDO = cave_light_field(VERTEX, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
    }
}
