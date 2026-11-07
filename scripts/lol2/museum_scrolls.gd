extends Node3D
const State = preload("res://scripts/lol2/museum_scroll_state.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Definitions = preload("res://scripts/lol2/item_definitions.gd")
var host: Node3D
var state := State.initial()
var pickups: Array[Sprite3D] = []
static func assets_ready() -> bool:
	for index in State.DEFINITIONS:
		if not FileAccess.file_exists(Definitions.icon(index)): return false
	return true
func setup(owner: Node3D, saved: Variant = null) -> String:
	host=owner
	name="MuseumScrolls"
	for i in 5:
		var texture := ImageTexture.create_from_image(Image.load_from_file(Definitions.icon(State.DEFINITIONS[i])))
		var sprite := Sprite3D.new()
		sprite.texture=texture
		# Same world-sprite half-pixel adapter as Museum crystal:31x16 pixels =>15.5x8 units.
		sprite.pixel_size=0.5
		sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.position=State.POSITIONS[i]+Vector3.UP*texture.get_height()*0.25
		add_child(sprite)
		pickups.append(sprite)
	return restore_checkpoint(saved)
func checkpoint() -> Dictionary: return state.duplicate(true)
func restore_checkpoint(saved: Variant) -> String:
	var error := State.validate(saved,host.carried_collected)
	if not error.is_empty(): return error
	state=State.canonical(saved)
	present()
	return ""
func present() -> void:
	for i in 5: pickups[i].visible=not state.taken[i]
func offered() -> int:
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active() or host.hand_item!="": return -1
	var result := -1
	var nearest := INF
	for i in 5:
		if not pickups[i].visible or not host.can_reach_sprite(pickups[i],pickups[i].global_position): continue
		var distance: float = host.camera.global_position.distance_squared_to(pickups[i].global_position)
		if distance<nearest:
			nearest=distance
			result=i
	return result
func use() -> bool:
	var i := offered()
	if i<0: return false
	if host.carried_collected.size()>=Catalog.MAX_CARRIED:
		host.save_feedback("You cannot carry more.")
		return true
	if not State.take(state,host.carried_collected,i): return false
	present()
	host.save_feedback(Catalog.entry(State.IDS[i]).label+" added to inventory.")
	return true
func interaction_hint() -> String:
	var i := offered()
	return "E — Take "+str(Catalog.entry(State.IDS[i]).label) if i>=0 else ""
