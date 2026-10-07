extends "res://scripts/lol2/audible_creature_population.gd"
## Actor0 only. Shared pursuit is a modern adapter; native behavior6 admission unresolved.
const SETTINGS:={"root":"res://assets/lol2/generated/cave_wild_roach_sprites/","source":"res://scripts/lol2/cave_wild_roach_source.json","target_prefix":"cavewildroach","fighting_owner":"quest_state","render":"cave_indexed","nav":"res://assets/lol2/generated/creature_nav/L1_DC.json",
	"audio_contract":"res://scripts/lol2/cave_roach_audio_source.json","audio_manifest":"res://assets/lol2/generated/cave_roach_audio/audio.json","names":{"5":"Roach"},
	"look":{"5":{"canvas":[320,200],"scale":0.21818181818181817,"floor_row":137,"radius":6,"height":12}}}
func _init() -> void: configure(SETTINGS)
func targets() -> Dictionary:
	var result:=super.targets()
	for target in result.values(): target.point=target.body.global_position+Vector3(0,6,0)
	return result
