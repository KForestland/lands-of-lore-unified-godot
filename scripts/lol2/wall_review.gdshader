shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D wall_texture : source_color, filter_nearest, repeat_disable;
uniform int address_mode = 8;
void fragment() {
 vec2 size = vec2(textureSize(wall_texture, 0));
 vec2 uv = UV;
 uv.x = address_mode == 0 ? clamp(uv.x, 0.0, 1.0 - 0.5 / size.x) : fract(uv.x);
 uv.y = address_mode == 8 ? fract(uv.y) : clamp(uv.y, 0.0, 1.0 - 0.5 / size.y);
 ALBEDO = texture(wall_texture, uv).rgb;
}
