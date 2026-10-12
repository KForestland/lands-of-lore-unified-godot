extends "res://scripts/lol2/audible_creature_population.gd"
## Museum skeletons/Rat on the generic scripted creature owner. Saved in the Museum
## checkpoint as "skeletons" (docs/museum-skeleton-population.md).
const ROOT:="res://assets/lol2/generated/museum_creature_sprites/"
## Per-definition adapters: skeleton opaque height ~ human 46 units; Rat as Roach.
const MUSEUM_CONFIG:={"nav":"res://assets/lol2/generated/creature_nav/L3_DH.json","root":ROOT,"source":"res://scripts/lol2/museum_skeleton_population_source.json","target_prefix":"museumcreature","fighting_owner":"fighting_checkpoint",
	"audio_contract":"res://scripts/lol2/museum_creature_audio_source.json","audio_manifest":"res://assets/lol2/generated/museum_creature_audio/audio.json",
	"names":{"0":"Skeleton","2":"Skeleton","1":"Rat"},
	"look":{"0":{"canvas":[320,240],"scale":0.29,"floor_row":212,"radius":12,"height":44},"2":{"canvas":[320,240],"scale":0.29,"floor_row":221,"radius":12,"height":44},"1":{"canvas":[320,200],"scale":0.21818181818181817,"floor_row":174,"radius":6,"height":12}}}
static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT+"sprites.json")
func _init() -> void:
	configure(MUSEUM_CONFIG)
