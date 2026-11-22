extends Node3D
## Islands mode (Fable TEMPLE-ISLANDS 2026-11-07, L14 first). The original clears the frame to black and shows its panorama
## only through a region ceiling that has no surface material (the pack omits that ceiling face: 344 L14 regions; longplay
## g_275 shows the starry sky over the three-door room, g_276-g_278 black around the ledge maze). Here the host's background
## becomes black and every such region gets a ceiling polygon at its native ceiling height (sector_potential/<area>.json
## region_ceiling, from the archive's region records) drawn with backdrop.gdshader: the panorama by view direction, the same
## adapter the Jungle uses for untextured boundary walls. The polygons are batched per room, so portal visibility hides them
## with the room. Drawing only; no collision.
const SHADER := preload("res://scripts/lol2/backdrop.gdshader")
var polygons := 0
var rooms := 0

static func attach(host: Node3D, nav: Array, faces: Array, ceilings: Array, islands: Dictionary) -> Node:
	var node: Node3D = load("res://scripts/lol2/island_sky_ceilings.gd").new()
	node.name = "IslandSkyCeilings"
	host.add_child(node)
	node.build(host, nav, faces, ceilings, islands)
	return node

## The panorama material of the host's original sky, mirrored by its sky controller (map_sky_controller.gd).
static func backdrop_material_of(host: Node3D) -> ShaderMaterial:
	var world := host.get_node_or_null("JungleSkyEnvironment") as WorldEnvironment
	if world == null or world.environment == null or world.environment.sky == null: return null
	var sky := world.environment.sky.sky_material as ShaderMaterial
	if sky == null: return null
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for key in ["panorama", "panorama_indices", "vertical_origin", "below_image_first_pixel"]:
		material.set_shader_parameter(key, sky.get_shader_parameter(key))
	for child in host.get_children():
		var mirrors: Variant = child.get("mirrors")
		if mirrors is Array and child.get("environment_path") != null:
			child.mirrors.append(material)
			break
	return material

func build(host: Node3D, nav: Array, faces: Array, ceilings: Array, islands: Dictionary) -> void:
	var material := backdrop_material_of(host)
	if material == null: return
	var world := host.get_node_or_null("JungleSkyEnvironment") as WorldEnvironment
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color.BLACK
	var roofed: Dictionary = {}
	for face in faces:
		if face is Dictionary and str(face.get("kind", "")) == "ceiling" and face.get("region") != null: roofed[int(face.region)] = true
	var tools: Dictionary = {}
	for r in nav.size():
		if roofed.has(r) or not islands.has(r): continue
		var poly: Array = nav[r][0]
		if poly.size() < 3: continue
		var height := float(ceilings[r]) if r < ceilings.size() else float(nav[r][1]) + 125.0
		var island := int(islands[r])
		if not tools.has(island):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[island] = tool
		var tool: SurfaceTool = tools[island]
		var first := Vector3(float(poly[0][0]), height, float(poly[0][1]))
		for i in range(1, poly.size() - 1):
			var b := Vector3(float(poly[i][0]), height, float(poly[i][1]))
			var c := Vector3(float(poly[i + 1][0]), height, float(poly[i + 1][1]))
			# Both windings: the panorama is seen from below, and the shader culls back faces.
			for point in [first, b, c, first, c, b]: tool.add_vertex(point)
		polygons += 1
	var listed: Variant = host.get("cluster_meshes")
	for island in tools:
		var mesh := MeshInstance3D.new()
		mesh.name = "Sky_%d" % int(island)
		mesh.mesh = (tools[island] as SurfaceTool).commit()
		mesh.material_override = material
		add_child(mesh)
		if listed is Dictionary:
			if not listed.has(island): listed[island] = []
			listed[island].append(mesh)
		rooms += 1
