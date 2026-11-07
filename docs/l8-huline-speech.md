# Huline speech at the first encounter

The owner report near(-3982,1142) is close to the original first trio. Original actor93 group18566 requests sound237, actor92 group17970 requests1012, and arena Daniel23/group15636 plus actor82/group17284 request1016. These are sound-bank selectors, not WOM line numbers. `prepare_l8_huline_speech.py --game GAME --output-root PROJECT` pins those bytes and stages three lossless original WAVs. Sound413 in a village-guard callback is `crosbow9.aud`, so it is excluded from dialogue.

Grok’s20:01 board reply confirms no first-meeting trigger join; kind8 value229 is not treated as a clip or meeting event.

The modern interaction plays the selected actor-bound cue once when the player faces that living, present actor and presses E in reach. It is not a decoded native greeting branch, a transcription, or a reconstruction of the full conversation. Daniel23 is eligible only after the completed initiation. Actor82 must already be present; no NPC is spawned for speech. Other source callbacks and the clubhouse guard's unjoined welcome remain outside this bounded speech fix.

Playback holds movement and world consumers, pauses with the game, supports mid-line saves, and records completion per actor. Repeated E falls through to the existing interaction once that cue has been heard. Enter skips the active cue. No item, attitude, native flag or quest outcome is granted by speech.

Qualification:5/5 PASS, source unchanged, `tmp/regressions/l8_huline_speech_final/report.json`: L8 creatures6.05s, journey state0.80s, journey live1.92s, physical clubhouse72.35s, earned speech10.69s. The speech test uses the actual Dawn departure branch for the first trio, and a separate whole saved arena checkpoint for Daniel; inventories are never merged. It checks playing original streams, movement/world hold, pause, mid-line save/reload and once-only completion. Owner listening confirmation remains pending.
