shader_type canvas_item;
render_mode unshaded;
uniform sampler2D background_indices : filter_nearest, repeat_disable;
uniform sampler2D sprite_indices : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D destination_remap : filter_nearest, repeat_disable;
uniform bool apply_remap = true;
uniform bool packed_indices = false;
int read_index(vec4 sample_value) {
    if (packed_indices) {
        ivec2 nibbles = ivec2(round((sample_value.rg * 255.0 - 64.0) / 12.0));
        nibbles = clamp(nibbles, ivec2(0), ivec2(15));
        return nibbles.x + 16 * nibbles.y;
    }
    return int(round(sample_value.r * 255.0));
}
void fragment() {
    int destination = read_index(texture(background_indices, UV));
    int source = read_index(texture(sprite_indices, UV));
    int result = destination;
    if (source == 1 && apply_remap) {
        result = int(round(texelFetch(destination_remap, ivec2(destination, 0), 0).r * 255.0));
    } else if (source > 1) {
        result = source;
    }
    COLOR = vec4(texelFetch(palette, ivec2(result, 0), 0).rgb, 1.0);
}
