// Artistic walkthrough light field, not recovered original light values.
vec3 cave_light_field(vec3 view_position) {
    float distance_to_camera = length(view_position);
    float near_weight = exp(-distance_to_camera / 240.0);
    // Warm near fill and cooler distant rock, without crushing navigation.
    vec3 distant = vec3(0.48, 0.55, 0.65);
    vec3 nearby = vec3(1.0, 0.96, 0.88);
    return mix(distant, nearby, near_weight);
}
