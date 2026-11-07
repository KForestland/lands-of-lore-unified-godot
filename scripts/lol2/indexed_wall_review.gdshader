shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D wall_indices : filter_nearest, repeat_disable;
uniform int address_mode = 8;
#include "res://scripts/lol2/cave_light_field.gdshaderinc"
#include "res://scripts/lol2/classic_depth_shading.gdshaderinc"
void vertex() {
    classic_level = classic_vertex((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, CUSTOM0.w >= 2.0 ? CUSTOM0 : lol2_classic_view_sector);
}
uniform bool lighting_capture = false;
uniform bool mask_capture = false;
void fragment() {
    vec2 size = vec2(textureSize(wall_indices, 0));
    vec2 uv = UV;
    uv.x = address_mode == 0 ? clamp(uv.x, 0.0, 1.0 - 0.5 / size.x) : fract(uv.x);
    uv.y = address_mode == 8 ? fract(uv.y) : clamp(uv.y, 0.0, 1.0 - 0.5 / size.y);
    int index = classic_shade(int(round(texture(wall_indices, uv).r * 255.0)), classic_level);
    ALBEDO = vec3(float(index % 16) * 12.0 + 64.0, float(index / 16) * 12.0 + 64.0, 0.0) / 255.0;
    if (mask_capture) { ALBEDO = vec3(64.0, 64.0, 0.0) / 255.0; }
    if (mask_capture && (CAMERA_VISIBLE_LAYERS & 16384u) != 0u) {
        float depth_value = clamp(floor(-VERTEX.z * 64.0 + 0.5), 0.0, 2097151.0);
        ALBEDO = (vec3(mod(depth_value, 128.0), mod(floor(depth_value / 128.0), 128.0), floor(depth_value / 16384.0)) + vec3(128.0)) / 255.0;
    }
    if (lighting_capture) {
        ALBEDO = cave_light_field(VERTEX, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
    }
}
