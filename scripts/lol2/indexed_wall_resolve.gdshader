shader_type canvas_item;
render_mode unshaded;
uniform sampler2D packed_wall_indices : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform bool apply_roof_tint = false;
void fragment() {
    vec2 packed = texture(packed_wall_indices, UV).rg;
    ivec2 nibbles = clamp(ivec2(round((packed * 255.0 - 64.0) / 12.0)), ivec2(0), ivec2(15));
    int index = nibbles.x + 16 * nibbles.y;
    vec3 rgb = texelFetch(palette, ivec2(index, 0), 0).rgb;
    float marker = texture(packed_wall_indices, UV).b;
    if (apply_roof_tint && marker > 0.75) { rgb = floor(rgb * 255.0 * 0.65 + 0.5) / 255.0; }
    else if (apply_roof_tint && marker > 0.25) { rgb = vec3(217.0, 38.0, 140.0) / 255.0; }
    COLOR = vec4(rgb, 1.0);
}
