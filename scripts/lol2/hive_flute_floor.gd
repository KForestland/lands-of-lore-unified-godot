extends Node3D
## HIVE-FLUTE-FLOOR (owner-reported Act 1 gap, 2026-11-02). Hive L5_HC storey below lift stop -1579: the iron flute put
## into the slanted slot (control 122, template 28 "Flute Grabber", region 792) slides the four green Pit Covers (movables
## 68-71, template 25, regions 904-906) out of their wall pocket over the oily floor (Puddle controls 53-58; oil floors
## 479-489, height -1674), so the player crosses on green tiles. Prima p.78 "slide the flute into the slot to give yourself
## safer footing", p.81 "place the iron flute in the slot. The latter trick slides a green tile floor into place"; Brady
## p.160 "Use the Flute to move a section of floor over the oil pool", p.170 "place the Flute in a receptacle, closing a
## floor over an open pool of oil"; Brady OCR p-082 "the outline of a flute in the wall to the right of the oil trap
## corridor ... A panel closes over the floor". Prima ch.12 (Huline Temple) "Insert the flute to cover the oil": the flute
## is still carried later (and summons the lift), so here it can be taken back out; the floor stays.
## Located by hive_flute_floor_frame.md (AI_COMMS/review_20261102). The native commands were not decoded: known behaviour
## built modern; the slide distance/motion and the commit trigger are the logged adapter (DEVIATIONS piece 0206).
## The flute goes through the mechanism transaction API (offer/occupy/commit/retrieve/refuse); saved as
## quests.hive_flute_floor {version, slot}. Load restores the slot mode and the slid covers from "committed" without
## replaying the commit. Before the commit the oil keeps its existing behaviour (a plain walkable floor; no hazard hosted).
const M := preload("res://scripts/lol2/mechanism_transaction.gd")
const FLUTE := preload("res://scripts/lol2/monastery_conversation.gd").FLUTE
const KEY := "hive_flute_floor"
const TARGET := "hive:flute_slot"
const EVENT := "hive_flute_floor_slid"
## Retrievable (the flute summons the lift and is used again in the Huline Temple); not repeatable (the floor stays).
## Forms as the kit's flute-slot recipe: the lizard does not handle items.
const RECIPE := {"target": TARGET, "accepts": [FLUTE], "output": "", "retrievable": true, "repeatable": false, "forms": ["human", "beast"]}
const FORMS := ["human", "beast", "lizard"]
const SLOT_CONTROL := 122
const SLOT_POINT := Vector3(-1834.5, -1617.0, -6456.5)  ## centre of control 122's slot faces (static assemblies pack)
const REACH := 110.0
## Movables 68-71 (lol2_out/all_maps_20260922/L5_HC/movables/movables.json): square plates turned 45 degrees, corner
## 91 units from the centre, from -1664 (underside, material 234) to -1654 (green tiles, material 231), sides 236.
const COVERS := {68: Vector2(-2233, -6131), 69: Vector2(-2140, -6227), 71: Vector2(-2045, -6320), 70: Vector2(-1952, -6416)}
const HALF_DIAGONAL := 91.0
const BOTTOM := -1664.0
const TOP := -1654.0
## ADAPTER: each plate slides one plate width out of the pocket (regions 904-906) along the pocket's normal, so it ends
## against the far wall of the oil channel (floors 479-489). Motion is a linear presentation slide; collision and state
## take the end position at once.
const SLIDE := Vector3(91.0, 0.0, 91.0)
const SLIDE_SECONDS := 1.5
const OIL_REGIONS := [479, 480, 481, 482, 483, 485, 486, 487, 488, 489]
const FOOT_OFFSET := 32.0

var host: Node3D
var state: Dictionary = initial()
var plates := {}        # id -> Node3D (meshes)
var bodies := {}        # id -> StaticBody3D (walkable box)
var slot_body: StaticBody3D
var slide_progress := 1.0

## Spark ("fire") on the slot: refused, nothing changes.
class SlotReceiver extends RefCounted:
	var owner
	func receive_spark() -> bool: return owner.refuse_fire()

static func initial() -> Dictionary:
	return {"version": 1, "slot": {"occupied": "", "committed": false, "receipts": []}}

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or value.get("version") != 1 or not value.get("slot") is Dictionary: return "Invalid Hive flute floor state."
	var snapshot := M.empty_snapshot()
	snapshot.slots[TARGET] = value.slot
	var error := M.validate(snapshot)
	if not error.is_empty(): return "Invalid Hive flute floor state: " + error
	var slot: Dictionary = value.slot
	if slot.size() != 3 or not slot.occupied in ["", FLUTE]: return "Invalid Hive flute floor slot."
	if slot.committed != (slot.receipts == [EVENT]) or (not slot.committed and not slot.receipts.is_empty()): return "Invalid Hive flute floor history."
	if slot.occupied == FLUTE and not slot.committed: return "An inserted flute has always slid the floor."
	return ""

static func canonical(value: Dictionary) -> Dictionary:
	return {"version": 1, "slot": {"occupied": str(value.slot.occupied), "committed": bool(value.slot.committed), "receipts": value.slot.receipts.duplicate()}}

## The flute is either carried or in the slot, never both (no duplicate through a forged or stale handoff).
static func transport_error(inventory: Dictionary, quests: Dictionary) -> String:
	var value: Variant = quests.get(KEY)
	if value == null: return ""
	var error := validate(value)
	if not error.is_empty(): return error
	if value.slot.occupied == FLUTE and FLUTE in inventory.get("collected", []): return "The iron flute cannot be both in the Hive slot and carried."
	return ""

func checkpoint() -> Dictionary: return state.duplicate(true)
func committed() -> bool: return bool(state.slot.committed)
func occupied() -> bool: return state.slot.occupied == FLUTE

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "HiveFluteFloor"
	host = owner
	for id in COVERS:
		var plate := Node3D.new()
		plate.name = "PitCover%d" % id
		var mesh := MeshInstance3D.new()
		mesh.mesh = _plate_mesh(COVERS[id])
		plate.add_child(mesh)
		add_child(plate)
		plates[id] = plate
		var body := StaticBody3D.new()
		body.name = "PitCoverBody%d" % id
		var shape := CollisionShape3D.new()
		var hull := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for corner in _corners(COVERS[id]):
			points.append(Vector3(corner.x, BOTTOM, corner.y)); points.append(Vector3(corner.x, TOP, corner.y))
		hull.points = points
		shape.shape = hull
		body.add_child(shape)
		add_child(body)
		bodies[id] = body
	# Hit-only body for the Spark ray (layers 4|8 like the Reaver pillars); the player does not collide with it.
	slot_body = StaticBody3D.new()
	slot_body.name = "FluteSlotHit"
	slot_body.collision_layer = 4 | 8
	slot_body.collision_mask = 0
	var slot_shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(12, 20, 12)
	slot_shape.shape = box
	slot_body.add_child(slot_shape)
	slot_body.position = SLOT_POINT
	var receiver := SlotReceiver.new(); receiver.owner = self
	slot_body.set_meta("spark_receiver", receiver)
	slot_body.set_meta("hive_flute_slot", true)
	add_child(slot_body)
	return restore(saved)

## Load path: state from the save, world from "committed"/"occupied" (no commit replay, no slide animation).
func restore(saved: Variant) -> String:
	var value: Variant = initial() if saved == null else saved
	var error := validate(value)
	if not error.is_empty(): return error
	state = canonical(value)
	slide_progress = 1.0
	present()
	return ""

static func _corners(centre: Vector2) -> Array:
	return [centre + Vector2(HALF_DIAGONAL, 0), centre + Vector2(0, -HALF_DIAGONAL), centre + Vector2(-HALF_DIAGONAL, 0), centre + Vector2(0, HALF_DIAGONAL)]

func _material(key: String) -> Material:
	var host_materials: Variant = host.get("materials")
	if host_materials is Dictionary and (host_materials as Dictionary).has(key): return host_materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var path := "res://assets/lol2/generated/hive_review/material_%s.png" % key
	if FileAccess.file_exists(path): m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(path))
	else: m.albedo_color = Color(0.35, 0.42, 0.25)
	return m

func _plate_mesh(centre: Vector2) -> ArrayMesh:
	var c: Array = _corners(centre)
	var mesh := ArrayMesh.new()
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for cap in [[TOP, "231"], [BOTTOM, "234"]]:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(_material(cap[1]))
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[i]); st.add_vertex(Vector3(c[i].x, cap[0], c[i].y))
		st.generate_normals(); st.commit(mesh)
	var side := SurfaceTool.new(); side.begin(Mesh.PRIMITIVE_TRIANGLES); side.set_material(_material("236"))
	for i in 4:
		var a: Vector2 = c[i]; var b: Vector2 = c[(i + 1) % 4]
		var quad := [Vector3(a.x, BOTTOM, a.y), Vector3(b.x, BOTTOM, b.y), Vector3(b.x, TOP, b.y), Vector3(a.x, TOP, a.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			side.set_uv(uv[k] * Vector2(1.0, 10.0 / 64.0)); side.add_vertex(quad[k])
	side.generate_normals(); side.commit(mesh)
	return mesh

func present() -> void:
	var assemblies: Variant = host.get("static_assemblies")
	if assemblies != null and is_instance_valid(assemblies): assemblies.set_mode(SLOT_CONTROL, 1 if occupied() else 0)
	var end := SLIDE if committed() else Vector3.ZERO
	for id in plates:
		plates[id].position = end * (slide_progress if committed() else 1.0)
		bodies[id].position = end

## Where the plates are now (state, not animation): the slid end position once committed.
func cover_offset() -> Vector3: return SLIDE if committed() else Vector3.ZERO

func _physics_process(delta: float) -> void:
	if slide_progress >= 1.0: return
	slide_progress = minf(1.0, slide_progress + delta / SLIDE_SECONDS)
	present()

# --- Interaction -----------------------------------------------------------------------------------------------------

func _active() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.get("flying") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	if host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.get("cursor_active"): return false
	if host.has_node("Warriors") and host.get_node("Warriors").health == 0: return false
	return true

## The slot is aimed at and in reach (geometry only; the inventory's Use button asks this while the cursor is free).
func in_reach() -> bool:
	if not is_instance_valid(host) or not is_inside_tree(): return false
	var offset: Vector3 = SLOT_POINT - host.camera.global_position
	if offset.length() < 0.01 or offset.length() > REACH: return false
	if (-host.camera.global_basis.z).dot(offset.normalized()) < 0.95: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, SLOT_POINT, 1, [host.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or (hit.position as Vector3).distance_to(SLOT_POINT) < 12.0

func _context() -> Dictionary:
	var form := int(host.get("player_form")) if host.get("player_form") != null else 0
	return {"in_reach": in_reach(), "form": FORMS[clampi(form, 0, FORMS.size() - 1)]}

func _snapshot() -> Dictionary:
	var snapshot := M.empty_snapshot(host.carried_inventory.collected, preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED)
	snapshot.slots[TARGET] = state.slot.duplicate(true)
	return snapshot

## Accept a transaction result: the carried list is updated in place (other owners hold the same array).
func _apply(snapshot: Dictionary) -> void:
	var collected: Array = host.carried_inventory.collected
	collected.assign(snapshot.inventory)
	state = canonical({"slot": M.slot(snapshot, TARGET)})

func _feedback(text: String) -> void:
	if not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 2.5

## Offer one carried item to the slot. Returns the API result ({"ok": ...}); a refusal changes nothing.
func offer_item(id: String) -> Dictionary:
	var snapshot := _snapshot()
	var proposal := M.offer(snapshot, RECIPE, id, _context())
	if not proposal.ok:
		_feedback("You cannot reach the slot." if not in_reach() else "That does not fit the slot." if id != FLUTE else "Nothing happens.")
		return proposal
	var result := M.occupy(snapshot, proposal.proposal)
	if not result.ok:
		_feedback("Nothing happens.")
		return result
	var first: bool = not M.slot(result.snapshot, TARGET).committed
	if first:
		var done := M.commit(result.snapshot, RECIPE, EVENT)
		if not done.ok: return done
		result = done
	_apply(result.snapshot)
	if first:
		slide_progress = 0.0
		_lift_player()
		_feedback("The flute slides into the slot. A green tile floor slides over the oil.")
	else: _feedback("The flute slides into the slot.")
	present()
	return result

func retrieve() -> Dictionary:
	var result := M.retrieve(_snapshot(), RECIPE)
	if not result.ok:
		_feedback("You cannot carry more." if occupied() else "Nothing happens.")
		return result
	_apply(result.snapshot)
	_feedback("Iron flute taken back.")
	present()
	return result

func refuse_fire() -> bool:
	M.refuse("fire does not fit %s" % TARGET)
	_feedback("Nothing happens.")
	return true

## A player standing on the oil when the plates come out ends up on top of them (no clipping into the new floor).
func _lift_player() -> void:
	var feet: float = host.player.global_position.y - FOOT_OFFSET
	if feet >= TOP: return
	var p := Vector2(host.player.global_position.x, host.player.global_position.z)
	for id in COVERS:
		var polygon := PackedVector2Array()
		for corner in _corners(COVERS[id]): polygon.append(corner + Vector2(SLIDE.x, SLIDE.z))
		if Geometry2D.is_point_in_polygon(p, polygon):
			host.player.global_position.y = TOP + FOOT_OFFSET
			return

## E at the aimed slot: put the flute in, or take it back out.
func use() -> bool:
	if not _active() or not in_reach(): return false
	if occupied(): retrieve()
	elif FLUTE in host.carried_inventory.collected: offer_item(FLUTE)
	else: _feedback("An empty, slanted slot.")
	return true

func interaction_hint() -> String:
	if not _active() or not in_reach(): return ""
	if occupied(): return "E — Take the iron flute"
	if FLUTE in host.carried_inventory.collected: return "E — Put the iron flute in the slot"
	return ""

func _process(_delta: float) -> void:
	var text := interaction_hint()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")) or host.interface_hud.save_notice_remaining > 0.2: return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2
