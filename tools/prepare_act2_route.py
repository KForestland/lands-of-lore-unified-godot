#!/usr/bin/env python3
"""Join authored hintbook route notes to byte-checked native room/exit witnesses.

This is an audit, not a walkthrough test. Unknown semantic joins stay unknown.
The private book is not redistributed. Page references are printed book pages.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# id, book pages, action, room candidates, destination, dependency
ROUTES = {
    "L8_SJ": [
        ("daniel_gift", [86,87], "Offer Daniel his grandfather's blade, then recover it after the hopper interruption.", [25], None, "L4 gift acquisition and outdoor encounter"),
        ("temple_first_visit", [87], "Visit the temple approach and witness the priest encounter before village admission.", [38], None, "Temple introduction"),
        ("village_admission", [88,89], "Show the recovered blade to the village guard; visit Daniel and the shaman.", [39,25,22], None, "Guard item-offer event and settlement room navigation"),
        ("cemetery_quest", [89,98], "Receive the silverleaf request and cemetery key from the shaman; travel to the cemetery.", [22], 10, "Shaman reward callback"),
        ("ruins_return", [89,90], "After the ruins flood, meet Dawn at the lake and surrender the dead bracers.", [], None, "L9 flood return and Dawn offer"),
        ("bacatta_rescue", [90], "Free Baccata from his trap on the return route.", [], None, "Outdoor rope interaction; exact required-versus-optional status not established"),
        ("silverleaf_return", [90,91], "Return with silverleaf; complete initiation and offer a leaf to the shaman for potion ingredients.", [25,22], None, "L10 emperor resolution and initiation fight"),
        ("larkhon", [93], "Combine silverleaf and amaranth serum; use the activated mixture on the Larkhon and enter the Claw Mountains.", [], 12, "Item recipe, targeted offer and sleep state"),
        ("temple_entry", [85,94], "Return from the mountains with the dreamstone and enter the Huline Temple.", [38], 14, "Dreamstone acquisition in later area; TMPLDOR door and exit callbacks"),
        ("optional_tree", [92], "After obtaining a temple shard, light tree-platform torches and use the shard for the optional treasure room.", [], None, "Optional revisit; not a mandatory exit prerequisite"),
    ],
    "L10_DC": [
        ("cemetery_key", [98,99], "Use the shaman's key to enter the main cemetery.", [], None, "L8 shaman reward"),
        ("gold_globe", [99,100], "Collect an empty globe, enter the catacombs and charge it gold.", [], None, "Globe placement, charger and retrieval events"),
        ("mage_tower", [100,101], "Visit the ruins' Mage's Tower for dead bracers and white globes; return to the cemetery.", [], 9, "Teleporter only when activated; earlier access via L8"),
        ("barrel", [101,102], "Use a white globe on the tomb, flip its switch, roll the barrel into the opposite tomb and ignite the spilled oil.", [], None, "Human barrel interaction, collision and fire trigger; hintbook reports an original barrel bug"),
        ("blue_globes", [103], "Reach the exposed catacombs and charge blue globes.", [], None, "Oil explosion opens access"),
        ("priest", [103], "Enter the priest's tomb with a blue globe and dead bracers; obtain his urn.", [], None, "Priest conversation and item grant"),
        ("priest_return", [104], "Complete the priest's body-and-ashes task in the ruins; return for the ankh.", [], None, "L9 task; cross-area inventory and quest persistence"),
        ("emperor", [104], "Use the ankh, place gold/white/blue globes in the matching boxes, hear the emperor and collect his remains.", [21], None, "Three orb controls and EMPT room callback"),
        ("emperor_ruins", [104], "Use the activated teleporter to take the emperor's remains to the ruins.", [], 9, "Emperor reward and teleporter state"),
        ("silverleaf", [104,105], "After the ruins flood and Dawn encounter, revisit the emperor and collect the newly growing silverleaf; return to L8.", [21], 8, "L9 resolution, room callback and plant activation"),
    ],
}


ROUTES.update({
'L9_DR':[
('bridge_orb',[110,112],'Reach the ruins from L8 and use Spark on the black orb to raise the bridge.',[],None,'Orb spell caller and bridge groups need an exact join'),
('tower_globes',[112,113],'Open the tower forcefields, charge two white globes and recover the dead bracers.',[],10,'Orb controls, charger and bracer pickup; optional teleport nexus distinguished from required path'),
('priest_ashes',[113,114],'Bring the priest body onto the altar, energize both orbs, burn the body and collect ashes in his urn.',[45],10,'ALTAR is a room-name candidate only; corpse placement and urn offer unjoined'),
('emperor_statue',[115],'Put the emperor remains in the statue alcove bowl and follow the statue.',[20],None,'STAT room candidate; remains offer and statue route unjoined'),
('flood_escape',[116,117],'After the worm encounter floods the chamber, escape by the rising furniture and waterfall passage to L8.',[],8,'Water progression, grate and return event must be earned'),
],
'L12_CM':[
('icy_valley',[120,121],'Follow the icy valley after the avalanche and cross the cave ledges.',[],None,'Optional village, cave and lake rewards are not mandatory gates'),
('citadel_approach',[122],'Cross the river, meet Baccata in the ice tunnel and proceed into the citadel.',[],13,'Encounter trigger and citadel entrance join pending; charm is optional'),
('river_return',[127,128],'Return from the citadel along the river route, then travel back to L8 with the dreamstone.',[],8,'Requires L13 dreamstone; optional bow and obsidian detour not a gate'),
],
'L13_RC':[
('entry_orb',[124],'Energize the entry orb, destroy the egg chamber fixture and take the lift down.',[],None,'Spark, fixture damage, drain and elevator groups unjoined'),
('maiden',[125],'Cross the activated bridge and speak with the imprisoned maiden and Dawn.',[28,29],None,'DSLAVE/SLAVES room candidates; exact dialogue conditions need callback recovery'),
('ruloi_boss',[126],'Pass the alternating ledges and turrets, then defeat the Ruloi leader.',[],None,'Movement and combat completion must be linked to source actors'),
('dreamstone',[127],'Take the dreamstone and free Dawn after the citadel encounter.',[28,29],None,'Dreamstone grant and prisoner release; optional sword forge precedes pickup'),
('exit_slot',[127,128],'Use the dreamstone in the exit slot, retrieve it and return to the mountains.',[],12,'Slot consumption/retrieval and return gate must preserve the item'),
],
'L14_HT':[
('revive_priest',[132,133],'Put the priest body on the slab, aloe in the west bowl and poison in the east; lower the floor and use Spark.',[],None,'Body placement, directional bowls and spell caller unjoined; reported bowl bug not yet reproduced'),
('first_shard',[133],'Recover the first green shard from the northern ceremonial room and find the curtain passage.',[],None,'Shard pickup and hidden passage source groups unjoined'),
('flute_statue',[134,135],'Recover the flute and run the corpse through the two machines to obtain a statue.',[],None,'Machine ordering, corpse consumption and statue grant unjoined'),
('second_shard',[137],'Use the lizard passage and the two buttons to reach the library; place the statue for the second shard.',[],None,'Form restriction, ordered switches and statue receptacle unjoined'),
('shard_bowls',[137],'Place both green shards in the floating bowls to open the next passage.',[],None,'Two item offers and passage condition unjoined'),
('three_statues',[138],'Complete the maze, tilting-floor and fire-button rooms to collect three statues.',[],None,'Three separate puzzle states required; no completion seeds'),
('pedestals',[139],'Use the flute slot, cross the oil and blade route, and place the three statues on their pedestals.',[],None,'Flute use, hazards and three item receptacles unjoined'),
('hopper_platform',[139],'Load the platform with five hopper bodies, then step onto it.',[],None,'Corpse count and player occupancy must be sourced'),
('false_belial',[140],'Fight the temple apparition in Beast form.',[],None,'Book states Beast; exact source combat/form gate not yet joined'),
('chalice',[140,141],'Place the dreamstone in the chalice in the voices chamber to raise and enter the ancient city.',[30],16,'CHV room candidate; dreamstone consumed here according to book, unlike earlier doors'),
],
'L16_CA':[
('water_source',[146],'Open the fountain water source for the corner-room tasks.',[],None,'Orb and fountain break events unjoined'),
('northwest',[147],'Solve the ice, fire and stone orb sequence in the northwest corner and send its box through the portal.',[],None,'Elemental item/spell matching; tower transfer area identity not established'),
('northeast',[148,149],'Use water and silverleaf in the greenhouse pyramid, turn the hourglass and send the box onward.',[],None,'Lichen reward optional; growth and box transfer unjoined'),
('southeast',[149],'Ignite the oil at the head statue, obtain the Dark Bow and retreat through the doors to the box portal.',[],None,'Fire, door timing and portal box unjoined'),
('ivory_chips',[150,153,154,155,156,157],'Collect four ivory chips from the city puzzles for the southwest route.',[],None,'Individual chip identities and optional detours require exact joins'),
('southwest',[150],'Complete the southwest corner after the other three, using the four ivory chips.',[],None,'Order and chip checks must come from source groups'),
('tower_boxes',[158],'On each of four tower visits, put the box in its socket and use the yellow control.',[],None,'Repeated interleaved visits, not four consecutive final steps; tower area mapping UNKNOWN'),
('mantle',[159],'Defeat the central apparition and cross the light bars to obtain the Mantle.',[],None,'Boss and light-bar sequence unjoined'),
('dragon_exit',[160],'Operate the dragon-room orbs and curtain, then follow the opened route into the caverns.',[31],17,'BALCONY room candidate only; exact dragon and one-way exit prerequisites unjoined'),
],
'L17_HC':[
('cavern_route',[164,165],'Pass the spider caverns and cut through the red strands; use the creature interior route to reach the laboratory.',[34,37],19,'L17 assignment inferred from travel topology and HIVE room names; book-to-area geometry join UNKNOWN'),
],
'L19_BC':[
('laboratory_approach',[166],'Witness Baccata last encounter, receive the horn and cross the gated liquid chamber using the form passages and switches.',[],None,'L19 assignment inferred from L17/L20 topology; precise encounter/area boundary UNKNOWN'),
('rapids_and_circle',[167],'Traverse the rapids or alternate bridge; use Mist on the four heads, defeat the demon and bring its body to the circle.',[],None,'Room-to-area join UNKNOWN; item, spell, corpse and elevator events unjoined'),
('birth_chamber',[168],'Reach Dawn and the birth chamber, use Curse on the mother and pursue Belial past the demons.',[],20,'L19/L20 boundary UNKNOWN; do not assume a decoded exit implements the full sequence'),
],
'L20_BB':[
('pillar_chase',[168,169],'Pursue Belial through the moving pillars and use the armory resources when needed.',[],None,'Book-to-area boundary inferred only; hazards, boss phases and optional supplies unjoined'),
('final_belial',[170,171],'Pass the false Draracle encounter, defeat Belial and reach the concluding sequence.',[],None,'Ending trigger unjoined; the book suspects a finale bug, not yet reproduced or established'),
],
})

def build(native_root, game):
    stems = json.loads((ROOT / "scripts/lol2/room_stems.json").read_text())["entries"]
    result = {"version": 1, "scope": "Chapters 8-14 route audit across ten areas. Later area assignments are candidates where stated; native semantic joins remain incomplete. Revisit steps are interleaved across areas, not a linear per-area completion order. Not proof of playable progression.", "grades": ["HINTBOOK", "DECODED"], "areas": {}}
    for area, steps in ROUTES.items():
        raw = (native_root / (area + ".json")).read_bytes()
        data = json.loads(raw)
        archive = (game / data["source"]["file"]).read_bytes()
        assert hashlib.sha256(archive).hexdigest() == data["source"]["sha256"]
        witnesses = []
        for group in data["groups"]:
            for command in group["commands"]:
                b = bytes.fromhex(command["raw_hex"])
                room = command["opcode"] == 12
                transition = command["opcode"] == 2 and b[4] == 0x1c
                if not (room or transition):
                    continue
                at = command["file_offset"]
                assert archive[at:at + len(b)] == b
                owners = [{"object": o["ref"], "event": e} for o in data["objects"] for e in o["events"] if e.get("stream") == group["stream"] and e.get("group") == group["group"]]
                row = {"stream": group["stream"], "group": group["group"], "command": command, "owners": owners, "grade": "DECODED"}
                if room:
                    row.update(type="room", room_index=b[4], archive=stems[b[4]]["archive"], hosted="adapter request only; room callback not hosted")
                else:
                    row.update(type="exit", destination=b[5] & 31, selector=b[5] >> 5, hosted="adapter binder; quest prerequisites not established by exit test")
                witnesses.append(row)
        out = []
        for ident, pages, action, rooms, destination, dependency in steps:
            candidates = [i for i, w in enumerate(witnesses) if (w["type"] == "room" and w["room_index"] in rooms) or (w["type"] == "exit" and destination == w["destination"])]
            out.append(dict(id=ident, hintbook_pages=pages, action=action, grade="HINTBOOK", witness_candidates=candidates, join="candidate only: room identity/exit destination does not prove the full quest step", hosted="not hosted end-to-end", reason=dependency))
        result["areas"][area] = dict(source=data["source"], export_sha256=hashlib.sha256(raw).hexdigest(), steps=out, witnesses=witnesses)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--native-root", type=Path, default=ROOT / "scripts/lol2/native_scripts")
    p.add_argument("--game", type=Path, required=True)
    p.add_argument("--out", type=Path, default=ROOT / "docs/act2_route.json")
    a = p.parse_args()
    data = build(a.native_root, a.game)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(data, indent=2) + "\n")
    lines = ["# Act 2 route audit", "", data["scope"], "", "Groups below are candidates, not verified full quest joins. Room requests currently stop at logging.", "", "| Area / step | Book pages | Candidate stream:groups | Hosted today / remaining work |", "|---|---|---|---|"]
    for area, entry in data["areas"].items():
        for step in entry["steps"]:
            groups = sorted({f'{entry["witnesses"][i]["stream"]}:{entry["witnesses"][i]["group"]}' for i in step["witness_candidates"]})
            lines.append(f'| {area} / {step["id"]} | {step["hintbook_pages"]} | {", ".join(groups) or "UNKNOWN"} | {step["hosted"]}: {step["reason"]} |')
    a.out.with_suffix(".md").write_text("\n".join(lines) + "\n")
    print("PASS byte-checked route witnesses for all ten Act2/3 areas; gameplay progression remains incomplete")


if __name__ == "__main__":
    main()
