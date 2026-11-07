extends SceneTree
const Dawn = preload("res://scripts/lol2/l19_dawn_curse.gd")
var failures: int = 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Dawn.PROP == 78 and Dawn.ACTOR == 39 and Dawn.DAWN_REGION == 1461 and Dawn.ACTOR_REGION == 2182, "Dawn prop and actor")
	check(Dawn.MOTHER == 242 and Dawn.MOTHER_REGION == 262 and Dawn.BIRTHED_PLACEMENTS == 0, "placenta, no birthed row")
	check(Dawn.RUBY_DEFINITION == 69 and Dawn.RUBY_IDENTITY == 4227368151 and Dawn.RUBY_HANDLER == 101 and not Dawn.grants_ruby(), "ruby identity stays ungranted")
	check(Dawn.CURSE_AT == 2 and Dawn.RUBY_AT == 3 and Dawn.CURSE_LINE != Dawn.RUBY_COMMENT, "click counts stay an adapter")
	check(Dawn.ANCIENT_LEVEL == 5 and Dawn.accepts_level(5) and not Dawn.accepts_level(4), "level 5 only")
	check(Dawn.SCENE_NAME == "placenta.vqa" and Dawn.SCENE_OFFSET == 5066703 and not Dawn.IN_MOVIE_TABLE and not Dawn.plays_movie(), "placenta stays unplayed")
	check(Dawn.DEMONS == -1 and Dawn.DOOR == -1 and not Dawn.relocates_player(), "demons and the door stay unbound")
	check(Dawn.validate(Dawn.initial()).is_empty(), "initial state")
	var bad: Dictionary = Dawn.initial()
	bad.clicks = 2
	bad.curse_said = true
	bad.line = ""
	check(not Dawn.validate(bad).is_empty(), "a blank curse line is refused")
	bad = Dawn.initial()
	bad.demons_killed = true
	check(not Dawn.validate(bad).is_empty(), "a demon kill is refused")
	if failures == 0: print("PASS l19_dawn_curse_test: Dawn clicks, level 5, placenta unplayed")
	quit(1 if failures else 0)
