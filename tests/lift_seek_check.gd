extends RefCounted
## Test-only classifier for the prop83 lift resume.
## The saved-state remainder is a separate gate (accept_reload). It is not an audio tolerance.
## derived_offset is the expression max(sound_seconds - state.sound, 0) read after _sync_sound
## returns. It is not the argument observed at AudioStreamPlayer.play. Comparing it with the
## saved seek checks that expression twice; the device check is `post`.
## AUDIO_WINDOW stays 0.06. It applies to `post` and to the later sample against expected plus dt.
## dt starts when _sync_sound returns (stamp usec), not at the native play() instant.
## usec_before and usec bracket the super call. whole_dt is reported and is not the acceptance term.
## A driver period is not a tolerance.

const AUDIO_WINDOW := 0.06
const SEEK_EPS := 1e-6

static func accept_reload(load_error: String, state_sound: float, sound_left: float, playing: bool, expected_offset: float, stamps: Array, load_begin_usec: int, actual: float, sample_usec: int) -> Dictionary:
	if not load_error.is_empty() or absf(state_sound - sound_left) > 1e-6 or not playing:
		return {
			"ok": false,
			"kind": "deterministic_state",
			"reason": "saved remainder was not restored",
			"window": AUDIO_WINDOW,
			"state_sound": state_sound,
			"sound_left": sound_left,
			"playing": playing,
			"load_error": load_error,
		}
	return accept_playback(expected_offset, stamps, load_begin_usec, actual, sample_usec)

static func accept_playback(expected_offset: float, stamps: Array, load_begin_usec: int, actual: float, sample_usec: int) -> Dictionary:
	var during: Array = []
	for stamp in stamps:
		if typeof(stamp) != TYPE_DICTIONARY:
			continue
		if int(stamp.get("usec", -1)) >= load_begin_usec:
			during.append(stamp)
	var base := {
		"expected": expected_offset,
		"actual": actual,
		"window": AUDIO_WINDOW,
		"seek_eps": SEEK_EPS,
		"load_begin_usec": load_begin_usec,
		"sample_usec": sample_usec,
		"sync_count": during.size(),
	}
	if during.size() != 1:
		return _done(false, "deterministic_seek", "restore called _sync_sound %d times during the load; expected 1" % during.size(), base)
	var stamp: Dictionary = during[0]
	if not stamp.has("derived_offset") or not stamp.has("post") or not stamp.has("usec") or not stamp.has("usec_before"):
		return _done(false, "deterministic_seek", "stamp is missing the derived offset, device position, or sync-call bracket", base)
	var derived := float(stamp["derived_offset"])
	var post := float(stamp["post"])
	var seek_usec := int(stamp["usec"])
	var usec_before := int(stamp["usec_before"])
	var dt := (sample_usec - seek_usec) / 1000000.0
	var whole_dt := (sample_usec - load_begin_usec) / 1000000.0
	base["derived_offset"] = derived
	base["post"] = post
	base["pre"] = float(stamp.get("pre", 0.0))
	base["dt_since_sync_s"] = dt
	base["whole_dt_s"] = whole_dt
	base["seek_usec"] = seek_usec
	base["usec_before"] = usec_before
	base["sync_bracket_us"] = seek_usec - usec_before
	if absf(derived - expected_offset) > SEEK_EPS:
		base["offset_res"] = absf(derived - expected_offset)
		return _done(false, "deterministic_seek", "derived offset differs from the saved-state seek", base)
	var visible := absf(post - expected_offset)
	base["seek_visible_res"] = visible
	if visible > AUDIO_WINDOW:
		return _done(false, "deterministic_seek", "playback position when _sync_sound returned is outside 0.06 of the saved seek", base)
	if dt < 0.0:
		return _done(false, "wall_clock", "sample timestamp precedes _sync_sound return", base)
	var residual := absf(actual - (expected_offset + dt))
	base["residual"] = residual
	base["raw_seek_res"] = absf(actual - expected_offset)
	base["whole_residual"] = absf(actual - (expected_offset + whole_dt))
	if residual > AUDIO_WINDOW:
		return _done(false, "wall_clock", "post-return playback residual exceeds 0.06", base)
	return _done(true, "pass", "derived offset matches, device position at _sync_sound return is within 0.06, and the later sample is within 0.06 of the seek plus measured dt", base)

static func _done(ok: bool, kind: String, reason: String, base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out["ok"] = ok
	out["kind"] = kind
	out["reason"] = reason
	return out
