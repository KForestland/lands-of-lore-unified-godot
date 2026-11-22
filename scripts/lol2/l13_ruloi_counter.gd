extends CanvasLayer
## Ruloi Stronghold (L13): the original HUD's "Remaining Ruloi N/19" line (Ruloi = actors 21-39; the maidens and the
## web wait for all of them, l13_prison.gd all_ruloi_dead). Lead 2026-11-16: a small HUD line in the HUD's own style,
## shown while any Ruloi lives. Read only: it counts the same creature state the prison gate reads (an actor with no
## state yet counts as alive, as the gate does) and writes nothing. Created by l13_prison.gd.
const FIRST := 21
const LAST := 39
const TOTAL := LAST - FIRST + 1
var host: Node3D
var line: Label

static func attach(owner: Node, map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l13_ruloi_counter.gd").new()
	n.host = map; n.name = "L13RuloiCounter"; owner.add_child(n); return n

func _ready() -> void:
	layer = 21 # just above the HUD (museum_interface layer 20)
	line = Label.new()
	line.theme = preload("res://scripts/lol2/museum_ui_theme.gd").create()
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	line.offset_left = -360; line.offset_right = -16; line.offset_top = 40; line.offset_bottom = 72
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_theme_color_override("font_shadow_color", Color.BLACK)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.visible = false
	add_child(line)

static func remaining(actors: Dictionary) -> int:
	var living := 0
	for n in range(FIRST, LAST + 1):
		if float(actors.get(str(n), {}).get("health", 1)) > 0: living += 1
	return living

func text() -> String:
	return line.text if line.visible else ""

func _process(_delta: float) -> void:
	var hud: Variant = host.get("interface_hud") if host != null else null
	var creatures: Variant = host.get("act2_creatures") if host != null else null
	if not is_instance_valid(hud) or not hud.visible or not is_instance_valid(creatures):
		line.visible = false; return
	var living := remaining(creatures.state.get("actors", {}))
	line.visible = living > 0
	line.text = "Remaining Ruloi %d/%d" % [living, TOTAL]
	if is_instance_valid(hud.hint):
		line.add_theme_font_size_override("font_size", hud.hint.get_theme_font_size("font_size"))
