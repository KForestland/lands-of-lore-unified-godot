// Artistic walkthrough light field, not recovered original light values.
uniform vec3 glow_positions[4];
uniform bool glow_enabled = true;
uniform bool glowing_prop = false;
vec3 cave_light_field(vec3 view_position, vec3 world_position) {
    float near_weight = exp(-length(view_position) / 240.0);
    vec3 result = mix(vec3(0.48, 0.55, 0.65), vec3(1.0, 0.96, 0.88), near_weight);
    if (glow_enabled) {
        for (int i = 0; i < 4; i++) {
            float weight = max(0.0, 1.0 - distance(world_position, glow_positions[i]) / 80.0);
            result += vec3(0.20, 0.65, 0.30) * weight * weight;
        }
        if (glowing_prop) { result = max(result, vec3(1.15, 1.8, 1.1)); }
    }
    // RGB8 light buffer encodes multipliers0..2, including local brightening.
    return clamp(result, vec3(0.0), vec3(2.0)) * 0.5;
}
