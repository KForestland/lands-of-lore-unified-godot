// Cave light field (Enhanced lighting pass): an RGB multiplier buffer the resolve shader applies to the palette colour.
// Owner direction 2026-10-29 ("light sources, not a small cone of light around us"): a flat ambient with NO player-centred
// falloff, plus warm local lights at the hosted native emitters (wall torches, lava flames, burning tar pits;
// cave_light_sources.gd uploads the nearest ones). Colours, ranges and the quadratic falloff are presentation adapters
// (docs/DEVIATIONS.md), not recovered original light values. The four crystal glows (descriptor 469) stay as before.
uniform vec3 ambient_light = vec3(0.85, 0.85, 0.85);
uniform int light_count = 0;
uniform vec3 light_positions[24];
// rgb = colour times intensity (added to the multiplier at the source), w = range in world units.
uniform vec4 light_colors[24];
uniform vec3 glow_positions[4];
uniform vec4 glow_active = vec4(1.0);
uniform bool glow_enabled = true;
uniform bool glowing_prop = false;
vec3 cave_light_field(vec3 view_position, vec3 world_position) {
    vec3 result = ambient_light;
    for (int i = 0; i < light_count; i++) {
        float weight = max(0.0, 1.0 - distance(world_position, light_positions[i]) / max(light_colors[i].w, 1.0));
        result += light_colors[i].rgb * weight * weight;
    }
    if (glow_enabled) {
        for (int i = 0; i < 4; i++) {
            float weight = max(0.0, 1.0 - distance(world_position, glow_positions[i]) / 80.0);
            result += vec3(0.20, 0.65, 0.30) * weight * weight * glow_active[i];
        }
        if (glowing_prop) { result = max(result, vec3(1.15, 1.8, 1.1)); }
    }
    // RGB8 light buffer encodes multipliers 0..2, including local brightening.
    return clamp(result, vec3(0.0), vec3(2.0)) * 0.5;
}
