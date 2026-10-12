extends RefCounted
## Source frame clocks. Emits sound/event requests; host clock stays external.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Context = preload("res://scripts/lol2/hive_ai_animation_context.gd")
const SOURCE := "res://assets/lol2/generated/hive_attack/animation.json"
var _clips: Dictionary = {}
var _state: Dictionary = {}
var _selectors: Array = []

func _init(source_path: String = SOURCE, selectors: Array = [0,2]) -> void:
	_selectors = selectors.duplicate()
	var source = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	assert(source is Dictionary and source.version==1)
	for clip in source.clips: _clips[int(clip.selector)] = clip

func restore(saved: Variant) -> String:
	if not saved is Dictionary or not Numbers._integer(saved.get("selector"),255) or int(saved.selector) not in _selectors or not _clips.has(int(saved.selector)): return "Invalid source pose selector."
	var clip: Dictionary = _clips[int(saved.selector)]
	if not Numbers._integer(saved.get("frame"),int(clip.frames)-1) or not Numbers._integer(saved.get("timer"),int(clip.interval)-1): return "Invalid source pose progress."
	_state = {"selector":int(saved.selector),"frame":int(saved.frame),"timer":int(saved.timer)}
	return ""

func checkpoint() -> Dictionary:
	return _state.duplicate(true)

func animation_context(b4: Variant) -> Dictionary:
	if _state.is_empty(): return {"error":"Source pose unavailable."}
	var clip: Dictionary = _clips[_state.selector]
	return Context.evaluate({"action":clip.action,"frame":_state.frame,"last":int(clip.frames)-1,"b4":b4})

func advance(delta: Variant, b4: Variant, b5: Variant) -> Dictionary:
	if _state.is_empty(): return {"error":"Source pose unavailable."}
	if not Numbers._integer(delta,32767) or not Numbers._integer(b4,255) or not Numbers._integer(b5,255): return {"error":"Invalid source pose clock/control."}
	var events: Array = []
	if (int(b5)&2)==0:
		var clip: Dictionary = _clips[_state.selector]
		var last := int(clip.frames)-1
		var reverse := (int(b4)&8)!=0
		_state.timer -= int(delta)
		while _state.timer<0:
			_state.timer += int(clip.interval)
			var previous := int(_state.frame)
			_state.frame = (last if previous==0 else previous-1) if reverse else (0 if previous>=last else previous+1)
			for event in clip.events:
				if int(event.frame)!=_state.frame: continue
				assert(int(event.kind)==2)
				var raw: PackedByteArray = event.raw_hex.hex_decode()
				events.append({"type":"sound","frame":_state.frame,"id":int(raw[2])|(int(raw[3])<<8)})
			var terminal: bool = (previous>0 and _state.frame==0) if reverse else (previous<last and _state.frame==last)
			if terminal:
				events.append({"type":"terminal","frame":_state.frame,"event":3})
				_state.timer = maxi(0,_state.timer)
	return {"state":checkpoint(),"events":events,"active":true}
