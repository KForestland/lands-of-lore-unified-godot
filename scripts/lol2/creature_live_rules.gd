extends RefCounted
## Shared live creature step: perception -> pursue -> one-impact attack clip.
## Callers supply source-derived damage/clip timing and their documented adapters
## (range, reach). Saved packet: {mode, elapsed, hit, heading}.
enum {IDLE, PURSUE, ATTACK}

## Returns player damage dealt this step (0 or capped damage). An attack clip always
## completes and lands at most once; reach, sight and protection are checked only at
## the impact frame.
static func advance(live: Dictionary, alive: bool, delta: float, distance: float, sight: bool, protected: bool, player_health: int, rules: Dictionary) -> int:
	if not is_finite(delta) or delta<=0: return 0
	if not alive:
		live.mode=IDLE;live.elapsed=0.0;live.hit=false
		return 0
	var damage:=0
	if live.mode==ATTACK:
		# Saved clocks stay on a 1/1024s grid so JSON saves round-trip exactly.
		var elapsed:=snappedf(float(live.elapsed)+delta,1.0/1024)
		if not live.hit and elapsed>=float(rules.impact):
			live.hit=true
			if sight and distance<=float(rules.reach) and not protected and player_health>0: damage=mini(int(rules.damage),player_health)
		if elapsed<float(rules.clip):
			live.elapsed=elapsed
			return damage
		live.mode=IDLE;live.elapsed=0.0;live.hit=false
	if player_health<=0 or not sight or distance>float(rules.alert): live.mode=IDLE
	elif distance<=float(rules.reach): live.mode=ATTACK
	else: live.mode=PURSUE
	return damage

static func validate(live: Variant, alive: bool, rules: Dictionary) -> String:
	const Values=preload("res://scripts/lol2/save_value_rules.gd")
	if not live is Dictionary or not Values.integer(live.get("mode"),ATTACK) or not live.get("hit") is bool: return "Invalid creature live mode."
	var elapsed=live.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>=float(rules.clip): return "Invalid creature attack clock."
	if int(live.mode)!=ATTACK and (elapsed!=0 or live.hit): return "Idle creature retains an attack clock."
	if live.hit and elapsed<float(rules.impact): return "Creature impact precedes its frame."
	if not alive and int(live.mode)!=IDLE: return "Defeated creature remains active."
	if not Values.integer(live.get("heading"),65535): return "Invalid creature heading."
	return ""

static func heading_units(facing: Vector2) -> int:
	return roundi(atan2(facing.x,facing.y)*65536.0/TAU)&0xffff
static func heading_vector(units: int) -> Vector2:
	var angle:=float(units)*TAU/65536.0
	return Vector2(sin(angle),cos(angle))
## Godot JSON does not round-trip every float32-derived value; 1/64 units does.
static func saved_position(p: Vector3) -> Array:
	return [snappedf(p.x,1.0/64),snappedf(p.y,1.0/64),snappedf(p.z,1.0/64)]
