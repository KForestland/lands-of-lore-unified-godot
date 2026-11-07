// Classic depth shading (original renderer 0x1319B4 + shade-row byte load 0x1300C8; G43 + Opus decompile 2026-10-29).
// Sector vec4: x ambient (signed byte +0x16 of the region's light descriptor), y fade start (u16 +6), z span (u16 +8),
// w surface multiplier [0xFD8A8]. The multiplier comes from a run-time wall-edge byte +0x40 / sprite definition +0x1F
// whose file source is not traced: 128, the neutral value of mult * (x >> 7), stands in until DOSBox capture (G38).
// w < 2 means "not a Classic-shaded surface" (a mesh without CUSTOM0 may read the GL default 0,0,0,1): unchanged index.
// Light-record terms are run-time lists (up to 10 records at 0xFD8C4, G47): 0 here. Record: +0/+4/+8 position, +0x0C scalar
// (halved or 16.16-multiplied, then summed; 0 skips), +0x10 compared with the caller's third argument (a match skips;
// name UNKNOWN), u16 +0x14 << 16 fade width, byte +0x16 << 16 full-strength distance (cutoff = their sum, 0x131ADD),
// byte +0x17 bits 0-1 type, bit 0x40 = B sum instead of A. [0xFD8C0] (added to A or B by [0x15288]) is also 0 here.
global uniform sampler2D lol2_classic_shade;
global uniform vec4 lol2_classic_view_sector;
// Owner direction 2026-10-29: the decoded depth shading is an optional "original darkness" toggle, default OFF
// (classic_depth_shading.gd set_enabled; the Cave walkthrough's O key). Off = the index passes unchanged.
global uniform bool lol2_classic_shading_enabled;
// The original steps the level linearly in screen space along each wall column (0x12FB54 accumulator). Godot has no
// noperspective varyings: (level * w, w) under perspective-correct interpolation gives the same screen-linear value.
varying vec2 classic_level;

// Native fixed point in 32-bit ints: distance is 16.16, the result is the row in 16.16 clamped to 0..0x3F0000.
float classic_row(vec3 view_position, vec4 sector) {
	if (sector.w < 2.0) { return -1.0; }
	// 16.16 like the original; 32767 keeps the product inside int32 (the camera far plane is 30000).
	int delta = int(min(length(view_position), 32767.0) * 65536.0) - int(sector.y) * 65536;
	int span = int(sector.z) * 65536;
	// (delta << 16) / (span << 16) in the original is delta / span (integer quotient).
	int fade = delta < 1 ? 65536 : (delta < span ? 65536 - delta / int(sector.z) : 0);
	// (fade * (ambient << 16)) >> 16 == fade * ambient exactly; then >> 7 and * multiplier.
	int level = int(sector.w) * ((fade * int(sector.x)) >> 7);
	return float(clamp(level, 0, 0x3F0000)) / 65536.0;
}

// view_position is the vertex in view space; clip w of a perspective camera is -view_position.z.
vec2 classic_vertex(vec3 view_position, vec4 sector) {
	float w = max(-view_position.z, 0.0001);
	return vec2(classic_row(view_position, sector) * w, w);
}

int classic_shade(int index, vec2 interpolated) {
	if (!lol2_classic_shading_enabled) { return index; }
	float row = interpolated.x / interpolated.y;
	if (row < 0.0) { return index; }
	// Adapter: the endpoint is clamped natively; this extra clamp of the interpolated row is not proven native (rows 64/65 exist).
	int r = clamp(int(floor(row)), 0, 63);
	return int(round(texelFetch(lol2_classic_shade, ivec2(index, r), 0).r * 255.0));
}
