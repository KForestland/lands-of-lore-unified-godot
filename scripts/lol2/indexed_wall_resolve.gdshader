shader_type canvas_item;
render_mode unshaded;
uniform sampler2D packed_wall_indices : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
void fragment() {
    vec2 packed = texture(packed_wall_indices, UV).rg;
    ivec2 nibbles = clamp(ivec2(round((packed * 255.0 - 64.0) / 12.0)), ivec2(0), ivec2(15));
    int index = nibbles.x + 16 * nibbles.y;
    COLOR = vec4(texelFetch(palette, ivec2(index, 0), 0).rgb, 1.0);
}
