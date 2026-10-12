extends SceneTree
const Audio=preload("res://scripts/lol2/scripted_creature_audio_state.gd")
const Museum=preload("res://scripts/lol2/museum_skeleton_population_state.gd")
func _initialize() -> void:
	var source:=Museum.source()
	var contract:=Museum.audio_contract()
	var checks:=0
	for definition in contract.definitions:
		for selector in contract.definitions[definition]:
			var clip: Dictionary=contract.definitions[definition][selector]
			for cue in clip.cues:
				var v: Dictionary={"selector":-1,"time":0.0,"request":0,"sample":0}
				Audio.advance(v,int(selector),float(cue[0])/8.0,0.0,clip.cues,0.0,8.0,contract)
				assert(v.request==int(cue[1]) and v.sample==0)
				var once:=v.duplicate(true)
				Audio.advance(v,int(selector),float(cue[0])/8.0,0.0,clip.cues,0.0,8.0,contract)
				assert(v==once)
				checks+=1
	assert(checks==51)
	var packet:=Audio.initial(source.actors)
	var actor: Dictionary=packet["24"]
	var walk: Dictionary=contract.definitions["2"]["4"]
	for frame in range(1,601):
		Audio.advance(actor,4,float(frame)/60.0,1.0/60.0,walk.cues,float(walk.frames)/8.0,8.0,contract)
		assert(Audio.validate(packet,source.actors,contract).is_empty())
		assert(Audio.canonical(JSON.parse_string(JSON.stringify(packet)))==packet)
	var saved:=Museum.initial();saved.audio=packet
	assert(Museum.validate(saved).is_empty() and Museum.canonical(JSON.parse_string(JSON.stringify(saved)))==saved)
	for entry in [["selector",999],["selector",0.5],["request",65535],["sample",-1],["sample",0.5],["time",-1],["time",INF]]:
		var bad:=packet.duplicate(true);bad["24"][entry[0]]=entry[1]
		assert(not Audio.validate(bad,source.actors,contract).is_empty())
	var missing:=packet.duplicate(true);missing.erase("22")
	assert(not Audio.validate(missing,source.actors,contract).is_empty())
	print("PASS: 51 original definition-specific cues exactly once, 600 loop/JSON round trips, Museum validation and malformed voice rejection")
	quit()
