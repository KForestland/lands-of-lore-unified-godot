extends RefCounted

# Prototype values, not recovered Lands of Lore II combat rules.
enum Phase { IDLE, PURSUING, WINDUP, RECOVERY, DEFEATED }
const PLAYER_HEALTH := 30
const ENEMY_HEALTH := 24
const PLAYER_DAMAGE := 8
const ENEMY_DAMAGE := 6
const STRIKE_COOLDOWN := 0.45
# Default source marker12 / prototype8fps; scene configures from verified assets.
const WINDUP_TIME := 1.5
const RECOVERY_TIME := 0.5
const ALERT_RANGE := 180.0
const ENEMY_REACH := 40.0

var player_health := PLAYER_HEALTH
var enemy_health := ENEMY_HEALTH
var phase := Phase.IDLE
var phase_remaining := 0.0
var strike_remaining := 0.0
var complete := false
var completion_count := 0
var windup_time := WINDUP_TIME
var recovery_time := RECOVERY_TIME

func configure_attack(impact_frame: int, frames: int, fps: float) -> void:
	assert(impact_frame > 0 and impact_frame < frames and fps > 0.0)
	windup_time = impact_frame / fps
	recovery_time = (frames - impact_frame) / fps

func attack_elapsed() -> float:
	if phase == Phase.WINDUP:
		return windup_time - phase_remaining
	if phase == Phase.RECOVERY:
		return windup_time + recovery_time - phase_remaining
	return 0.0

func strike(in_reach: bool, aimed: bool, unobstructed: bool, damage: int = PLAYER_DAMAGE) -> bool:
	if player_health <= 0 or enemy_health <= 0 or strike_remaining > 0.0:
		return false
	strike_remaining = STRIKE_COOLDOWN
	if not (in_reach and aimed and unobstructed):
		return false
	enemy_health = maxi(0, enemy_health - maxi(0,damage))
	if enemy_health == 0:
		phase = Phase.DEFEATED
		phase_remaining = 0.0
	return true

func advance(delta: float, distance: float, unobstructed: bool, invulnerable: bool = false, defense: int = 0) -> int:
	strike_remaining = maxf(0.0, strike_remaining - delta)
	if player_health <= 0 or enemy_health <= 0:
		return 0
	if phase == Phase.WINDUP:
		phase_remaining = maxf(0.0, phase_remaining - delta)
		if phase_remaining > 0.0:
			return 0
		phase = Phase.RECOVERY
		phase_remaining = recovery_time
		if unobstructed and distance <= ENEMY_REACH and not invulnerable:
			var damage := mini(preload("res://scripts/lol2/player_defense.gd").damage(15,defense), player_health)
			player_health -= damage
			return damage
		return 0
	if phase == Phase.RECOVERY:
		phase_remaining = maxf(0.0, phase_remaining - delta)
		if phase_remaining > 0.0:
			return 0
	if not unobstructed or distance > ALERT_RANGE:
		phase = Phase.IDLE
	elif distance <= ENEMY_REACH:
		phase = Phase.WINDUP
		phase_remaining = windup_time
	else:
		phase = Phase.PURSUING
	return 0

func enter_exit(has_sample: bool, inside: bool) -> bool:
	if complete or player_health <= 0 or enemy_health > 0 or not has_sample or not inside:
		return false
	complete = true
	completion_count += 1
	return true
