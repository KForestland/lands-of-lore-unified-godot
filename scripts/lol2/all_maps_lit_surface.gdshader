shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
#include "map_lighting.gdshaderinc"
#include "map_sector_visibility.gdshaderinc"
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform bool sprite = false;
uniform bool cutout = false;
uniform bool front_faces_only = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
void vertex() {
    sector_admitted = sector_visibility_value(CUSTOM1.x);
    surface_light = use_vertex_light ? CUSTOM0 : sector_light;
    if (sprite) {
        vec3 up = vec3(0.0, 1.0, 0.0);
        vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
        vec3 forward = cross(right, up);
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(forward, 0.0), MODEL_MATRIX[3]);
    }
}
void fragment() {
    if (sector_admitted < 0.5) { discard; }
    if (front_faces_only && !FRONT_FACING) { discard; }
    vec2 uv = UV * uv_scale + uv_offset;
    uv = sprite ? clamp(uv, vec2(0.0), vec2(1.0)) : fract(uv);
    int index = int(round(texture(indices, uv).r * 255.0));
    if (cutout && index == 0) { discard; }
    index = shade_index(index, length(VERTEX));
    ALBEDO = texture(palette, vec2((float(index) + 0.5) / 256.0, 0.5)).rgb;
}
