extends SceneTree
## Owner r12l F10 2026-10-28 15:30:39: Dawn stood about 3 m tall (73 units against the player's 46). Her body figure and
## her talk clips must both come out about the player's height, on the same pixel size.
const JungleDawn=preload("res://scripts/lol2/jungle_dawn.gd")
const HiveDawn=preload("res://scripts/lol2/hive_dawn20.gd")
const PLAYER_HEIGHT:=46.0
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: run.call_deferred()
## Opaque rows of the definition's first idle frame (L8 indices; 0 = transparent).
func figure_rows(root: String, definition: String) -> int:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root+"sprites.json"))
	var resource:=int(manifest.definitions[definition].states[0].views[0].frames[0])
	var file:=""
	for row in manifest.frames:
		if int(row.resource)==resource: file=str(row.file)
	var image:=Image.load_from_file(root+file)
	var top:=-1;var bottom:=-1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).r>0.0:
				if top<0: top=y
				bottom=y;break
	return bottom-top+1
func run() -> void:
	for pair in [[JungleDawn,"8","Jungle"],[HiveDawn,"3","Hive"]]:
		var config: Dictionary=pair[0].POP_CONFIG
		var look: Dictionary=config.look[pair[1]]
		var image_width:=640.0
		var unit_per_pixel: float=float(look.canvas[0])*float(look.scale)/image_width
		var height: float=figure_rows(str(config.root),pair[1])*unit_per_pixel
		check(height>=PLAYER_HEIGHT*0.85 and height<=PLAYER_HEIGHT*1.1,"%s Dawn body is about player height (%.1f units)" % [pair[2],height])
		check(is_equal_approx(float(pair[0].CLIP_SCALE),unit_per_pixel),"%s Dawn talk clips use the body's pixel size" % pair[2])
	if failures:
		push_error("FAIL: %d Dawn scale checks" % failures);quit(1);return
	print("PASS Dawn body scale: about player height in the Jungle and the Hive, talk clips on the same pixel size")
	quit()
