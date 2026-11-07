shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, skip_vertex_transform;
// The original's backdrop drawn on world faces: a solid region edge with no wall texture (or the clear pixels of a
// cut-out wall) shows the panorama, and nothing beyond it, because the portal walk stops at solid edges. Same
// projection and parameters as all_maps_sky.gdshader (native_projection branch), kept in step by map_sky_controller.gd.
uniform sampler2D panorama : source_color, filter_nearest, repeat_enable;
uniform sampler2D panorama_indices : filter_nearest, repeat_enable;
uniform bool indexed = false;
// Opt-in Act 2 host adapter: replace below-image edge stretching with the panorama first pixel.
uniform bool below_image_first_pixel = false;
uniform float vertical_origin = 0.0;
uniform float native_principal_y = 200.0;
uniform vec2 captured_focal_pixels = vec2(491.5225, 409.5996);
uniform vec2 captured_principal_point = vec2(320.0, 200.0);
uniform vec3 captured_right = vec3(1.0, 0.0, 0.0);
uniform vec3 captured_up = vec3(0.0, 1.0, 0.0);
uniform vec3 captured_forward = vec3(0.0, 0.0, -1.0);
uniform vec2 captured_phase = vec2(0.0);

// Backdrop faces lie on their wall or floor plane. Scaling the view-space position keeps every pixel where it is but
// puts the backdrop just behind anything on the same plane (a textured or cut-out wall wins without an inset).
void vertex() {
    VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz * 1.001;
}

void fragment() {
    vec3 eye = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
    float depth = max(dot(eye, captured_forward), 0.0001);
    vec2 pixel = floor(captured_principal_point + captured_focal_pixels *
        vec2(dot(eye, captured_right), -dot(eye, captured_up)) / depth);
    vec2 source_pixel = floor((pixel + captured_phase) * 0.5);
    source_pixel.x = floor(fract(atan(eye.x, -eye.z) / TAU) * 1280.0 + 160.25);
    source_pixel.y = floor(200.0 - vertical_origin + floor((200.0 - native_principal_y) * 0.5) * 0.5 + pixel.y * 0.5);
    if (source_pixel.y < 0.0 || (below_image_first_pixel && source_pixel.y >= 300.0)) { source_pixel = vec2(0.0); }
    vec2 uv = vec2(fract((source_pixel.x + 0.5) / 1280.0), clamp((source_pixel.y + 0.5) / 300.0, 0.0, 0.998));
    if (indexed) {
        int index = int(round(texture(panorama_indices, uv).r * 255.0));
        ALBEDO = vec3(float(index % 16) * 12.0 + 64.0, float(index / 16) * 12.0 + 64.0, 0.0) / 255.0;
    } else {
        ALBEDO = texture(panorama, uv).rgb;
    }
}
