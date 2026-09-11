shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D indices : filter_nearest, repeat_disable;
uniform bool solid = false;
uniform float solid_index = 0.0;
void fragment() {
    float value = solid ? solid_index / 255.0 : texture(indices, UV).r;
    // This diagnostic deliberately requires the project's Compatibility renderer.
    int index = int(round(value * 255.0));
    // Two nibbles, widely spaced above black: survive the Compatibility
    // colour conversion without collapsing low index values.
    ALBEDO = vec3(float(index % 16) * 12.0 + 64.0, float(index / 16) * 12.0 + 64.0, 0.0) / 255.0;
}
