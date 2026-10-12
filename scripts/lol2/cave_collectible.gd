extends RefCounted

# Original record/artwork; collection behaviour and item name are provisional.
const RECORD := 1108
const ID := "draracle/prop/1108/sample"
const REACH := 96.0
const AIM_DOT := 0.97
var mesh: MeshInstance3D
var collected := false

func target_position() -> Vector3:
	return mesh.to_global(mesh.mesh.center_offset)

func can_collect(camera: Camera3D, player: CharacterBody3D) -> bool:
	if mesh == null or collected or not mesh.is_visible_in_tree():
		return false
	var delta := target_position() - camera.global_position
	if delta.length() < 0.01 or delta.length() > REACH:
		return false
	if (-camera.global_basis.z).dot(delta.normalized()) < AIM_DOT:
		return false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target_position(), 1, [player.get_rid()])
	ray.hit_from_inside = true
	return camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func saved_ids() -> Array:
	return [ID] if collected else []

func restore(ids: Array) -> void:
	collected = ID in ids
	if mesh != null:
		mesh.visible = not collected

static func validate_ids(ids: Variant) -> bool:
	# One prototype object. Expand the explicit catalog with future objects.
	return ids is Array and (ids.is_empty() or (ids.size() == 1 and ids[0] is String and ids[0] == ID))
