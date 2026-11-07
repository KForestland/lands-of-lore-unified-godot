# Museum pickups with an item in the hand

Owner r3 reports, 2026-10-20 (UTC 11:37 Prism, 11:42 Long arm), came from a save holding Broken Thohan in the hand (`hand_item = museum:control181:Tho_Broken`; the Broken Thohan grant puts the item in the hand). The original pickups for the Prism (prop280, group6590), the Long arm (prop153) and the other museum source pickups require an empty hand. The port refused them without any message, so the owner could not tell why nothing happened.

## Modern adapters (deviations)

- **Put away on E.** E first runs every action with the hand as it is, so actions that use the held item (key locks, putting Broken Thohan back) keep priority. If none applies and the held item is carried, E retries only the plain item grants with the hand emptied: Long arm, Prism, Lightning crystal, Fine Longsword, Mail Shirt and the Champion Stones. Actions whose empty-hand outcome is not a grant (sconce burns, urn chips, locks, controls) are never retried, so a held item does not set them off. The item stays in the pack; only the hand is cleared. When nothing is taken, the held item stays in the hand. The hint reads `E — Take Prism (puts away Broken Thohan)`.
- **Aim on the drawn sprite.** The Prism and the Long arm altar accept E when the view centre lies on the sprite's drawn rectangle with 4 degrees of slack, as well as by the old 14-degree cone around their anchor. The original picks any pixel of the item with the cursor, and the port draws no crosshair. At the owner's Prism pose the view centre sat on the hilt, 15 degrees below the sprite centre, which the cone refused.

The Long arm's modern safety prerequisite (passage78 open, curse requests enabled) is unchanged. With an item in the hand, its refusal text now shows instead of nothing.

## Not changed

Cursor-mode clicks (Prism `use_pointer`) still refuse a busy hand, as before. Whether the original swaps a held cursor item on such a click is not established.

Test: `tests/museum_hand_pickup_owner_pose_test.gd` uses both exact owner poses, with Broken Thohan in the hand.
