shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
 vec2 p = (UV - vec2(0.5)) * 2.0;
 float radius = length(p);
 if (radius > 1.0) { discard; }
 float rim = smoothstep(0.84, 0.92, radius);
 float wave = sin(p.y * 15.0 + sin(p.x * 7.0 + TIME * 0.4) - TIME * 0.7);
 vec3 glass = mix(vec3(0.24,0.38,0.49),vec3(0.66,0.79,0.85),0.5 + 0.18 * wave);
 vec3 silver = mix(vec3(0.30,0.34,0.38),vec3(0.84,0.87,0.90),0.5 + 0.5 * p.x);
 ALBEDO = mix(glass,silver,rim);
}
