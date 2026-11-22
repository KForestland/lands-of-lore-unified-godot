extends Node3D
## The one world change for the r16 stream gap (owner 2026-11-07). Region 2559 at
## (-4603,-3412) has a bed and no drawn surface. This is a draw-only sheet on that
## region only, using material 808 (the Jungle water texture). No skirts, no other region.
const REGION := 2559
const MATERIAL_ID := "808"
const UV_SCALE := 64.0

func build(host: Node3D) -> int:
	var liquid: Node = host.get("liquid_drowning")
	if liquid == null or not is_instance_valid(liquid): return 0
	var region := _region(liquid)
	if region.is_empty(): return 0
	var mats: Variant = host.get("materials")
	if not mats is Dictionary: return 0
	var source: Variant = (mats as Dictionary).get(MATERIAL_ID)
	if not source is StandardMaterial3D: return 0
	var real := source as StandardMaterial3D
	if real.albedo_texture == null: return 0
	var mat := real.duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var poly: PackedVector2Array = region.polygon
	if poly.size() < 3: return 0
	var y := float(region.surface)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(mat)
	var origin := Vector3(poly[0].x, y, poly[0].y)
	for i in range(1, poly.size() - 1):
		var b := Vector3(poly[i].x, y, poly[i].y)
		var c := Vector3(poly[i + 1].x, y, poly[i + 1].y)
		_vert(tool, origin)
		_vert(tool, b)
		_vert(tool, c)
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "WaterSurface2559"
	mesh.mesh = tool.commit()
	add_child(mesh)
	_cluster(host, mesh)
	return 1

func _vert(tool: SurfaceTool, point: Vector3) -> void:
	tool.set_uv(Vector2(point.x / UV_SCALE, point.z / UV_SCALE))
	tool.add_vertex(point)

func _region(liquid: Node) -> Dictionary:
	var rows: Array = liquid.get("regions")
	for item in rows:
		var row: Dictionary = item
		if int(row.get("id", -1)) == REGION: return row
	return {}

func _cluster(host: Node3D, mesh: MeshInstance3D) -> void:
	var clusters: Variant = host.get("region_cluster")
	var groups: Variant = host.get("cluster_meshes")
	if not clusters is Dictionary or not groups is Dictionary: return
	if not (clusters as Dictionary).has(REGION): return
	var cluster := int((clusters as Dictionary)[REGION])
	if cluster < 0: return
	if not (groups as Dictionary).has(cluster): (groups as Dictionary)[cluster] = []
	((groups as Dictionary)[cluster] as Array).append(mesh)
