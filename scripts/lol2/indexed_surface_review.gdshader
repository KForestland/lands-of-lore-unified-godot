shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform bool sprite = false;
// Fixed (non-billboard) faces whose index 0 is transparent, e.g. alpha-cutout movable materials.
uniform bool cutout = false;
uniform bool roof_tint = false;
uniform bool unresolved = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
#include "res://scripts/lol2/classic_depth_shading.gdshaderinc"
void vertex() {
    if (sprite) {
        vec3 up = vec3(0.0, 1.0, 0.0);
        vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
        vec3 forward = cross(right, up);
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
    }
    // Static meshes carry their region's sector; anything without one (creatures, items, placed props) uses the viewer's.
    vec4 classic_sector = CUSTOM0.w >= 2.0 ? CUSTOM0 : lol2_classic_view_sector;
    classic_level = classic_vertex((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, classic_sector);
}
#include "res://scripts/lol2/cave_light_field.gdshaderinc"
uniform bool lighting_capture = false;
uniform bool mask_capture = false;
uniform bool compare_crystal_depth = false;
uniform sampler2D crystal_depth : filter_nearest, repeat_disable;
void fragment() {
    vec2 uv = UV * uv_scale + uv_offset;
    uv = sprite ? clamp(uv, vec2(0.0), vec2(1.0)) : fract(uv);
    int index = int(round(texture(indices, uv).r * 255.0));
    if ((sprite || cutout) && index == 0) { discard; }
    // Sprite index 1 is the shadow marker the remap layer reads; it is not a colour and stays unshaded.
    if (!((sprite || cutout) && index == 1)) {
        index = classic_shade(index, classic_level);
        // Row 0 maps every index to 0, which the layer compositor reads as transparent. Index 3 is the same
        // palette black (L1 palette 0 == 3), so a fully dark sprite pixel stays opaque black as in the original.
        if ((sprite || cutout) && index == 0) { index = 3; }
    }
    if (compare_crystal_depth && (CAMERA_VISIBLE_LAYERS & 32768u) != 0u) {
        uvec3 bytes = uvec3(round(texture(crystal_depth, SCREEN_UV).rgb * 255.0));
        bool has_depth = all(greaterThanEqual(bytes, uvec3(128u)));
        bytes = max(bytes, uvec3(128u)) - uvec3(128u);
        uint packed_depth = bytes.r | (bytes.g << 7u) | (bytes.b << 14u);
        // Coplanar ordinary/crystal layers intentionally compose. Quantization is 1/64 world unit; range covers the 30000-unit camera far plane.
        if (has_depth && -VERTEX.z > float(packed_depth) / 64.0 + 0.02) { discard; }
    }
    ALBEDO = vec3(float(index % 16) * 12.0 + 64.0, float(index / 16) * 12.0 + 64.0, unresolved ? 128.0 : roof_tint ? 255.0 : 0.0) / 255.0;
    if (mask_capture) { ALBEDO = vec3(64.0, 64.0, 0.0) / 255.0; }
    if (mask_capture && (CAMERA_VISIBLE_LAYERS & 16384u) != 0u) {
        float depth_value = clamp(floor(-VERTEX.z * 64.0 + 0.5), 0.0, 2097151.0);
        ALBEDO = (vec3(mod(depth_value, 128.0), mod(floor(depth_value / 128.0), 128.0), floor(depth_value / 16384.0)) + vec3(128.0)) / 255.0;
    }
    if (lighting_capture) {
        if ((sprite || cutout) && index <= 1) { discard; }
        ALBEDO = cave_light_field(VERTEX, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
    }
}
