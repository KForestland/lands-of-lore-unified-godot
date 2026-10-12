extends Node
## Native potential-sector membership with conservative modern camera lookup.
@export var regions: Array[Dictionary] = []
@export var potential_sectors: Array = []
@export var mask: ImageTexture
var camera_override: Camera3D
var active_sector := -2
var previous_region := -1
var cells: Dictionary = {}
var image: Image
const CELL_SIZE := 512.0

func _ready() -> void:
	initialize()

func initialize() -> void:
	cells.clear()
	previous_region = -1
	active_sector = -2
	if mask == null or potential_sectors.is_empty(): return
	image = mask.get_image()
	for i in regions.size():
		var region := regions[i]
		var polygon := PackedVector2Array()
		for p in region.polygon: polygon.append(Vector2(float(p[0]), float(p[1])))
		region["points"] = polygon
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for p in polygon: bounds = bounds.expand(p)
		for x in range(floori(bounds.position.x / CELL_SIZE), floori(bounds.end.x / CELL_SIZE) + 1):
			for y in range(floori(bounds.position.y / CELL_SIZE), floori(bounds.end.y / CELL_SIZE) + 1):
				var key := Vector2i(x,y)
				if not cells.has(key): cells[key] = []
				cells[key].append(i)
	set_sector(-1)

func _process(_delta: float) -> void:
	if mask == null: return
	var camera := camera_override if is_instance_valid(camera_override) else get_viewport().get_camera_3d()
	if camera == null: return
	var position := camera.global_position
	if get_parent() is Node3D: position = (get_parent() as Node3D).to_local(position)
	set_sector(sector_at(position))

func sector_at(position: Vector3) -> int:
	var point := Vector2(position.x, position.z)
	if previous_region >= 0 and contains(regions[previous_region], point, position.y):
		return int(regions[previous_region].sector)
	var found := -1
	for i in cells.get(Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE)), []):
		if not contains(regions[i], point, position.y): continue
		if found >= 0 and regions[found].sector != regions[i].sector:
			previous_region = -1
			return -1 # Ambiguous overlapping spaces: retain geometry.
		found = i
	previous_region = found
	return -1 if found < 0 else int(regions[found].sector)

static func contains(region: Dictionary, p: Vector2, height: float) -> bool:
	var polygon: PackedVector2Array = region.points
	if not Geometry2D.is_point_in_polygon(p, polygon): return false
	for i in range(1,polygon.size()-1):
		var a := polygon[0]
		var b := polygon[i]
		var c := polygon[i+1]
		var denominator := (b-a).cross(c-a)
		if absf(denominator) < 0.000001: continue
		var u := (p-a).cross(c-a) / denominator
		var v := (b-a).cross(p-a) / denominator
		if u < -0.00001 or v < -0.00001 or u+v > 1.00001: continue
		var floor_height := float(region.floor[0])*(1-u-v)+float(region.floor[i])*u+float(region.floor[i+1])*v
		var ceiling_height := float(region.ceiling[0])*(1-u-v)+float(region.ceiling[i])*u+float(region.ceiling[i+1])*v
		return height >= floor_height-0.05 and height <= ceiling_height+0.05 and ceiling_height > floor_height
	return false

func set_sector(sector: int) -> void:
	if sector == active_sector or image == null: return
	active_sector = sector
	image.fill(Color.WHITE if sector < 0 else Color.BLACK)
	if sector >= 0:
		for admitted in potential_sectors[sector]: image.set_pixel(int(admitted),0,Color.WHITE)
	mask.update(image)
