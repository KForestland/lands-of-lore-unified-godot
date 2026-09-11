shader_type canvas_item;
render_mode unshaded;
uniform sampler2D background_indices : filter_nearest, repeat_disable;
uniform sampler2D source_indices : filter_nearest, repeat_disable;
uniform sampler2D remap : filter_nearest, repeat_disable;
int decode_index(vec4 value) {
    ivec2 nibble = clamp(ivec2(round((value.rg * 255.0 - 64.0) / 12.0)), ivec2(0), ivec2(15));
    return nibble.x + 16 * nibble.y;
}
void fragment() {
    vec4 background = texture(background_indices, UV);
    int destination = decode_index(background);
    int source = decode_index(texture(source_indices, UV));
    int result = destination;
    float marker = background.b;
    if (source > 1) { result = source; marker = 0.0; }
    // A diagnostic unresolved floor has no trustworthy original index.
    else if (source == 1 && !(marker > 0.25 && marker < 0.75)) {
        result = int(round(texelFetch(remap, ivec2(destination, 0), 0).r * 255.0));
    }
    COLOR = vec4((float(result % 16) * 12.0 + 64.0) / 255.0,
                 (float(result / 16) * 12.0 + 64.0) / 255.0, marker, 1.0);
}
