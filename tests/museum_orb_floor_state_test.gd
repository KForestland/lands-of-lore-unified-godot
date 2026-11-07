extends SceneTree
const State = preload("res://scripts/lol2/museum_orb_floor_state.gd")
func _initialize() -> void:
	var s := State.initial()
	assert(State.use(s))
	assert(not State.use(s))
	State.advance(s, 1.0)
	assert(s.height == -14.0 and s.timer == 540.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s))
	assert(State.validate(saved).is_empty())
	var restored := State.restore(saved)
	State.advance(s, 8.0); State.advance(restored, 8.0)
	assert(s == restored and s.height == 30.0 and s.local20 and s.timer == 60.0)
	State.advance(s, 1.0)
	assert(not s.local20 and s.target == -50.0 and s.height == 30.0 and s.timer == 600.0)
	State.advance(s, 1.0)
	assert(s.height == -6.0)
	assert(State.use(s)) # Original local20 is clear during descent: re-use reverses the target.
	State.advance(s, 1.0)
	assert(s.height == 30.0 and s.local20)
	State.advance(s, 9.0); State.advance(s, 3.0)
	assert(s.height == -50.0 and not s.local20)
	var before := s.duplicate(true)
	State.advance(s, 0.0); State.advance(s, -1.0); State.advance(s, NAN)
	assert(s == before)
	for key in ["height","target","timer"]:
		var bad := s.duplicate(true); bad[key] = NAN
		assert(not State.validate(bad).is_empty())
	assert(State.validate({"version":1,"raised":true}).is_empty())
	assert(State.restore({"version":1,"raised":true}).height == 30.0)
	assert(State.restore(null).height == -50.0)
	var legacy: Dictionary={"version":2,"local20":true,"height":-12.5,"target":30.0,"timer":540.0}
	assert(State.validate(legacy).is_empty())
	var migrated:=State.restore(legacy)
	assert(migrated.height==-13 and migrated.motion_fraction==32768 and State.validate(migrated).is_empty())
	var carry:=s.duplicate(true);carry.motion_fraction=65536
	assert(not State.validate(carry).is_empty())
	var bad := s.duplicate(true); bad.target = 30.0
	assert(not State.validate(bad).is_empty())
	print("PASS orb floor movement/timed reset/mid-motion JSON/reversal/legacy/invalid state")
	quit()
