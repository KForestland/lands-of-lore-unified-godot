extends SceneTree
## Regression for the VQA v2 partial-codebook decode (tools/vqa_v2_decode.py): staged frames from codebook groups that
## FFmpeg mis-decoded must not contain interior key-colour holes. Interior holes = transparent pixels with opaque
## pixels 3 columns left and right. FFmpeg-staged media scored 250–530 on these frames; the Python decoder (tools/vqa_v2_decode.py) scores < 60.
## Frames whose holes are genuine source dissolves (identical in both decoders) are deliberately not pinned.
const LIMIT:=120
const CASES:=[
	["res://assets/lol2/generated/jungle_dawn_media/media.json",["clip"],[64,71,380,872,875]],
	["res://assets/lol2/generated/jungle_bacatta_media/media.json",["clips","prop552","1"],[24,25,26,27,28,29,30,31,72]],
	["res://assets/lol2/generated/hive_dawn20_media/media.json",["clip"],[64,67,71,568,960]]]
func _initialize() -> void:
	var checked:=0
	for c in CASES:
		if not FileAccess.file_exists(c[0]): push_error("Missing staged media "+c[0]);quit(1);return
		var node=JSON.parse_string(FileAccess.get_file_as_string(c[0]))
		for key in c[1]: node=node[key]
		for i in c[2]:
			var path:=str(node.frame_files[i])
			var img:=Image.load_from_file(path)
			var holes:=0
			for y in img.get_height():
				for x in range(3,img.get_width()-3):
					if img.get_pixel(x,y).a<0.5 and img.get_pixel(x-3,y).a>=0.5 and img.get_pixel(x+3,y).a>=0.5: holes+=1
			if holes>LIMIT:
				push_error("Partial-codebook frame decoded with holes: %s (%d)"%[path,holes]);quit(1);return
			checked+=1
	print("PASS vqa partial codebook media: %d previously mis-decoded frames (Dawn63 E065E, Bacatta BC07, Dawn20 E075E) have no interior key holes."%checked)
	quit()
