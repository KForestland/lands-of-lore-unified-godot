extends SceneTree
const Rule = preload("res://scripts/lol2/chain_short_sword_rule.gd")
func _initialize() -> void:
	var rule := Rule.new()
	for difficulty in range(3):
		for amount in range(256):
			rule.reset()
			assert(rule.strike(amount, difficulty) == 5370)
			assert(rule.remaining <= 1 and rule.script_state == 1)
			assert(rule.strike(amount, difficulty) == 0)
	rule.reset()
	assert(rule.strike(-1) == 0 and rule.strike(256) == 0 and rule.strike(1, 3) == 0)
	assert(rule.remaining == 2 and rule.script_state == 0)
	print("Short Sword rule: 768 hits, repeat rejection, invalid input, reset passed")
	quit()
