extends RefCounted
## L8_SJ night shading (lead 2026-10-31, option A of L8_TREE_TOPS_FINDING: the original hides the trunk tops with its night
## darkness over distance). Every pack face and prop carries its native sector light (tools/lol2/map_lighting.py: [ambient
## signed byte +0x16 of the 26-byte sector record, fade start u16 +6, span u16 +8, 128]); the row is the original's 0x1319B4
## formula (classic_depth_shading.gdshaderinc classic_row: (level * fade) >> 7, 16.16, clamped to rows 0..63). The port's L8
## textures are colour, not palette indices, so the row scales the colour by the average effect of that row of the level's own
## shade table on its palette (tools/prepare_l8_night_shade.py -> darker_jungle_sky/shade_rows.json, a 64x1 lookup; L8: row 52
## = 0.44, row 30 = 0.10, row 16 = 0.07) instead of remapping indices per pixel: an adapter (docs/DEVIATIONS.md). Without the
## lookup the row scales linearly (row / 63). Static assemblies carry no sector in the data (map_lighting.py leaves
## them full-bright): they take the sector of the region their placement stands in (adapter). Option B (`fog_only`): the fade
## to black without the ambient level, behind a flag for the owner.
const TEMPLATE := """shader_type spatial;
render_mode unshaded, %CULL%, depth_draw_opaque;
#include "res://scripts/lol2/classic_depth_shading.gdshaderinc"
uniform sampler2D albedo : source_color, filter_nearest, repeat_enable;
uniform bool cutout = false;
uniform bool billboard = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform int sector_source = 0;
uniform vec4 sector = vec4(63.0, 9999.0, 9999.0, 128.0);
uniform bool night_enabled = true;
uniform bool fog_only = false;
uniform bool has_rows = false;
uniform sampler2D shade_rows : filter_nearest, repeat_disable;
varying vec2 night_level;
void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	vec4 s = sector_source == 0 ? CUSTOM0 : (sector_source == 1 ? INSTANCE_CUSTOM : sector);
	if (fog_only) { s.x = 63.0; }
	vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	night_level = classic_vertex(view_position, s);
	UV = UV * uv_scale + uv_offset;
}
void fragment() {
	vec4 tex = texture(albedo, UV);
	if (cutout && tex.a < 0.5) { discard; }
	float row = night_level.x / night_level.y;
	vec3 k = vec3(1.0);
	if (night_enabled && row >= 0.0) {
		float r = clamp(row, 0.0, 63.0);
		k = has_rows ? texelFetch(shade_rows, ivec2(int(r), 0), 0).rgb : vec3(r / 63.0);
	}
	ALBEDO = tex.rgb * k;
}
"""
const FULL_BRIGHT := Vector4(63, 9999, 9999, 128)
const SHADE_ROWS := "res://assets/lol2/generated/darker_jungle_sky/shade_rows.json"
static var _rows_texture: ImageTexture = null
static var _rows_loaded := false
static var rows_available := false

## The 64x1 RGB lookup of the level's shade rows (prepare_l8_night_shade.py), or null when the file is not staged.
static func shade_rows() -> ImageTexture:
	if _rows_loaded: return _rows_texture
	_rows_loaded = true
	if not FileAccess.file_exists(SHADE_ROWS): return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHADE_ROWS))
	if not parsed is Dictionary or not parsed.get("rows") is Array or (parsed.rows as Array).size() != 64: return null
	var image := Image.create(64, 1, false, Image.FORMAT_RGBF)
	for i in 64:
		var row: Array = parsed.rows[i]
		image.set_pixel(i, 0, Color(float(row[0]), float(row[1]), float(row[2])))
	_rows_texture = ImageTexture.create_from_image(image)
	rows_available = true
	return _rows_texture
const SOURCE_CUSTOM0 := 0
const SOURCE_INSTANCE := 1
const SOURCE_UNIFORM := 2
static var _shaders: Dictionary = {}

static func shader(cull_back: bool) -> Shader:
	var key := "back" if cull_back else "off"
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = TEMPLATE.replace("%CULL%", "cull_back" if cull_back else "cull_disabled")
		_shaders[key] = s
	return _shaders[key]

## The night material for a pack surface: the StandardMaterial3D's texture, cut-out, billboard mode, UV flip and cull mode
## carried over; the sector read from CUSTOM0 (static faces), INSTANCE_CUSTOM (prop batches) or the given uniform.
static func material_for(source: StandardMaterial3D, sector_source: int, sector: Vector4, fog_only: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader(source.cull_mode == BaseMaterial3D.CULL_BACK)
	material.set_shader_parameter("albedo", source.albedo_texture)
	material.set_shader_parameter("cutout", source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
	material.set_shader_parameter("billboard", source.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y)
	material.set_shader_parameter("uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
	material.set_shader_parameter("uv_offset", Vector2(source.uv1_offset.x, source.uv1_offset.y))
	material.set_shader_parameter("sector_source", sector_source)
	material.set_shader_parameter("sector", sector)
	material.set_shader_parameter("night_enabled", true)
	material.set_shader_parameter("fog_only", fog_only)
	var rows := shade_rows()
	material.set_shader_parameter("has_rows", rows != null)
	if rows != null: material.set_shader_parameter("shade_rows", rows)
	return material

static func light_of(row: Variant) -> Vector4:
	if row is Array and (row as Array).size() >= 4:
		return Vector4(float(row[0]), float(row[1]), float(row[2]), float(row[3]))
	return FULL_BRIGHT
