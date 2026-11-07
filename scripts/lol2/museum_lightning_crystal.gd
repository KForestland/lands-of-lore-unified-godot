extends Node3D
## Source item row7 "56a-Ltng cr" behind the rubble-room blocks (region1010). E/range and inventory are modern;
## the item's handler 8 (use) is not replayed.
const ROOT := "res://assets/lol2/generated/museum_lightning_crystal/"
const ID := "museum:item7:Lightning_Crystal"
var host: Node3D
var sprite: Sprite3D
static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT + "items.json") and FileAccess.file_exists(ROOT + "crystal.png")
func setup(owner: Node3D) -> void:
	host = owner
	name = "MuseumLightningCrystal"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "items.json"))
	var item: Dictionary = data.items[0]
	var image := Image.load_from_file(ROOT + "crystal.png")
	sprite = Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = 0.5
	sprite.position = Vector3(item.position[0], item.position[1], item.position[2])
	sprite.offset.y = image.get_height() / 2.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sprite)
func restore_collected(ids: Array) -> void:
	if is_instance_valid(sprite): sprite.visible = not ID in ids
func can_take() -> bool:
	return is_instance_valid(sprite) and sprite.visible and not ID in host.carried_collected and host.can_reach_item(sprite.global_position + Vector3(0, 3, 0))
func interaction_hint() -> String:
	return "E — Take Lightning crystal" if can_take() else ""
func use() -> bool:
	if not can_take(): return false
	host.carried_collected.append(ID)
	sprite.hide()
	host.save_feedback("Lightning crystal added to inventory.")
	return true
