shader_type canvas_item;
render_mode unshaded;
uniform sampler2D background_indices : filter_nearest, repeat_disable;
uniform sampler2D sprite_indices : filter_nearest, repeat_disable;
uniform sampler2D palette : filter_nearest, repeat_disable;
uniform sampler2D destination_remap : filter_nearest, repeat_disable;
uniform bool apply_remap = true;
void fragment() {
    int destination = int(round(texture(background_indices, UV).r * 255.0));
    int source = int(round(texture(sprite_indices, UV).r * 255.0));
    int result = destination;
    if (source == 1 && apply_remap) {
        result = int(round(texelFetch(destination_remap, ivec2(destination, 0), 0).r * 255.0));
    } else if (source > 1) {
        result = source;
    }
    COLOR = vec4(texelFetch(palette, ivec2(result, 0), 0).rgb, 1.0);
}
