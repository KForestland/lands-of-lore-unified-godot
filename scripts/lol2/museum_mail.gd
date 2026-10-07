extends Sprite3D
## Original item10 graphic/anchor; bottom pivot and billboard are authored.
const ROOT := "res://assets/lol2/generated/museum_mail/"
func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "item.json"))
	var image := Image.load_from_file(ROOT + "mail.png")
	texture = ImageTexture.create_from_image(image)
	position = Vector3(data.position[0],data.position[1],data.position[2])
	pixel_size = 0.5
	offset.y = image.get_height() / 2.0
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
