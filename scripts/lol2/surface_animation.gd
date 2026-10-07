extends Node
## Source image sequences at explicit restoration-owned playback rates.
var sequences: Array = []
func configure(materials: Dictionary, definitions: Dictionary, root_path: String) -> void:
	for key in definitions:
		if not materials.has(key): continue
		var definition: Dictionary = definitions[key]
		var frames: Array[ImageTexture] = []
		for file in definition.frames:
			frames.append(ImageTexture.create_from_image(Image.load_from_file(root_path + file)))
		if frames.is_empty(): continue
		materials[key].albedo_texture = frames[0]
		sequences.append({"material":materials[key],"frames":frames,"fps":float(definition.fps),"elapsed":0.0,"frame":0})
func _process(delta: float) -> void:
	advance(delta)
func advance(delta: float) -> void:
	for sequence in sequences:
		sequence.elapsed = fposmod(sequence.elapsed + maxf(delta,0),sequence.frames.size() / sequence.fps)
		var frame: int = int(sequence.elapsed * sequence.fps) % sequence.frames.size()
		if frame != sequence.frame:
			sequence.frame = frame
			sequence.material.albedo_texture = sequence.frames[frame]
