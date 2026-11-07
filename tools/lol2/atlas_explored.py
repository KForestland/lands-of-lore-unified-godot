#!/usr/bin/env python3
"""Explored-atlas rules mirrored by scripts/lol2/atlas_explored.gd."""
CREATURE_AREAS = (
    "L8_SJ", "L9_DR", "L10_DC", "L12_CM", "L13_RC",
    "L14_HT", "L16_CA", "L17_HC", "L19_BC", "L20_BB",
)
REGION_LIMIT = 12000


def initial():
    return {"version": 1, "areas": {}}


def area_of(host):
    named = host.get("area_id")
    if isinstance(named, str) and named:
        return named
    path = str(host.get("geometry_file", ""))
    if path.endswith("darker_jungle/area.json"):
        return "L8_SJ"
    if path.endswith("dark_halls/area.json"):
        return "L7_DH"
    if path.endswith("hive.json"):
        return "L5_HC"
    if path.endswith("jungle.json"):
        return "L4_HJ"
    return ""


def area_name_ok(area):
    if not isinstance(area, str) or not 2 <= len(area) <= 16:
        return False
    for index, char in enumerate(area):
        letter = "A" <= char <= "Z"
        digit = "0" <= char <= "9"
        if index == 0 and not letter:
            return False
        if not letter and not digit and char != "_":
            return False
    return True


def validate(saved, quests):
    if not isinstance(quests, dict):
        return "Invalid atlas explored."
    if not isinstance(saved, dict) or len(saved) != 2 or int(saved.get("version", 0)) != 1:
        return "Invalid atlas explored."
    areas = saved.get("areas")
    if not isinstance(areas, dict):
        return "Invalid atlas explored."
    for area, row in areas.items():
        if not area_name_ok(area):
            return "Invalid atlas explored."
        if not isinstance(row, dict) or not isinstance(row.get("full"), bool) or not isinstance(row.get("regions"), list):
            return "Invalid atlas explored."
        if row["full"] and row["regions"]:
            return "Invalid atlas explored."
        if len(row["regions"]) > REGION_LIMIT:
            return "Invalid atlas explored."
        seen = set()
        for raw in row["regions"]:
            if isinstance(raw, bool) or not isinstance(raw, (int, float)):
                return "Invalid atlas explored."
            if float(raw) != float(int(raw)):
                return "Invalid atlas explored."
            region = int(raw)
            if region < 0 or region >= REGION_LIMIT or region in seen:
                return "Invalid atlas explored."
            seen.add(region)
    return ""


def migrate(quests, host_area):
    areas = {}
    if host_area:
        areas[host_area] = {"full": True, "regions": []}
    for key in quests:
        name = str(key)
        if not name.startswith("act2_creatures_"):
            continue
        area = name[len("act2_creatures_"):]
        if area in CREATURE_AREAS and area not in areas:
            areas[area] = {"full": True, "regions": []}
    return {"version": 1, "areas": areas}


def reveal(saved, area, ids, mapped=-1):
    copy = {"version": int(saved.get("version", 1)), "areas": {}}
    for key, row in saved.get("areas", {}).items():
        copy["areas"][key] = {"full": bool(row.get("full")), "regions": [int(r) for r in row.get("regions", [])]}
    if not area:
        return copy
    row = copy["areas"].get(area, {"full": False, "regions": []})
    if row["full"]:
        copy["areas"][area] = {"full": True, "regions": []}
        return copy
    seen = []
    for raw in list(row["regions"]) + list(ids):
        region = int(raw)
        if region < 0 or region in seen:
            continue
        seen.append(region)
    seen.sort()
    if mapped >= 0 and len(seen) >= mapped and mapped > 0:
        copy["areas"][area] = {"full": True, "regions": []}
    else:
        copy["areas"][area] = {"full": False, "regions": seen}
    return copy
