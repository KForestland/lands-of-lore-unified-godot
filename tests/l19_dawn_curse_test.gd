extends SceneTree
const Dawn = preload("res://scripts/lol2/l19_dawn_curse.gd")
var failures: int = 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Dawn.PROP == 78 and Dawn.ACTOR == 39 and Dawn.DAWN_REGION == 1461 and Dawn.ACTOR_REGION == 2182, "Dawn prop and actor")
	check(Dawn.MOTHER == 242 and Dawn.MOTHER_REGION == 262 and Dawn.BIRTHED_PLACEMENTS == 0, "placenta, no birthed row")
	check(Dawn.RUBY_DEFINITION == 69 and Dawn.RUBY_IDENTITY == 4227368151 and Dawn.RUBY_HANDLER == 101 and Dawn.grants_ruby(), "ruby identity is granted")
	check(Dawn.CURSE_AT == 2 and Dawn.RUBY_AT == 3 and Dawn.CURSE_LINE != Dawn.RUBY_COMMENT, "click counts stay an adapter")
	check(Dawn.ANCIENT_LEVEL == 5 and Dawn.accepts_level(5) and not Dawn.accepts_level(4), "level 5 only")
	check(Dawn.SCENE_NAME == "placenta.vqa" and Dawn.SCENE_OFFSET == 5066703 and not Dawn.IN_MOVIE_TABLE and Dawn.plays_movie(), "placenta stays off the movie table")
	check(Dawn.BIRTH_MOVIE == 65 and Dawn.BIRTH_NAME == "bb_brth" and Dawn.BIRTH_X == -1382 and Dawn.BIRTH_Y == 3213 and Dawn.BIRTH_FLAGS == 0x0085 and Dawn.BIRTH_HEADING == 0x4000, "opcode 21 index 65 and the opcode 18 words")
	check(Dawn.DEMONS == -1 and Dawn.DOOR == -1 and not Dawn.relocates_player(), "demons and the door stay unbound, and the curse module does not place Luther")
	check(Dawn.validate(Dawn.initial()).is_empty(), "initial state")
	var bad: Dictionary = Dawn.initial()
	bad.clicks = 2
	bad.curse_said = true
	bad.line = ""
	check(not Dawn.validate(bad).is_empty(), "a blank curse line is refused")
	bad = Dawn.initial()
	bad.demons_killed = true
	check(not Dawn.validate(bad).is_empty(), "a demon kill before the glob is refused")
	var born: Dictionary = Dawn.initial()
	born.clicks = 3
	born.curse_said = true
	born.ruby_offered = true
	born.line = Dawn.CURSE_LINE
	born.glob_entered = true
	born.demons_killed = true
	check(Dawn.validate(born).is_empty(), "demons die only after the glob")
	check(not born.mother_dead and not born.creatures_cleared and not Dawn.PLAYER_KILLS_MOTHER, "the player does not kill the mother")
	var early: Dictionary = born.duplicate()
	early.mother_dead = true
	check(Dawn.validate(early).is_empty(), "the mother dies after the demons")
	early.creatures_cleared = true
	check(Dawn.validate(early).is_empty(), "the clear follows the death")
	var reversed: Dictionary = born.duplicate()
	reversed.creatures_cleared = true
	check(not Dawn.validate(reversed).is_empty(), "creatures stay until the mother dies")
	var premature: Dictionary = Dawn.initial()
	premature.mother_dead = true
	check(not Dawn.validate(premature).is_empty(), "the mother does not die before the birth")
	if failures == 0: print("PASS l19_dawn_curse_test: Dawn clicks, level 5, birth card, the mother dies only after the demons")
	quit(1 if failures else 0)
