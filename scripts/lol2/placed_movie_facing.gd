extends RefCounted
## Facing of in-world movies placed on cave controls (playtest 2026-10-17, reports10:43:24 and10:51:27).
## A source placement heading h puts the object's local +x (texture left->right) along world (cos h, 0, sin h);
## calibrated on exported L1_DC movables (headings 57/90/237/344 degrees). Seen from the back of that plane the
## image reads mirrored. The port keeps its camera-facing billboard size and only mirrors the frames.
static func control_heading(control_hex: String) -> float:
	var raw:=control_hex.hex_decode()
	return float(raw.decode_u16(4))*TAU/65536.0
static func mirrored(camera: Camera3D, heading: float) -> bool:
	return camera.global_basis.x.dot(Vector3(cos(heading),0.0,sin(heading))) < 0.0
