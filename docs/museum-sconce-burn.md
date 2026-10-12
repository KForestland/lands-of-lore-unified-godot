# Lit Museum sconces

An empty-hand interaction with one of the22 source-backed lit sconces now causes5 damage through the existing player-health/death path. Unlit sconces, a busy hand and control134 do not burn the player. Key and panel interactions retain priority. Pause, death and the normal interaction gates suppress damage; health persists through the existing save system.

The original handler issues a hit-type0x10 damage operation. Its amount mode remains ambiguous, so5 damage is an explicit modern adapter. Source audio and the separate sconce recharge producer remain unresolved. Independent checks cover all22 targets, refusal cases, lethal damage, pause and disk reload; camera vantages are supplied.
