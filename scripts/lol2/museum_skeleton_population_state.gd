extends RefCounted
## Museum skeletons 20-32 and Rat22: thin wrapper over scripted_creature_state.gd
## bound to the L3_DH population source (docs/museum-skeleton-population.md).
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const SOURCE="res://scripts/lol2/museum_skeleton_population_source.json"
const FPS:=Generic.FPS
const ALERT_RANGE:=Generic.ALERT_RANGE
const REACH:=Generic.REACH
const SPEED:=Generic.SPEED
static func source() -> Dictionary: return Generic.source(SOURCE)
static func actor_row(src: Dictionary, id: String) -> Dictionary: return Generic.actor_row(src,id)
static func scripted_wake(src: Dictionary, id: String) -> bool: return Generic.scripted_wake(src,id)
static func clip_seconds(frames: int) -> float: return Generic.clip_seconds(frames)
static func attack_rules(src: Dictionary, id: String, variant: int) -> Dictionary: return Generic.attack_rules(src,id,variant)
static func initial() -> Dictionary: return Generic.initial(source())
const Audio=preload("res://scripts/lol2/scripted_creature_audio_state.gd")
static func audio_contract() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/museum_creature_audio_source.json"))
static func validate(state: Variant) -> String:
	var src:=source()
	var error:=Generic.validate(state,src)
	if not error.is_empty(): return error
	return Audio.validate(state.audio,src.actors,audio_contract()) if state.has("audio") else ""
static func canonical(state: Dictionary) -> Dictionary:
	var result:=Generic.canonical(state,source())
	if result.has("audio"): result.audio=Audio.canonical(result.audio)
	return result
static func spawn(state: Dictionary, id: String) -> bool: return Generic.spawn(state,id)
static func wake(state: Dictionary, id: String) -> bool: return Generic.wake(state,id)
static func contact(state: Dictionary, src: Dictionary, point: Vector3, foot: float) -> Array: return Generic.contact(state,src,point,foot)
static func damage(state: Dictionary, src: Dictionary, id: String, amount: int) -> int: return Generic.damage(state,src,id,amount)
static func advance_clocks(state: Dictionary, src: Dictionary, delta: float) -> void: Generic.advance_clocks(state,src,delta)
static func ready_to_fight(state: Dictionary, src: Dictionary, id: String) -> bool: return Generic.ready_to_fight(state,src,id)
static func advance_live(state: Dictionary, src: Dictionary, id: String, delta: float, distance: float, sight: bool, protected: bool, player_health: int) -> int: return Generic.advance_live(state,src,id,delta,distance,sight,protected,player_health)
