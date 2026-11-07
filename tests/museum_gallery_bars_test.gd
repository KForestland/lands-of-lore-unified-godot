extends SceneTree
## grok J02. Grate 51 bars use resource 431 on the sides and 433 on the caps. Bars 62 and 78 stay off the moving grate.
const Gallery = preload("res://scripts/lol2/museum_gallery.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var gallery = Gallery.new()
	root.add_child(gallery)
	await process_frame
	var bars := 0
	for child in gallery.grate.get_children():
		if child is MeshInstance3D: bars += 1
	check(bars == 14, "fourteen grate bars")
	var bar: MeshInstance3D = gallery.grate.get_node("MuseumGrateBar0")
	check(bar.mesh.get_surface_count() == 2, "sides and caps are two surfaces")
	check(bar.material_override == null, "no single override hides the cap")
	var side = bar.mesh.surface_get_material(0)
	var cap = bar.mesh.surface_get_material(1)
	check(side != null and cap != null and side != cap, "431 and 433 are different materials")
	check(side.albedo_texture != null and cap.albedo_texture != null, "both bar textures load")
	check(gallery.grate.get_node("MuseumGrateBar13").mesh == bar.mesh, "the grate shares one bar mesh")
	var left: MeshInstance3D = gallery.get_node("MuseumBar62")
	var right: MeshInstance3D = gallery.get_node("MuseumBar78")
	check(left.mesh == bar.mesh and right.mesh == bar.mesh, "movables 62 and 78 use the same mesh")
	check(left.get_parent() == gallery and right.get_parent() == gallery, "62 and 78 are not children of the moving grate")
	check(left.position == Vector3(1050, 60, -948) and right.position == Vector3(1206, 60, -949), "static bar positions")
	check(gallery.lever.material_override.albedo_color.is_equal_approx(Color(0.52, 0.43, 0.27)), "the lever colour stays")
	if failures == 0: print("PASS museum_gallery_bars_test: 431 sides, 433 caps, static bars 62 and 78")
	quit(1 if failures else 0)
