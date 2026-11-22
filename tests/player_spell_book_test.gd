extends SceneTree
const Book=preload("res://scripts/lol2/player_spell_book.gd")
const Magic=preload("res://scripts/lol2/player_magic_state.gd")
const Progress=preload("res://scripts/lol2/hive_magic_reward.gd")
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func _initialize() -> void:
	var old := Magic.initial()
	if not check(not old.has("spellbook") and Magic.restore(old).checkpoint == old,"Old packet byte shape stays unchanged"):return
	var book := Book.initial()
	for group: String in Book.GROUPS:
		var previous := book.duplicate(true)
		book=Book.learn(book,group)
		if not check(previous != book and Book.learn(book,group) == book,"One-time learning, independent copy: "+group):return
	if not check(book.learned.size()==8 and Book.validate(book).is_empty(),"Exactly the eight named casts"):return
	for vector in [["curse",1,0,"curse1",1],["curse",3,0,"curse3",2],["curse",3,2,"curse2",2],["curse",5,0,"curse5",5],["mists",1,0,"mists1",1],["mists",3,0,"mists3",3],["prism",5,0,"prism5",5],["summon",3,0,"summon3",3]]:
		var plan := Book.request(book,vector[0],vector[1],vector[2])
		if not check(plan == {"id":vector[3],"cost":vector[4]},"Fixed named adapter vector: "+str(vector)):return
	for school: String in Book.SCHOOLS:
		if not check(Book.cast_id(school,3,1).is_empty(),"Beast never casts"):return
	if not check(Book.request(Book.initial(),"prism",5,0).has("error") and Book.request(book,"prism",1,0).has("error"),"Unlearned and unsupported charges refuse"):return
	var saved := old.duplicate(true);saved.spell="summon";saved.spellbook=book
	var roundtrip := Magic.restore(JSON.parse_string(JSON.stringify(saved)))
	if not check(not roundtrip.has("error") and roundtrip.checkpoint == saved,"New selection/learned state survives save-shaped transport"):return
	var reward := Progress.award_checkpoint(saved,0,[])
	if not check(not reward.has("error") and reward.checkpoint == saved,"XP path retains learned state"):return
	for invalid in [{},{"version":true,"learned":[]},{"version":1,"learned":["curse4"]},{"version":1,"learned":["curse1","curse1"]},{"version":1,"learned":[],"extra":0}]:
		var bad := saved.duplicate(true);bad.spellbook=invalid
		if not check(Magic.restore(bad).has("error") and saved.spellbook==book,"Malformed learned state rejected without mutation"):return
	print("PASS G15 shared spell book: exact eight cast/cost vectors, forms, old/new disk/XP transport, invalid-state rejection; no quest receiver or earned-cast claim")
	quit()
