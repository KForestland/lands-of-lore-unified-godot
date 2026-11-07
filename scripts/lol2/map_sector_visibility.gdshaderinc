uniform bool sector_visibility = false;
uniform sampler2D sector_mask : filter_nearest, repeat_disable;
uniform float render_sector = -1.0;
varying flat float sector_admitted;
float sector_visibility_value(float vertex_sector) {
    float sector = use_vertex_light ? vertex_sector : render_sector;
    float admitted = 1.0;
    if (sector_visibility && sector >= 0.0) {
        float width = float(textureSize(sector_mask, 0).x);
        admitted = textureLod(sector_mask, vec2((sector + 0.5) / width, 0.5), 0.0).r;
    }
    return admitted;
}
