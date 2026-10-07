extends Node3D
## Huline Jungle world-item rows 0, 50, 52–57 and 63–67 (tools/prepare_jungle_world_items.py). Row51 (dagger) is
## jungle_source_pickups.gd. Same E, 96-unit reach, 0.97 aim and mask-1 occlusion as the dagger/Hive wax pickups;
## each sprite is the original inventory image on a modern fixed-Y billboard. Each row is collected once: saved
## history quest_state.jungle_world_items.collected (rows), so trading or using an item never respawns it.
## Native pickup admission and item handlers are not replayed; no item use is enabled here.
const Catalog=preload("res://scripts/lol2/jungle_world_items_catalog.gd")
const ROOT:="res://assets/lol2/generated/jungle_world_items/"
const KEY:="jungle_world_items"
const REACH:=96.0
const AIM:=0.97
var host: Node3D
var sprites: Dictionary={}

static func assets_ready() -> bool: return FileAccess.file_exists(ROOT+"items.json")
static func initial() -> Dictionary: return {"version":1,"collected":[]}
static func validate(saved: Variant) -> String:
	if not saved is Dictionary or saved.size()!=2 or saved.get("version")!=1 or not saved.get("collected") is Array: return "Invalid Jungle world-item history."
	var seen: Array=[]
	for r in saved.collected:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r)!=floorf(float(r)) or int(r) not in Catalog.rows() or int(r) in seen: return "Invalid Jungle world-item row."
		seen.append(int(r))
	return ""

func _ready() -> void:
	host=get_parent()
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"items.json"))
	for row in catalog.items:
		assert(Catalog.id_of(int(row.row))==row.id and int(row.flags)==2)
		var image:=Image.load_from_file(str(row.icon))
		var sprite:=Sprite3D.new()
		sprite.texture=ImageTexture.create_from_image(image)
		sprite.pixel_size=0.5
		sprite.position=Vector3(float(row.position[0]),float(row.position[1]),float(row.position[2]))
		sprite.offset.y=image.get_height()/2.0
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(sprite)
		sprites[int(row.row)]=sprite
	restore()

## The saved history, or (when absent) a detached empty one: the quest key is written only once a row is
## actually collected or migrated, so saves without world items keep their exact quest state.
func history(create: bool=false) -> Dictionary:
	if validate(host.quest_state.get(KEY)).is_empty():
		# JSON loads rows as floats; keep them integral so membership/migration never duplicates a row.
		host.quest_state[KEY].collected=host.quest_state[KEY].collected.map(func(r):return int(r))
		return host.quest_state[KEY]
	if not create: return initial()
	host.quest_state[KEY]=initial()
	return host.quest_state[KEY]

func carried() -> Array:
	var pack=host.get("carried_collected")
	return pack if pack is Array else []

## Saved history decides presence; an already-carried row (older saves) is migrated into it.
func restore() -> void:
	var h:=history()
	for row in sprites:
		if Catalog.id_of(row) in carried() and row not in h.collected:
			h=history(true);h.collected.append(row)
		sprites[row].visible=row not in h.collected.map(func(r):return int(r))

func aim_point(row: int) -> Vector3:
	var sprite: Sprite3D=sprites[row]
	return sprite.global_position+Vector3(0,sprite.texture.get_height()*sprite.pixel_size/2.0,0)

## The aimed, visible, unobstructed row within reach (closest to the view centre), or -1.
func target() -> int:
	if host.flying or get_tree().paused or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED or _overlay_blocks(): return -1
	var best:=-1;var best_dot:=AIM
	for row in sprites:
		if not sprites[row].visible: continue
		var delta: Vector3=aim_point(row)-host.camera.global_position
		if delta.length()<0.01 or delta.length()>REACH: continue
		var dot: float=(-host.camera.global_basis.z).dot(delta.normalized())
		if dot<best_dot: continue
		var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,aim_point(row),1,[host.player.get_rid()])
		query.hit_from_inside=true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		best=row;best_dot=dot
	return best

func collect() -> bool:
	if not host.get("carried_collected") is Array: return false
	var row:=target()
	if row<0: return false
	var id:=Catalog.id_of(row)
	if id in host.carried_collected: restore();return false
	host.carried_collected.append(id)
	history(true).collected.append(row)
	restore()
	if host.has_method("save_feedback"): host.save_feedback(str(Catalog.ITEMS[id].label)+" taken.")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and collect():
		get_viewport().set_input_as_handled()

func _overlay_blocks() -> bool:
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return true
	var hud=host.get("interface_hud")
	if hud!=null and is_instance_valid(hud) and hud.cursor_active: return true
	var inventory=host.get("inventory")
	if inventory!=null and is_instance_valid(inventory): return true
	for name in ["departure","monastery","magic_shop","weapon_shop","village_dialogue","followup_dialogue"]:
		var room=host.get(name)
		if room!=null and is_instance_valid(room) and room.has_method("active") and room.active(): return true
	return false
