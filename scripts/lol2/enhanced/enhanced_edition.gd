extends RefCounted
## Enhanced Edition switch. Classic never sees an Enhanced feature: everything behind this is opt-in through the
## `--enhanced` user argument (or the engine meta "lol2_enhanced" that tests set).
static func enabled() -> bool:
	return "--enhanced" in OS.get_cmdline_user_args() or bool(Engine.get_meta("lol2_enhanced", false))
