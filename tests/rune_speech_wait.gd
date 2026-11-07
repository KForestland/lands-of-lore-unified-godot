extends RefCounted
static func settle(tree: SceneTree, entry) -> bool:
	for frame in range(1800):
		if not entry.busy(): return true
		await tree.process_frame
	push_error("Rune room playback did not finish naturally")
	tree.quit(1)
	return false
