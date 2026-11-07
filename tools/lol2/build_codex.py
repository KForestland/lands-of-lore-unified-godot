#!/usr/bin/env python3
"""C1 Codex generator. Writes data/lol2/codex.json.

Items come from item_catalog.gd, act2_items_catalog.gd, the item census, and
the hint-book chapter 3 names. Creatures and characters are names from the
research tables. The sentence is the held or met name. A catalog slot may add
one line about where it is worn. Effect lines, recipes, and later uses are not
copied.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

CLASS_SLOTS = {0x44: "weapon", 0x48: "weapon", 0x50: "offhand", 0x53: "offhand", 0x60: "armor"}
SLOT_SENTENCE = {
    "weapon": "It fits the weapon hand.",
    "armor": "It fits the armor place.",
    "offhand": "It fits the off hand.",
}
CHARGED = {"yellow": 99, "white": 100, "blue": 101}
NAMED_ACT2 = {
    "act2:L12_CM:blue_bow": "Blue Bow",
    "act2:L12_CM:item5": "Obsidian Chain Mail",
    "act2:L13_RC:dark_sword": "Dark Sword",
    "act2:L13_RC:enchanted_thohan": "Enchanted Thohan’s Sword",
    "act2:L13_RC:dreamstone": "Dreamstone",
    "act2:L13_RC:dawn_bestial_disk": "Bestial Disk",
    "act2:L12_CM:kenneth_picture": "Kenneth’s Picture",
    "act2:L12_CM:kenneth_charm": "Kenneth’s Charm",
    "act2:L8_SJ:larkhon_vapors": "Larkhon Vapors",
    "act2:L8_SJ:shaman_amaranth": "Amaranth Serum",
    "act2:L8_SJ:dawn_control_token": "Control Token",
    "act2:L10_DC:priest_urn": "Caretaker Urn",
    "act2:L10_DC:priest_ankh": "Ankh",
    "act2:L10_DC:emperor_remains": "Emperor Remains",
}
BASIN = {145: "51-Cowards sh", 146: "33-Myriad", 147: "20-Bastion"}
LICHEN_RECORDS = [518, 521, 522, 527, 528, 533, 534, 539, 540, 545, 546, 551, 552, 557]
MAGIC_LABELS = {
    "War_cluster": "War Cluster",
    "Mana_foil": "Mana Foil",
    "SS5": "Spell Scroll",
    "Fire_crystals": "Fire Crystal",
    "Dag_Light": "Dagger of Light",
    "Tho_fixed": "Thohan's Great Sword",
}
MAGIC_WEAPONS = {"jungle:magic_shop:Dag_Light", "jungle:magic_shop:Tho_fixed"}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def quoted_strings(block: str) -> list[str]:
    return re.findall(r'"([^"]*)"', block)


def const_block(text: str, name: str, opener: str = "{") -> str:
    marker = f"const {name} := {opener}"
    marker2 = f"const {name}:={opener}"
    start = text.find(marker)
    if start < 0:
        start = text.find(marker2)
    if start < 0:
        raise SystemExit(f"missing const {name}")
    closer = "}" if opener == "{" else "]"
    depth = 0
    for index in range(start, len(text)):
        char = text[index]
        if char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
    raise SystemExit(f"unclosed const {name}")


def norm(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_") or "entry"


def held(name: str, slot: str) -> str:
    text = "I have held %s." % (name.strip() or "this")
    extra = SLOT_SENTENCE.get(slot, "")
    return text if not extra else text + " " + extra


def load_definitions(game: Path) -> list[dict]:
    path = game / "assets/lol2/generated/items/definitions.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    rows = data["definitions"]
    if len(rows) != 170:
        raise SystemExit("definitions.json is not 170 rows")
    return rows


def by_index(rows: list[dict]) -> dict[int, dict]:
    return {int(row["index"]): row for row in rows}


def def_label(rows: dict[int, dict], index: int) -> str:
    row = rows.get(index)
    return str(row.get("label", "")).strip() if row else ""


def def_slot(rows: dict[int, dict], index: int) -> str:
    row = rows.get(index)
    if not row or row.get("ghost"):
        return ""
    return CLASS_SLOTS.get(int(row.get("item_class", 0)), "")


def hintbook_names(path: Path | None) -> set[str]:
    if path is None or not path.is_file():
        return set()
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    start = next((i for i, line in enumerate(lines) if "Chapter Three: Items" in line and i > 1000), None)
    end = next((i for i, line in enumerate(lines) if "Chapter Four: Getting Things Done" in line and i > 1600), None)
    if start is None or end is None or end <= start:
        return set()
    found = set()
    for line in lines[start:end]:
        text = line.strip()
        if not text or len(text) > 40 or "." in text:
            continue
        key = norm(text)
        if len(key) >= 4:
            found.add(key)
    return found


def census_labels(path: Path | None) -> dict[int, str]:
    if path is None or not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    rows = data.get("definitions") or data.get("items") or []
    if isinstance(data, dict) and not rows:
        # The census file is a list at the top level after a header object was not used.
        pass
    labels = {}
    if isinstance(data, list):
        rows = data
    elif isinstance(data, dict):
        for key in ("definitions", "items", "rows"):
            if isinstance(data.get(key), list):
                rows = data[key]
                break
        else:
            rows = [value for value in data.values() if isinstance(value, dict) and "index" in value]
    for row in rows:
        if isinstance(row, dict) and "index" in row and "label" in row:
            labels[int(row["index"])] = str(row["label"])
    return labels


def fixed_facts(catalog: str) -> dict[str, dict]:
    block = const_block(catalog, "FIXED")
    facts = {}
    for line in block.splitlines():
        match = re.match(r'\s*"([^"]+)":\{.*"slot":"([^"]*)".*"label":"([^"]*)"', line)
        if not match:
            continue
        facts[match.group(1)] = {"name": match.group(3), "slot": match.group(2)}
    if len(facts) < 40:
        raise SystemExit("FIXED parse is short: %d" % len(facts))
    return facts


def one_line_items(text: str, const: str) -> dict[str, dict]:
    block = const_block(text, const)
    facts = {}
    for line in block.splitlines():
        match = re.match(r'\s*"([^"]+)":\{.*"name":"([^"]*)".*"label":"([^"]*)"', line)
        if not match:
            continue
        slot = "offhand" if match.group(2) == "38-Guard shield" else ""
        facts[match.group(1)] = {"name": match.group(3), "slot": slot}
    return facts


def dark_halls_facts(text: str) -> dict[str, dict]:
    block = const_block(text, "ITEMS")
    facts = {}
    for line in block.splitlines():
        match = re.match(r'\s*"([^"]+)":\{"label":"([^"]*)".*"slot":"([^"]*)"', line)
        if match:
            facts[match.group(1)] = {"name": match.group(2), "slot": match.group(3)}
    if len(facts) != 13:
        raise SystemExit("dark halls items: %d" % len(facts))
    return facts


def string_map(text: str, const: str) -> dict[str, str]:
    block = const_block(text, const)
    return dict(re.findall(r'"([^"]+)":"([^"]+)"', block))


def string_list(text: str, const: str) -> list[str]:
    block = const_block(text, const, "[")
    return quoted_strings(block)


def int_list(text: str, const: str) -> list[int]:
    block = const_block(text, const, "[")
    return [int(value) for value in re.findall(r"-?\d+", block.split(":=", 1)[1])]


def area_facts(text: str, rows: dict[int, dict]) -> dict[str, dict]:
    facts = {}
    for area, prefix in (("museum", "museum:item"), ("darkhalls", "darkhalls:item"), ("darkerjungle", "darkerjungle:item")):
        row_match = re.search(rf'"{area}": \{{.*?"rows": \[([^\]]+)\].*?"definitions": \[([^\]]+)\]', text, re.S)
        if not row_match:
            raise SystemExit("area block missing " + area)
        row_ids = [int(value) for value in re.findall(r"\d+", row_match.group(1))]
        definitions = [int(value) for value in re.findall(r"\d+", row_match.group(2))]
        if len(row_ids) != len(definitions):
            raise SystemExit("area length mismatch " + area)
        for row, index in zip(row_ids, definitions):
            label = def_label(rows, index)
            ident = "%s%d:%s" % (prefix, row, label.replace(" ", "_"))
            facts[ident] = {"name": label, "slot": def_slot(rows, index)}
    if len(facts) != 17:
        raise SystemExit("area ids: %d" % len(facts))
    return facts


def catalog_facts(game: Path, rows: dict[int, dict]) -> dict[str, dict]:
    scripts = game / "scripts/lol2"
    catalog = read(scripts / "item_catalog.gd")
    facts = fixed_facts(catalog)
    facts["cave:captain:Short_Sword"] = {"name": "Short Sword", "slot": "weapon"}
    facts["cave:captain:Burnt_Chain"] = {"name": "Burnt Chain", "slot": "armor"}
    scrolls = read(scripts / "museum_scroll_state.gd")
    scroll_ids = string_list(scrolls, "IDS")
    scroll_defs = int_list(scrolls, "DEFINITIONS")
    for ident, index in zip(scroll_ids, scroll_defs):
        facts[ident] = {"name": def_label(rows, index), "slot": ""}
    for ident in string_list(read(scripts / "museum_aloe_state.gd"), "IDS"):
        facts[ident] = {"name": def_label(rows, 110), "slot": ""}
    hive = read(scripts / "hive_world_items_state.gd")
    for ident, index in zip(string_list(hive, "IDS"), int_list(hive, "DEFINITIONS")):
        facts[ident] = {"name": def_label(rows, index), "slot": ""}
    facts.update(area_facts(read(scripts / "area_world_items_state.gd"), rows))
    for record in (144, 145, 146, 147, 148, 149, 641):
        facts["cave:prop%d:harvest1:Stalagmite" % record] = {"name": "Stalagmite", "slot": "weapon"}
    for record in (791, 792, 793):
        for harvest in (1, 2, 3):
            facts["cave:prop%d:harvest%d:Cave_Aloe" % (record, harvest)] = {"name": "Cave Aloe", "slot": ""}
    weapons = string_map(read(scripts / "weapon_shop_state.gd"), "ITEMS")
    for ident in weapons.values():
        if ident in facts:
            continue
        facts[ident] = {"name": ident.split(":")[2].replace("_", " "), "slot": "weapon"}
    herb_defs = {"sap": 111, "amber": 112, "aloe": 110}
    for kind, index in herb_defs.items():
        for number in (0, 1):
            facts["jungle:herb:%s:%d" % (kind, number)] = {"name": def_label(rows, index), "slot": ""}
    facts["monastery:item94:Iron_Flute"] = {"name": "Iron Flute", "slot": ""}
    facts["monastery:item83:Power_Orb"] = {"name": "Power Orb", "slot": ""}
    facts["hive:item0:Wax"] = {"name": "Wax", "slot": ""}
    facts["jungle:kityara:Empty_hand"] = {"name": "Kityara's blade", "slot": "weapon"}
    facts["l8:shaman:Dracoid_sigil"] = {"name": "Dracoid Sigil", "slot": ""}
    magic = const_block(read(scripts / "magic_shop_state.gd"), "ITEMS")
    for ident in quoted_strings(magic):
        if not ident.startswith("jungle:magic_shop:"):
            continue
        key = ident.split(":")[2]
        if key.startswith("Fire_crystals_"):
            key = "Fire_crystals"
        facts[ident] = {"name": MAGIC_LABELS[key], "slot": "weapon" if ident in MAGIC_WEAPONS else ""}
    facts.update(one_line_items(read(scripts / "jungle_world_items_catalog.gd"), "ITEMS"))
    for ident in string_list(read(scripts / "jungle_beehive_wax.gd"), "POOL"):
        facts[ident] = {"name": "Wax", "slot": ""}
    for number in range(1, 28):
        facts["jungle:aloe_plant:Aloe_%d" % number] = {"name": "Aloe", "slot": ""}
    for number in range(1, 25):
        facts["jungle:sap_tree:Ironwood_sap_%d" % number] = {"name": "Ironwood sap", "slot": ""}
    for number in range(1, 13):
        facts["hive:control123:Amber_%d" % number] = {"name": "Amber", "slot": ""}
    facts.update(dark_halls_facts(read(scripts / "dark_halls_items.gd")))
    for number in range(23):
        facts["hive:Wax_runes:%d" % number] = {"name": "Wax runes", "slot": ""}
    thieves = string_map(read(scripts / "thieves_den_state.gd"), "ITEMS")
    by_name = {str(row["name"]).strip(): row for row in rows.values()}
    for source_name, ident in thieves.items():
        if ident in facts:
            continue
        row = by_name.get(source_name)
        label = str(row["label"]) if row else source_name
        facts[ident] = {"name": label, "slot": ""}
    return facts


def act2_facts(game: Path, rows: dict[int, dict], placement: dict[str, dict]) -> tuple[dict[str, dict], int]:
    source = json.loads((game / "scripts/lol2/act2_items_source.json").read_text(encoding="utf-8"))
    facts: dict[str, dict] = {}
    disagree = 0

    def add(ident: str, name: str, index: int | None = None) -> None:
        nonlocal disagree
        if ident in placement:
            return
        shown = name
        if index is not None and index >= 0 and not rows.get(index, {}).get("ghost"):
            definition_name = def_label(rows, index)
            if definition_name and norm(definition_name) != norm(name):
                disagree += 1
                shown = definition_name
            elif definition_name:
                shown = definition_name
        facts[ident] = {"name": shown, "slot": ""}

    for block in source["areas"].values():
        for row in block.get("items", []):
            index = int(row["definition"])
            add(str(row["id"]), str(row.get("label") or row.get("name") or row["id"]), index)
            if index == 98:
                for color, charged_index in CHARGED.items():
                    add(str(row["id"]) + ":charged:" + color, color.capitalize() + " Glass Globe", charged_index)
    add("act2:L9_DR:tower_blank", "Empty Glass Globe", 98)
    for color, charged_index in CHARGED.items():
        add("act2:L9_DR:tower_blank:charged:" + color, color.capitalize() + " Glass Globe", charged_index)
    for row_number, name in BASIN.items():
        add("act2:L13_RC:item%d" % row_number, name, {145: 50, 146: 32, 147: 19}[row_number])
    add("act2:L14_HT:item65", "Statuette", 103)
    item5 = next(row for row in source["areas"]["L14_HT"]["items"] if int(row["row"]) == 5)
    item67 = next(row for row in source["areas"]["L14_HT"]["items"] if int(row["row"]) == 67)
    for suffix in ("371", "372", "384"):
        add("act2:L14_HT:trial_idol" + suffix, str(item5.get("label") or item5["name"]), int(item5["definition"]))
    add("act2:L14_HT:post_shard", str(item67.get("label") or item67["name"]), int(item67["definition"]))
    for number in range(9):
        add("act2:L16_CA:pad_lichen%d" % number, "Black Lichen", 122)
    for number in LICHEN_RECORDS:
        add("act2:L16_CA:lichen%d" % number, "Black Lichen", 122)
    for number in range(159, 171):
        add("act2:L10_DC:silverleaf%d" % number, "Silverleaf", 117)
    for number in (91, 92, 93, 94, 95):
        add("act2:L14_HT:hopper_corpse%d" % number, "Hopper corpse", None)
    for ident, name in NAMED_ACT2.items():
        add(ident, name, None)
    return facts, disagree


def generic_facts(rows: dict[int, dict], have: set[str]) -> dict[str, dict]:
    facts = {}
    for index, row in rows.items():
        if row.get("ghost"):
            continue
        ident = "item:def%03d" % index
        if ident in have:
            continue
        facts[ident] = {"name": str(row.get("label") or row.get("name")), "slot": def_slot(rows, index)}
    return facts


def table_rows(text: str) -> list[list[str]]:
    rows = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or set(cells[0]) <= set("-: "):
            continue
        rows.append(cells)
    return rows


def named_section(path: Path | None, column: int, skip: tuple[str, ...] = ()) -> dict[str, dict]:
    if path is None or not path.is_file():
        return {}
    entries = {}
    seen = set()
    for cells in table_rows(path.read_text(encoding="utf-8")):
        if len(cells) <= column:
            continue
        name = cells[column].strip()
        if not name or name.lower() in ("creature", "who speaks", "area"):
            continue
        blob = " ".join(cells)
        if any(phrase in blob for phrase in skip):
            continue
        if name in seen:
            continue
        seen.add(name)
        ident = slug(name)
        while ident in entries:
            ident += "_2"
        entries[ident] = {"name": name, "text": name + "."}
    return entries


def lore_places(path: Path | None) -> dict[str, dict]:
    if path is None or not path.is_file():
        return {}
    entries = {}
    for cells in table_rows(path.read_text(encoding="utf-8")):
        if len(cells) < 2 or cells[0].lower() == "who speaks":
            continue
        if "Not a conversation" in " ".join(cells) or "Not one placed NPC" in " ".join(cells):
            continue
        place = cells[1].split(",")[0].strip()
        lowered = place.lower()
        if not place or any(word in lowered for word in ("brady", "prima", "finale", "hintbook")):
            continue
        ident = slug(place)
        if ident in entries:
            continue
        entries[ident] = {"name": place, "text": place + "."}
    return entries


def build(game: Path, census: Path | None, hintbook: Path | None, creatures: Path | None, characters: Path | None) -> dict:
    rows = by_index(load_definitions(game))
    placement = catalog_facts(game, rows)
    act2, disagree = act2_facts(game, rows, placement)
    generics = generic_facts(rows, set(placement) | set(act2))
    listed = hintbook_names(hintbook)
    census_names = census_labels(census)
    confirmed = 0
    for index, label in census_names.items():
        if norm(label) == norm(def_label(rows, index)):
            confirmed += 1
    items = {}
    hint_hits = 0
    for ident, fact in {**placement, **act2, **generics}.items():
        entry = {"name": fact["name"], "text": held(fact["name"], fact.get("slot", ""))}
        if norm(fact["name"]) in listed:
            entry["listed_in_hintbook"] = True
            hint_hits += 1
        items[ident] = entry
    book = {
        "version": 1,
        "voice": "Luther, after holding or meeting the thing. No later use is written.",
        "sources": {
            "item_catalog": "scripts/lol2/item_catalog.gd",
            "act2_items_catalog": "scripts/lol2/act2_items_catalog.gd",
            "definitions": "assets/lol2/generated/items/definitions.json",
            "item_census_rows": len(census_names),
            "census_label_matches": confirmed,
            "act2_label_disagreements_not_merged": disagree,
            "hintbook_chapter3": "reference_hintbook/hintbook.txt chapter 3, folio 25",
            "hintbook_name_matches": hint_hits,
            "creatures": "grok_research/creatures.md names",
            "characters": "grok_research/npc_speech_map.md names",
        },
        "Items": items,
        "Creatures": named_section(creatures, 0),
        "Characters": named_section(characters, 0, ("Not a conversation", "Not one placed NPC")),
        "Lore": lore_places(characters),
    }
    for section in ("Items", "Creatures", "Characters", "Lore"):
        if not book[section]:
            raise SystemExit("empty section " + section)
    return book


def main() -> None:
    parser = argparse.ArgumentParser()
    here = Path(__file__).resolve()
    game_default = here.parents[2] if len(here.parents) > 2 else Path.cwd()
    parser.add_argument("--game", type=Path, default=game_default)
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--census", type=Path, default=Path("~/AI_COMMS/act1_completion_20261017/item_census.json"))
    parser.add_argument("--hintbook", type=Path, default=Path("~/AI_COMMS/reference_hintbook/hintbook.txt"))
    parser.add_argument("--creatures", type=Path, default=Path("~/AI_COMMS/grok_research/creatures.md"))
    parser.add_argument("--characters", type=Path, default=Path("~/AI_COMMS/grok_research/npc_speech_map.md"))
    args = parser.parse_args()
    book = build(args.game, args.census, args.hintbook, args.creatures, args.characters)
    out = args.out or (args.game / "data/lol2/codex.json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(book, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print("items", len(book["Items"]), "creatures", len(book["Creatures"]), "characters", len(book["Characters"]), "lore", len(book["Lore"]))
    print("sources", json.dumps(book["sources"]))


if __name__ == "__main__":
    main()
