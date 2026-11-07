extends CanvasLayer
## One top-left target/fall line per area host (owner F10 2026-11-03 17:57:47, PT3-UI-FALL-TEXT-OVERLAP).
## Before: every creature population (scripted_creature_population.gd, jungle_dino_population.gd) drew its own Label at
## (16,48). A population whose processing its owner switches off (Dawn and Kelsrick while they talk, a friendly Bacatta)
## kept its last aim text on screen ("Dawn 100/200"), and the fall prompt the other populations wrote was drawn on top of
## it at the same spot: unreadable. Populations now keep their own label hidden, as the text model their owners and tests
## read, and attach it here; this node draws a single line: the fall prompt while the player is down (it wins over any
## aim text), otherwise the first non-empty text of a population that is processing this frame (a stale text is never
## shown). An area whose own owner already draws a prompt at that spot (the Hive guardians' "Defeated · F9: load or R:
## retry guardians" and their target line, hive_warriors.gd) registers that label with yield_to(): while it shows text
## over this line, this line stays empty. Presentation only (docs/DEVIATIONS.md).
const FELL:="You fell · R: recover here · F9: load save"
const META:="lol2_target_status"
var host: Node
## [[population, its hidden label], ...] in attach order.
var sources: Array=[]
## Visible labels of other owners this line gives way to when both would be drawn over each other.
var blockers: Array=[]
var label: Label

## Called by a population at setup: hides its own label and draws it through the host's single line.
static func attach(owner_host: Node, population: Node, text: Label) -> void:
	text.visible=false
	var node=of(owner_host)
	if node!=null: node.sources.append([population,text])

## Called by an owner that draws its own prompt at this spot: this line yields while that label shows text over it.
static func yield_to(owner_host: Node, text: Label) -> void:
	var node=of(owner_host)
	if node!=null: node.blockers.append(text)

## The host's line, created on first use.
static func of(owner_host: Node) -> Variant:
	if owner_host==null: return null
	var node=owner_host.get_meta(META) if owner_host.has_meta(META) else null
	if node==null or not is_instance_valid(node):
		node=load("res://scripts/lol2/target_status.gd").new()
		node.name="TargetStatus";node.host=owner_host
		owner_host.set_meta(META,node)
		# A population is set up from its host's _ready (or later); a deferred add never hits a busy parent. The deferred
		# call is the node's own, so a host freed first (tests that free a scene at once) never leaves an orphan.
		node.call_deferred("_adopt")
	return node

func _adopt() -> void:
	if is_inside_tree(): return
	if host!=null and is_instance_valid(host) and not host.is_queued_for_deletion(): host.add_child(self)
	else: queue_free()

func _init() -> void:
	label=Label.new();label.name="TargetStatusLabel";label.position=Vector2(16,48)
	add_child(label)
	process_priority=1000 # after the populations have written their texts this frame

static func fallen(owner_host: Node) -> bool:
	if owner_host==null or not is_instance_valid(owner_host): return false
	var magic=owner_host.get("starting_magic")
	return magic!=null and is_instance_valid(magic) and magic.health()==0

func compose() -> String:
	if fallen(host): return FELL
	for s in sources:
		var population=s[0];var text=s[1]
		if not is_instance_valid(population) or not is_instance_valid(text): continue
		if not population.is_inside_tree() or not population.can_process() or not population.is_processing(): continue
		if not str(text.text).is_empty() and str(text.text)!=FELL: return text.text
	return ""

func _process(_delta: float) -> void:
	label.text=compose()
	if label.text.is_empty(): return
	var mine: Rect2=Rect2(label.global_position,label.get_combined_minimum_size())
	for b in blockers:
		if is_instance_valid(b) and b.is_visible_in_tree() and not str(b.text).is_empty() and b.get_global_rect().intersects(mine):
			label.text="";return
