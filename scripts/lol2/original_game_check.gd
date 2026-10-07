extends RefCounted

# Verified against the local GOG installation and the 2026-04-25 RE ledger.
# This identifies file bytes, not purchase or licensing status.
const EXE_SHA256 := "cbd225cebc81cfbf06272456492686340d95c0148b5db9a0acca3c58653902f6"
const EXE_SIZE := 2847

static func verify(path: String) -> String:
	if path.is_empty():
		return "Select LOLG.EXE from your Lands of Lore II installation."
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "Cannot read this file. Select LOLG.EXE from your game installation."
	if file.get_length() != EXE_SIZE:
		return "Unrecognized executable. This build supports the verified GOG LOLG.EXE."
	var bytes := file.get_buffer(EXE_SIZE)
	file.close()
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	if bytes.size() != EXE_SIZE or hash_context.finish().hex_encode() != EXE_SHA256:
		return "Checksum mismatch. Select an unmodified GOG LOLG.EXE; other editions are not yet supported."
	return ""
