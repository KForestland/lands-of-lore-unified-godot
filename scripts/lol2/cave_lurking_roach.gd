extends "res://scripts/lol2/audible_creature_population.gd"
## Source-present36/37: WORM goal5 targets player; AA1 walks, reach selects AA2→clip5.
## Visibility, reach50, speed48, region navigation and8fps are shared playable adapters.
## Shared marker59 is startup AI context; it neither spawns nor wakes the pair.
const SETTINGS={"root":"res://assets/lol2/generated/cave_lurking_roach_sprites/","source":"res://scripts/lol2/cave_lurking_roach_source.json","target_prefix":"cavelurkingroach","fighting_owner":"quest_state","render":"cave_indexed","nav":"res://assets/lol2/generated/creature_nav/L1_DC.json",
	"audio_contract":"res://scripts/lol2/cave_lurking_roach_audio_source.json","audio_manifest":"res://assets/lol2/generated/cave_lurking_roach_audio/audio.json","names":{"6":"Cave creature"},
	"look":{"6":{"canvas":[320,200],"scale":0.21818181818181817,"floor_row":137,"radius":6,"height":12}}}
const Packet=preload("res://scripts/lol2/cave_lurking_roach_state.gd")
func _init() -> void: configure(SETTINGS)
static func assets_ready() -> bool:
	return FileAccess.file_exists(SETTINGS.root+"sprites.json") and FileAccess.file_exists(SETTINGS.audio_manifest)
func setup(walkthrough: Node3D, saved: Variant=null) -> String:
	return super.setup(walkthrough,saved if saved!=null else Packet.initial())
func restore(saved: Variant) -> String:
	var error:=Packet.validate(saved)
	if not error.is_empty(): return error
	var canonical: Dictionary=saved.duplicate(true)
	canonical.marker59=int(canonical.marker59)
	return super.restore(canonical)
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	# Native chooser is bound for the source bank plus reach condition44:
	# outside reach AA1; admitted reach AA2 dispatches A3DEC's clip5.
	# Shared live adapter supplies visibility/range and completes source hit clocks.
	super.advance(delta)
func targets() -> Dictionary:
	var result:=super.targets()
	for target in result.values(): target.point=target.body.global_position+Vector3(0,6,0)
	return result
