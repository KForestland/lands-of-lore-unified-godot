shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, skip_vertex_transform;
// See-through audit: backdrop.gdshader geometry and depth, drawn flat cyan.
void vertex() {
    VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 1.001;
}
void fragment() {
    ALBEDO = vec3(0.0, 1.0, 1.0);
}
