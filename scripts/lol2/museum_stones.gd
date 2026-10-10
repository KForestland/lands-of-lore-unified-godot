extends Node3D
## Two distinct source placements; shared original artwork and authored pivot.
const ROOT := "res://assets/lol2/generated/museum_stones/"
const IDS := ["museum:item8:Champion_Stone", "museum:item9:Champion_Stone"]
var sprites: Array[Sprite3D] = []
func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "items.json"))
	var image := Image.load_from_file(ROOT + "stone.png")
	var texture := ImageTexture.create_from_image(image)
	for item in data.items:
		var sprite := Sprite3D.new()
		sprite.texture = texture
		sprite.pixel_size = 0.5
		sprite.position = Vector3(item.position[0],item.position[1],item.position[2])
		sprite.offset.y = image.get_height() / 2.0
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(sprite)
		sprites.append(sprite)
func restore_collected(ids: Array) -> void:
	for index in sprites.size(): sprites[index].visible = not IDS[index] in ids
