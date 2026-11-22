extends Node
## Source image sequences at explicit restoration-owned playback rates.
var sequences: Array = []
func configure(materials: Dictionary, definitions: Dictionary, root_path: String) -> void:
	for key in definitions:
		# A key may also have a second copy ("KEY|wall" or "KEY|both", jungle_review one-sided walls): all animate together.
		var targets: Array = []
		for name in [key, str(key) + "|wall", str(key) + "|both"]:
			if materials.has(name): targets.append(materials[name])
		if targets.is_empty(): continue
		var definition: Dictionary = definitions[key]
		var frames: Array[ImageTexture] = []
		for file in definition.frames:
			frames.append(ImageTexture.create_from_image(Image.load_from_file(root_path + file)))
		if frames.is_empty(): continue
		for material in targets:
			material.albedo_texture = frames[0]
			sequences.append({"material":material,"frames":frames,"fps":float(definition.fps),"elapsed":0.0,"frame":0})
func _process(delta: float) -> void:
	advance(delta)
func advance(delta: float) -> void:
	for sequence in sequences:
		sequence.elapsed = fposmod(sequence.elapsed + maxf(delta,0),sequence.frames.size() / sequence.fps)
		var frame: int = int(sequence.elapsed * sequence.fps) % sequence.frames.size()
		if frame != sequence.frame:
			sequence.frame = frame
			sequence.material.albedo_texture = sequence.frames[frame]
