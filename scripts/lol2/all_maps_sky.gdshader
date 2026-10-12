shader_type sky;
uniform sampler2D panorama : source_color, filter_nearest, repeat_enable;
uniform sampler2D panorama_indices : filter_nearest, repeat_enable;
uniform bool indexed = false;
uniform float image_aspect = 4.266666667;
uniform float horizon = 0.666666667;
uniform bool native_projection = false;
uniform float vertical_origin = 0.0;
uniform float native_heading = 0.0;
uniform float native_principal_y = 200.0;
// Optional measured crop for a fixed native reference pose, not a camera formula.
uniform bool captured_crop = false;
uniform vec2 captured_focal_pixels = vec2(491.5225, 409.5996);
uniform vec2 captured_principal_point = vec2(320.0, 200.0);
uniform vec3 captured_right = vec3(1.0, 0.0, 0.0);
uniform vec3 captured_up = vec3(0.0, 1.0, 0.0);
uniform vec3 captured_forward = vec3(0.0, 0.0, -1.0);
uniform vec2 captured_offset = vec2(0.0);
uniform vec2 captured_phase = vec2(0.0);
// Original indexed panorama, modern cylindrical placement. Alignment is review-time.
void sky() {
    float yaw = atan(EYEDIR.x, -EYEDIR.z);
    float pitch = atan(EYEDIR.y, length(EYEDIR.xz));
    vec2 uv = vec2(fract(yaw / TAU), clamp(horizon - pitch * image_aspect / TAU, 0.0, 0.998));
    if ((captured_crop || native_projection) && !AT_CUBEMAP_PASS) {
        float depth = max(dot(EYEDIR, captured_forward), 0.0001);
        vec2 pixel = floor(captured_principal_point + captured_focal_pixels *
            vec2(dot(EYEDIR, captured_right), -dot(EYEDIR, captured_up)) / depth);
        vec2 source_pixel = floor((pixel + captured_phase) * 0.5) + captured_offset;
        if (native_projection && !captured_crop) {
            source_pixel.x = floor(native_heading * 1280.0 + 0.25 + pixel.x * 0.5);
            source_pixel.y = floor(200.0 - vertical_origin + floor((200.0 - native_principal_y) * 0.5) * 0.5 + pixel.y * 0.5);
            // Native fills above the image with its first pixel. Below-image
            // framebuffer retention is not reproduced by the modern sky pass.
            if (source_pixel.y < 0.0) { source_pixel = vec2(0.0); }
        }
        uv = vec2(fract((source_pixel.x + 0.5) / 1280.0), clamp((source_pixel.y + 0.5) / 300.0, 0.0, 0.998));
    }
    if (indexed) {
        int index = int(round(texture(panorama_indices, uv).r * 255.0));
        COLOR = vec3(float(index % 16) * 12.0 + 64.0, float(index / 16) * 12.0 + 64.0, 0.0) / 255.0;
    } else {
        COLOR = texture(panorama, uv).rgb;
    }
}
