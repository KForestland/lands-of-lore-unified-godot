extends SceneTree
## Owner r18 F10 14-55-28/14-55-48 at (-741,-4356) and 15-18-02 at (-4667,-459): a forest-floor slab and a dark beam hung in
## the sky. They were textured interior header spans between two open-sky regions (faces 9149, material 714, 107..147 and
## 10313, material 62, 127..147 of jungle_review/jungle.json). The Jungle host skips such spans (jungle_review.gd
## skip_sky_headers): foot on no floor, own region and the region beyond without a native ceiling face. Headers beside a
## region with a ceiling (face 8130, a hut front) and every span whose foot stands on a floor keep drawing.
const SLAB := 9149
const BEAM := 10313
const HUT_HEADER := 8130
const EXPECTED := 153

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL jungle sky headers: ", message)
	quit(1)

func run() -> void:
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Jungle not ready")
		return
	if not bool(scene.skip_sky_headers):
		fail("the Jungle host does not skip sky headers")
		return
	var skipped: Dictionary = scene.sky_header_faces
	if skipped.size() != EXPECTED:
		fail("%d sky headers skipped, expected %d" % [skipped.size(), EXPECTED])
		return
	if not skipped.has(SLAB) or not skipped.has(BEAM):
		fail("the owner's slab (face %d) or beam (face %d) is still drawn" % [SLAB, BEAM])
		return
	if skipped.has(HUT_HEADER):
		fail("header %d beside a ceiling region was skipped" % HUT_HEADER)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var span_start: int = int(data.interior_audit.span_start)
	var ceilinged := {}
	for face in data.faces:
		if face.kind == "ceiling": ceilinged[int(face.region)] = true
	for index in skipped:
		var face: Dictionary = data.faces[int(index)]
		if int(index) < span_start or face.kind != "wall" or not face.has("material") or ceilinged.has(int(face.region)):
			fail("face %d is not a textured interior span of an open-sky region" % int(index))
			return
	print("PASS jungle sky headers: %d textured headers between open-sky regions are not drawn (slab 9149, beam 10313); header 8130 beside a hut ceiling stays" % skipped.size())
	quit(0)
