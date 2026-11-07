# Jungle village Confidante (controls 112/123)

The Huline village Confidante is hosted from the original L4_HJ scripts (contract: AI_COMMS/grok_act1_mechanics_20261025/VILLAGE_ESCAPE_CONTRACT.md; preparer `tools/prepare_jungle_confidante.py`; state `scripts/lol2/jungle_confidante_state.gd`; live owner `scripts/lol2/jungle_confidante.gd`).

- **Control123** (E102E.VQA, assembly template47, 60×37): the first meeting. Seeing barrel prop1465 (p96: hut not smoked, barrel state0, Daniel known or Kityara dead) links it and loops idle segment3 (255 passes). Region3408 (p198: local20==0, Daniel/Kityara, hut not smoked) sets prop1465 state1, local20=1, holds Luther at (-1271,0,-4323) and focuses it. The next loop end (state1) starts timer prop68 (23 s) and plays segment0; timer prop68 or the segment end sets local27 Met_Confidant=1; the end releases Luther and unlinks it. Region3397 (p170) sets local20=2.
- **Control112** (E103E.VQA, template52): the second meeting. Seeing prop492 (p105: hut smoked or Anyar attacked, prop492 state0, Met_Confidant) links it (prop492 state1). Region3408 (p175: local20==2, smoked/Anyar, local39==0) holds Luther; the loop end sets state2 and plays segment0; its end adds 1 Soul, releases and unlinks it.
- **Kill**: a landed hit (kind9 value0; wildcard masks, threshold1, mode1, one-shot 0x80) runs group 25628 (112) or 25802 (123) once: local39 Killed_Confidante=1, Soul-1, release, local20=3/2, death segment1, state5; 123 also sets prop492 state5 (112 can then never appear) and plays sound269. The state5 end unlinks the control with sound227. The port passes the melee/Spark damage amount as context +0x1E; 0 or less changes nothing.
- **Owners**: locals 20/27/39 are owned here and saved in `quest_state.jungle_confidante`; locals 6/33 are read from the Kelsrick owner; Soul goes to the monastery globals (cap 10); shared29 is read from the village gate.

## Native gate: Daniel first (owner F10 2026-11-03, PT3-JUNGLE-PASSWORD-GUY)
Both first-meeting producers (barrel sight p96, region3408 p198) need GV_LUTHER_KNOWS_ABOUT_DANIEL (shared47) or
GV_KITYARA_DEAD (shared25). Shared47 is written only by Kit'yara's shop introduction (WPN, `weapon_shop_data.gd` intro
plan); the Prima hintbook (ch. 6) sends the player to the Armorer's Glen, south-west of the village, before the Hive.
A player who skips her shop finds nobody in the alley and the den door has no password; My Journal `no_confidante_yet`
names the armorer's glen. Nothing in the save blocks a later visit: entering her shop earns Daniel knowledge and the
Confidante then appears and speaks (`tests/jungle_confidante_owner_route_test.gd`, the owner's own save and a campaign
save). Classic keeps the gate; an Enhanced guard is a candidate (thieves_den_state JOURNAL_HINTS).

## Not hosted (gaps for the betrayal escape)
- Gate leaves 78/79 (groups 28068/28140, p196 local39==1 AND shared29==1) need a hit context with bit 0x0800 (AE2C8 mask test) and context+0x26 <= 1 (mode4); no traced producer supplies it. Killing the Confidante therefore sets the precondition but the port opens no gate. No bypass is added.
- Barrel prop1465's own hit group 15674 (p37 Barrel_Variable==0) and control100's CHUT stop group 21322 belong to other owners; they are recorded under `not_hosted` in the source contract.
- Region3247/3253/4523 stop control123 and set prop1465 property10; property10 has no port meaning and stays a receipt.

## Media
`python3 tools/prepare_jungle_confidante.py --game GAME --geometry L4_HJ/geometry/geometry.json --output scripts/lol2/jungle_confidante_source.json --media-root FRESH` writes `assets/lol2/generated/jungle_confidante_media/{112,123}/` (cyan-keyed frames rotated 270, voice.wav, media.json) and `sounds/227.wav`, `sounds/269.wav` under FRESH; copy `assets/` into the project. Original media stays local.
