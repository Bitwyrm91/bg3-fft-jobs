#!/usr/bin/env python3
"""Generate the mod's derived files from data/ and stats_src/.

Outputs:
  Mod/Mods/FFTJobs/ScriptExtender/Lua/Shared/GeneratedData.lua  (jobs, abilities, config defaults, presets)
  Mod/Public/FFTJobs/Stats/Generated/Data/*.txt                  (stats_src templates with localization handles)
  Mod/Localization/English/FFTJobs.xml                           (English strings; Part B converts it to .loca)
  docs/vanilla_refs.md, docs/vanilla_refs.json                   (vanilla IDs the stats rely on, for Part B)

Usage: python3 tools/build.py            write the files
       python3 tools/build.py --check    exit 1 if a generated file is missing or stale
"""
import json
import re
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOD_UUID = "3db7be3e-9387-4678-b172-044acc7ff0c2"
MOD_FOLDER = "FFTJobs"
MOD_VERSION = "1.0.0.20"
JOB_BOARD_SPELL = "Shout_FFTJ_JobBoard"
TRAINING_SPELL = "Shout_FFTJ_JPTraining"
# Icons: art\icons\<key>.png -> icon FFTJ_Icon_<key> in our atlas (64 px cells, like vanilla Icons_Skills); the DDS
# files are made by tools\make_icons.ps1 when packaging.
ICON_PREFIX = "FFTJ_Icon_"
ATLAS_NAME = "Icons_FFTJobs"
ATLAS_SIZE = 1024
ATLAS_CELL = 64
ABILITY_TYPES = ("Action", "Reaction", "Support", "Movement")
GRANT_KINDS = ("spells", "passives", "statuses")
SLOT_OF_TYPE = {"Reaction": "reaction", "Support": "support", "Movement": "movement"}
# A job's "equip" list: BG3 proficiency groups (every one occurs in a vanilla Proficiency() boost) -> English text.
# The main job grants them through its marker passive ({{prof:<JobId>}} in stats_src).
PROFICIENCIES = {
    "Daggers": "daggers", "Shortswords": "shortswords", "Longswords": "longswords", "Greatswords": "greatswords",
    "Rapiers": "rapiers", "Scimitars": "scimitars", "Handaxes": "handaxes", "Battleaxes": "battleaxes",
    "Greataxes": "greataxes", "Flails": "flails", "Morningstars": "morningstars", "Maces": "maces", "Clubs": "clubs",
    "Greatclubs": "greatclubs", "LightHammers": "light hammers", "Warhammers": "warhammers", "Mauls": "mauls",
    "Warpicks": "war picks", "Quarterstaffs": "quarterstaffs", "Spears": "spears", "Pikes": "pikes",
    "Glaives": "glaives", "Halberds": "halberds", "Tridents": "tridents", "Javelins": "javelins",
    "Sickles": "sickles", "Shortbows": "shortbows", "Longbows": "longbows", "HandCrossbows": "hand crossbows",
    "LightCrossbows": "light crossbows", "HeavyCrossbows": "heavy crossbows", "MartialWeapons": "martial weapons",
    "LightArmor": "light armour", "MediumArmor": "medium armour", "HeavyArmor": "heavy armour",
    "Shields": "shields", "MusicalInstrument": "musical instruments", "SimpleWeapons": "simple weapons",
}

DATA_DIR = ROOT / "data"
STATS_SRC = ROOT / "stats_src"
LUA_OUT = ROOT / "Mod" / "Mods" / MOD_FOLDER / "ScriptExtender" / "Lua" / "Shared" / "GeneratedData.lua"
STATS_OUT = ROOT / "Mod" / "Public" / MOD_FOLDER / "Stats" / "Generated" / "Data"
LOCA_OUT = ROOT / "Mod" / "Localization" / "English" / f"{MOD_FOLDER}.xml"
REFS_MD = ROOT / "docs" / "vanilla_refs.md"
REFS_JSON = ROOT / "docs" / "vanilla_refs.json"
ART_DIR = ROOT / "art" / "icons"
ATLAS_LSX = ROOT / "Mod" / "Public" / MOD_FOLDER / "GUI" / f"{ATLAS_NAME}.lsx"
TEXTURE_BANK = ROOT / "Mod" / "Public" / MOD_FOLDER / "Content" / "UI" / "[PAK]_UI" / "_merged.lsx"


class BuildError(Exception):
    pass


def load_json(name):
    with open(DATA_DIR / name, encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------- validation

def validate(jobs_doc, config_doc, strings_doc):
    errors = []
    jobs = jobs_doc["jobs"]
    job_ids = [j["id"] for j in jobs]
    if len(job_ids) != len(set(job_ids)):
        errors.append("duplicate job id")
    job_by_id = {j["id"]: j for j in jobs}
    badge_ids = [b["id"] for b in jobs_doc.get("badges", [])]
    if len(badge_ids) != len(set(badge_ids)):
        errors.append("duplicate badge id")
    for b in jobs_doc.get("badges", []):
        if not b.get("name") or not b.get("description"):
            errors.append(f"badge {b['id']}: needs a name and a description")
    for j in jobs:
        for req in j.get("unlock", []):
            if "badge" in req:
                if req["badge"] not in badge_ids:
                    errors.append(f"job {j['id']}: unknown badge {req['badge']}")
                continue
            if "kills" in req:
                if not (isinstance(req["kills"], int) and req["kills"] > 0):
                    errors.append(f"job {j['id']}: kills must be a positive whole number")
                continue
            if req["job"] not in job_by_id:
                errors.append(f"job {j['id']}: unknown required job {req['job']}")
            if req.get("mastered"):
                if "level" in req:
                    errors.append(f"job {j['id']}: a requirement is either a level or mastered, not both")
            elif not (1 <= req["level"] <= 8):
                errors.append(f"job {j['id']}: required level {req['level']} out of range")
            if j.get("implemented") and not job_by_id.get(req["job"], {}).get("implemented"):
                errors.append(f"job {j['id']} is implemented but requires unimplemented job {req['job']}")
        levels = [t.get("level") for t in j.get("levelGrants", [])]
        if any(not isinstance(lv, int) or not 1 <= lv <= 8 for lv in levels) or levels != sorted(set(levels)):
            errors.append(f"job {j['id']}: levelGrants need increasing job levels 1-8")
        for p in j.get("equip", []):
            if p not in PROFICIENCIES:
                errors.append(f"job {j['id']}: unknown proficiency {p} (see PROFICIENCIES in tools/build.py)")
        mastery = j.get("mastery")
        if mastery:
            if not mastery.get("description"):
                errors.append(f"job {j['id']}: mastery perk without a description")
            for kind in mastery:
                if kind not in GRANT_KINDS and kind != "description":
                    errors.append(f"job {j['id']}: bad mastery grant kind {kind}")
        if j.get("implemented") and not mastery:
            errors.append(f"job {j['id']} is implemented but has no mastery perk")
    ab_ids = set()
    for a in jobs_doc["abilities"]:
        aid = a["id"]
        if aid in ab_ids:
            errors.append(f"duplicate ability id {aid}")
        ab_ids.add(aid)
        if a["job"] not in job_by_id:
            errors.append(f"ability {aid}: unknown job {a['job']}")
        elif not job_by_id[a["job"]].get("implemented"):
            errors.append(f"ability {aid}: job {a['job']} is not implemented")
        if a["type"] not in ABILITY_TYPES:
            errors.append(f"ability {aid}: bad type {a['type']}")
        if not isinstance(a["cost"], int) or a["cost"] < 0:
            errors.append(f"ability {aid}: bad cost {a['cost']}")
        for g in [a.get("grants", {})] + [v["grants"] for v in a.get("variants", [])]:
            for kind in g:
                if kind not in GRANT_KINDS:
                    errors.append(f"ability {aid}: bad grant kind {kind}")
        if not a.get("grants"):
            errors.append(f"ability {aid}: grants nothing")
        if not a.get("description"):
            errors.append(f"ability {aid}: no description")
    for a in jobs_doc["abilities"]:
        for v in a.get("variants", []):
            for cond in v["when"].get("anyOf", []):
                for key, val in cond.items():
                    if key == "primaryJob" and val not in job_by_id:
                        errors.append(f"ability {a['id']}: variant condition on unknown job {val}")
                    elif key == "equippedEffect" and not any(x.get("effect") == val for x in jobs_doc["abilities"]):
                        errors.append(f"ability {a['id']}: variant condition on unknown effect {val}")
                    elif key == "learned" and val not in ab_ids:
                        errors.append(f"ability {a['id']}: variant condition on unknown ability {val}")
                    elif key not in ("primaryJob", "equippedEffect", "equipped", "learned"):
                        errors.append(f"ability {a['id']}: unknown variant condition {key}")
    defaults = config_doc["defaults"]
    for jid in defaults["Rules"]["StartingUnlocked"]:
        if not job_by_id.get(jid, {}).get("implemented"):
            errors.append(f"config: starting job {jid} is not an implemented job")
    sj = defaults["Rules"]["StartingJob"]
    for jid in [sj["Default"]] + list(sj["ByClass"].values()):
        if jid not in defaults["Rules"]["StartingUnlocked"]:
            errors.append(f"config: starting job {jid} is not in StartingUnlocked")
    th = defaults["JobLevels"]["Thresholds"]
    if th != sorted(th) or len(th) != 7:
        errors.append("config: JobLevels.Thresholds must be 7 increasing numbers")
    if config_doc["defaultPreset"] not in config_doc["presets"]:
        errors.append("config: defaultPreset is not a preset")
    for name, p in config_doc["presets"].items():
        bad = unknown_paths(p["values"], defaults)
        if bad:
            errors.append(f"config: preset {name} sets unknown keys {bad}")
    if errors:
        raise BuildError("data errors:\n  " + "\n  ".join(errors))


def unknown_paths(values, defaults, prefix=""):
    bad = []
    for k, v in values.items():
        path = prefix + k
        if k not in defaults:
            bad.append(path)
        elif isinstance(v, dict) and isinstance(defaults[k], dict):
            bad += unknown_paths(v, defaults[k], path + ".")
    return bad


# ---------------------------------------------------------------- Lua output

def lua_str(s):
    out = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
    return f'"{out}"'


IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LUA_KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
                "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"}


def to_lua(v, indent=0):
    pad = "  " * indent
    pad1 = "  " * (indent + 1)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        r = repr(v)
        return r if ("." in r or "e" in r) else r + ".0"
    if isinstance(v, str):
        return lua_str(v)
    if v is None:
        return "nil"
    if isinstance(v, list):
        if not v:
            return "{}"
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(to_lua(x) for x in v) + " }"
        return "{\n" + "".join(f"{pad1}{to_lua(x, indent + 1)},\n" for x in v) + pad + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        lines = []
        for k, x in v.items():
            key = k if (IDENT.match(k) and k not in LUA_KEYWORDS) else f"[{lua_str(k)}]"
            lines.append(f"{pad1}{key} = {to_lua(x, indent + 1)},\n")
        return "{\n" + "".join(lines) + pad + "}"
    raise BuildError(f"cannot convert {type(v)} to Lua")


def equip_text(job):
    """English list of a job's main-job proficiencies ("" when it has none)."""
    return ", ".join(PROFICIENCIES[p] for p in job.get("equip", []))


def unlock_req(r):
    """One unlock requirement for Rules.RequirementsMet: a badge, a kill count, a mastered job or a job level."""
    if "badge" in r:
        return {"Badge": r["badge"]}
    if "kills" in r:
        return {"Kills": r["kills"]}
    if r.get("mastered"):
        return {"Job": r["job"], "Mastered": True}
    return {"Job": r["job"], "Level": r["level"]}


def build_lua(jobs_doc, config_doc):
    jobs = {}
    art = set(art_keys())
    for i, j in enumerate(jobs_doc["jobs"]):
        jobs[j["id"]] = {
            "Id": j["id"], "Name": j["name"], "Skillset": j.get("skillset", ""), "Group": j.get("group", ""),
            "Implemented": bool(j.get("implemented")), "Order": i + 1,
            "Unlock": [unlock_req(r) for r in j.get("unlock", [])],
            "Innate": {k.capitalize(): v for k, v in j.get("innate", {}).items()},
            "Equip": equip_text(j),
            "Description": j.get("description", ""),
            # passives the main job gives by its job level, highest tier reached (Onion Knight)
            "LevelGrants": [{"Level": t["level"], "Grants": {k.capitalize(): v for k, v in t.items() if k in GRANT_KINDS}}
                            for t in j.get("levelGrants", [])],
            # while it is the main job, no slot or secondary works (Onion Knight; config Rules.OnionKnightBlocksSlots)
            "NoSlots": bool(j.get("noSlots")),
        }
        # the job's emblem in our icon atlas (art\icons\Job_<JobId>), shown on the Job Board even before it is built
        if "Job_" + j["id"] in art:
            jobs[j["id"]]["Emblem"] = ICON_PREFIX + "Job_" + j["id"]
        if j.get("mastery"):
            jobs[j["id"]]["Mastery"] = {
                "Description": j["mastery"]["description"],
                "Grants": {k.capitalize(): v for k, v in j["mastery"].items() if k in GRANT_KINDS},
            }
    badges = {b["id"]: {"Id": b["id"], "Name": b["name"], "Description": b["description"]}
              for b in jobs_doc.get("badges", [])}
    abilities = {}
    by_job = {j["id"]: [] for j in jobs_doc["jobs"] if j.get("implemented")}
    for i, a in enumerate(jobs_doc["abilities"]):
        entry = {
            "Id": a["id"], "Job": a["job"], "Type": a["type"], "Name": a["name"], "Cost": a["cost"],
            "Order": i + 1, "Description": a["description"],
            "Grants": {k.capitalize(): v for k, v in a["grants"].items()},
        }
        if a.get("effect"):
            entry["Effect"] = a["effect"]
        if a.get("fft"):
            entry["Fft"] = a["fft"]
        if a.get("variants"):
            entry["Variants"] = [{
                "When": {"AnyOf": [{k[0].upper() + k[1:]: val for k, val in c.items()} for c in v["when"]["anyOf"]]},
                "Grants": {k.capitalize(): val for k, val in v["grants"].items()},
            } for v in a["variants"]]
        abilities[a["id"]] = entry
        by_job[a["job"]].append(a["id"])
    echo = {sid: {"Spell": sid + ECHO_SUFFIX, "Ability": aid} for sid, aid in echo_spells(jobs_doc).items()}
    presets = {name: {"Description": p.get("description", ""), "Values": p["values"]}
               for name, p in config_doc["presets"].items()}
    data = {
        "ModUUID": MOD_UUID,
        "ModVersion": MOD_VERSION,
        "JobBoardSpell": JOB_BOARD_SPELL,
        "TrainingSpell": TRAINING_SPELL,
        "AbilityTypes": list(ABILITY_TYPES),
        "SlotOfType": SLOT_OF_TYPE,
        "Jobs": jobs,
        "JobOrder": [j["id"] for j in jobs_doc["jobs"]],
        "Abilities": abilities,
        "AbilityOrder": [a["id"] for a in jobs_doc["abilities"]],
        "AbilitiesByJob": by_job,
        "Badges": badges,
        "BadgeOrder": [b["id"] for b in jobs_doc.get("badges", [])],
        "Echo": echo,
        "ArithMagicks": {aid: sid + ARITH_SUFFIX for aid, sid in arith_magicks(jobs_doc).items()},
        "ArithRules": ARITH_RULES,
        "ConfigDefaults": config_doc["defaults"],
        "Presets": presets,
        "PresetOrder": list(config_doc["presets"].keys()),
        "DefaultPreset": config_doc["defaultPreset"],
        "ConfigHelp": config_doc.get("help", {}),
    }
    return ("-- GENERATED by tools/build.py from data/*.json. Do not edit by hand; edit data/ and rebuild.\n"
            "return " + to_lua(data) + "\n")


# ---------------------------------------------------------------- localization

NS = uuid.UUID(MOD_UUID)


def handle_for(key):
    h = uuid.uuid5(NS, key).hex
    return f"h{h[0:8]}g{h[8:12]}g{h[12:16]}g{h[16:20]}g{h[20:32]}"


def string_table(jobs_doc, strings_doc):
    table = {}
    for a in jobs_doc["abilities"]:
        table[f"ability.{a['id']}.name"] = a["name"]
        table[f"ability.{a['id']}.desc"] = a["description"]
        table[f"ability.{a['id']}.echo_name"] = f"Echo: {a['name']}"
        table[f"ability.{a['id']}.arith_name"] = f"Arithmeticks: {a['name']}"
    board = strings_doc["strings"]["JobPassive.Desc"]
    for j in jobs_doc["jobs"]:
        if j.get("implemented"):
            equip = equip_text(j)
            equip = f" Equipment: {equip} (proficiency while this is your job)." if equip else ""
            table[f"job.{j['id']}.passive_name"] = f"Job: {j['name']}"
            table[f"job.{j['id']}.passive_desc"] = f"{j.get('description', '')}{equip} {board}".strip()
            if j.get("mastery"):
                table[f"job.{j['id']}.mastery_name"] = f"{j['name']} Mastery"
                table[f"job.{j['id']}.mastery_desc"] = (f"{j['mastery']['description']} Earned by mastering "
                                                        f"{j['name']}; kept after changing jobs.")
    for k, v in strings_doc["strings"].items():
        table[f"str.{k}"] = v
    return table


PLACEHOLDER = re.compile(r"\{\{(name|desc|jobname|jobdesc|masteryname|masterydesc|str):([^}]+)\}\}")
KEY_OF = {"name": "ability.{}.name", "desc": "ability.{}.desc", "jobname": "job.{}.passive_name",
          "jobdesc": "job.{}.passive_desc", "masteryname": "job.{}.mastery_name",
          "masterydesc": "job.{}.mastery_desc", "str": "str.{}"}
# {{prof:<JobId>}} -> the job's equip list as Proficiency() boosts (plain stats text, not a string handle).
PROF_PLACEHOLDER = re.compile(r"\{\{prof:([^}]+)\}\}")

# Geomancy, "terrain decides" (user): {{terrain:<Key>[|<Key>...]}} -> a condition that is true while the caster
# (context.Source) stands on one of those terrains. Surface names are the ones vanilla conditions use (InSurface).
TERRAIN_SURFACES = {
    "Water": ["SurfaceWater", "SurfaceWaterElectrified", "SurfaceDeepWater", "SurfaceDeepWaterRunning"],
    "Ice": ["SurfaceWaterFrozen", "SurfaceBloodFrozen"],
    "Fire": ["SurfaceFire", "SurfaceHellfire", "SurfaceLava"],
    "Swamp": ["SurfaceMud", "SurfaceBlood", "SurfaceAcid", "SurfacePoison", "SurfaceCausticBrine",
              "SurfaceSerpentVenom", "SurfaceWyvernPoison", "SurfacePurpleWormPoison"],
    "Plants": ["SurfaceVines", "SurfaceOvergrowth", "SurfaceWeb"],
    "Oil": ["SurfaceGrease", "SurfaceOil", "SurfaceAlcohol"],
}
TERRAIN_PLACEHOLDER = re.compile(r"\{\{terrain:([^}]+)\}\}")


def in_surfaces(names):
    return " or ".join(f"InSurface('{s}',context.Source)" for s in names)


def terrain_condition(key):
    if key == "Plain":  # no Geomancy surface under you
        return "not (" + in_surfaces([s for group in TERRAIN_SURFACES.values() for s in group]) + ")"
    if key == "Sunlight":
        return "IsInSunlight(context.Source)"
    if key == "Shadow":
        return ("HasObscuredState(ObscuredState.LightlyObscured,context.Source) or "
                "HasObscuredState(ObscuredState.HeavilyObscured,context.Source)")
    if key == "Water":  # rain counts: it leaves you Wet
        return in_surfaces(TERRAIN_SURFACES["Water"]) + " or HasStatus('WET',context.Source)"
    if key in TERRAIN_SURFACES:
        return in_surfaces(TERRAIN_SURFACES[key])
    raise BuildError(f"unknown terrain {key!r}")


def terrain(m):
    return "(" + " or ".join(f"({terrain_condition(k)})" for k in m.group(1).split("|")) + ")"


def xml_escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# ---------------------------------------------------------------- stats

ENTRY_RE = re.compile(r'^new entry "([^"]+)"')
TYPE_RE = re.compile(r'^type "([^"]+)"')
USING_RE = re.compile(r'^using "([^"]+)"')
DATA_RE = re.compile(r'^data "([^"]+)" "(.*)"$')
TARGET_WORDS = {"SELF", "TARGET", "SOURCE", "SWAP", "OBSERVER_SOURCE", "OBSERVER_TARGET", "OBSERVER_OBSERVER",
                "CASTER", "OWNER"}


def parse_stats(text, filename):
    entries = []
    cur = None
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("//"):
            continue
        m = ENTRY_RE.match(line)
        if m:
            cur = {"name": m.group(1), "type": None, "using": None, "data": [], "file": filename, "line": lineno}
            entries.append(cur)
            continue
        if cur is None:
            raise BuildError(f"{filename}:{lineno}: line before the first entry: {line}")
        m = TYPE_RE.match(line)
        if m:
            cur["type"] = m.group(1)
            continue
        m = USING_RE.match(line)
        if m:
            cur["using"] = m.group(1)
            continue
        m = DATA_RE.match(line)
        if m:
            cur["data"].append((m.group(1), m.group(2)))
            continue
        raise BuildError(f"{filename}:{lineno}: cannot parse: {line}")
    return entries


def status_refs(value):
    refs = set()
    for fn in ("ApplyStatus", "RemoveStatus"):
        for m in re.finditer(fn + r"\(([^)]*)\)", value):
            args = [a.strip() for a in m.group(1).split(",")]
            for a in args:
                if a and a not in TARGET_WORDS and re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", a):
                    refs.add(a)
                    break
    for m in re.finditer(r"HasStatus\('([^']+)'", value):
        refs.add(m.group(1))
    return refs


# ---------------------------------------------------------------- icons

def art_keys():
    """Keys that have a picture (.jpg, or .png) in art/icons, sorted (the atlas order)."""
    if not ART_DIR.is_dir():
        return []
    return sorted({p.stem for ext in ("*.jpg", "*.png") for p in ART_DIR.glob(ext)})


def icon_keys(jobs_doc, entries):
    """Stats entry name -> icon key: the ability that grants it (variants included), Job_<JobId> for the job marker
    passives, JobBoard / JPTraining, and for a status the ability whose entries apply it (abilities in data order,
    so an action wins over the passive that reuses its status, e.g. Regen over Regenerate)."""
    keys = {JOB_BOARD_SPELL: "JobBoard", TRAINING_SPELL: "JPTraining"}
    for j in jobs_doc["jobs"]:
        if j.get("implemented"):
            for pid in j.get("innate", {}).get("passives", []) + j.get("mastery", {}).get("passives", []):
                keys.setdefault(pid, "Job_" + j["id"])
    granted = []
    for a in jobs_doc["abilities"]:
        for g in [a["grants"]] + [v["grants"] for v in a.get("variants", [])]:
            for kind in GRANT_KINDS:
                for sid in g.get(kind, []):
                    keys.setdefault(sid, a["id"])
                    granted.append((sid, a["id"]))
    by_name = {e["name"]: e for e in entries}
    for sid, aid in granted:
        for _, value in by_name.get(sid, {}).get("data", []):
            for st in status_refs(value):
                keys.setdefault(st, aid)
    return keys


def inject_icons(text, keys, art):
    """Gives every entry whose icon key has a picture `data "Icon" "FFTJ_Icon_<key>"` (replacing a borrowed vanilla
    icon, or added after its type/using lines)."""
    out = []
    pending = None  # icon still to add for the current entry

    def flush():
        nonlocal pending
        if pending:
            # after the type/using header lines of the entry
            i = len(out)
            while i > 0 and not out[i - 1].startswith(("new entry", "type ", "using ")):
                i -= 1
            out.insert(i, f'data "Icon" "{pending}"')
            pending = None

    for line in text.split("\n"):
        m = ENTRY_RE.match(line)
        if m:
            flush()
            key = keys.get(m.group(1))
            pending = ICON_PREFIX + key if key in art else None
        elif pending and line.startswith('data "Icon" '):
            line = f'data "Icon" "{pending}"'
            pending = None
        elif line == "" and pending:
            flush()
        out.append(line)
    flush()
    return "\n".join(out)


def atlas_uv(index):
    """UVs of atlas cell index (row-major), half a pixel inside the cell like vanilla."""
    per_row = ATLAS_SIZE // ATLAS_CELL
    x, y = (index % per_row) * ATLAS_CELL, (index // per_row) * ATLAS_CELL
    s = float(ATLAS_SIZE)
    return (x + 0.5) / s, (x + ATLAS_CELL - 0.5) / s, (y + 0.5) / s, (y + ATLAS_CELL - 0.5) / s


def atlas_uuid():
    return str(uuid.uuid5(NS, "atlas:" + ATLAS_NAME))


def build_atlas_lsx(art):
    if len(art) > (ATLAS_SIZE // ATLAS_CELL) ** 2:
        raise BuildError(f"{len(art)} icons do not fit a {ATLAS_SIZE} px atlas")
    lines = ['<?xml version="1.0" encoding="UTF-8"?>', "<save>",
             '    <version major="4" minor="6" revision="0" build="700"/>',
             '    <region id="IconUVList">', '        <node id="root">', "            <children>"]
    for i, key in enumerate(art):
        u1, u2, v1, v2 = atlas_uv(i)
        lines += ['                <node id="IconUV">',
                  f'                    <attribute id="MapKey" type="FixedString" value="{ICON_PREFIX}{key}"/>',
                  f'                    <attribute id="U1" type="float" value="{u1:.8f}"/>',
                  f'                    <attribute id="U2" type="float" value="{u2:.8f}"/>',
                  f'                    <attribute id="V1" type="float" value="{v1:.8f}"/>',
                  f'                    <attribute id="V2" type="float" value="{v2:.8f}"/>',
                  "                </node>"]
    lines += ["            </children>", "        </node>", "    </region>",
              '    <region id="TextureAtlasInfo">', '        <node id="root">', "            <children>",
              '                <node id="TextureAtlasIconSize">',
              f'                    <attribute id="Height" type="int32" value="{ATLAS_CELL}"/>',
              f'                    <attribute id="Width" type="int32" value="{ATLAS_CELL}"/>',
              "                </node>",
              '                <node id="TextureAtlasPath">',
              f'                    <attribute id="Path" type="string" value="Assets/Textures/Icons/{ATLAS_NAME}.dds"/>',
              f'                    <attribute id="UUID" type="FixedString" value="{atlas_uuid()}"/>',
              "                </node>",
              '                <node id="TextureAtlasTextureSize">',
              f'                    <attribute id="Height" type="int32" value="{ATLAS_SIZE}"/>',
              f'                    <attribute id="Width" type="int32" value="{ATLAS_SIZE}"/>',
              "                </node>",
              "            </children>", "        </node>", "    </region>", "</save>"]
    return "\n".join(lines) + "\n"


def build_texture_bank():
    """The atlas texture's resource (vanilla: Public/SharedDev/Content/UI/[PAK]_UI/_merged.lsf); packaging converts
    this .lsx to .lsf."""
    attrs = [("Depth", "int32", "1"), ("Height", "int32", str(ATLAS_SIZE)), ("ID", "FixedString", atlas_uuid()),
             ("Localized", "bool", "False"), ("Name", "LSString", ATLAS_NAME), ("SRGB", "bool", "False"),
             ("SourceFile", "LSString", f"Public/{MOD_FOLDER}/Assets/Textures/Icons/{ATLAS_NAME}.dds"),
             ("Streaming", "bool", "True"), ("Template", "FixedString", ATLAS_NAME), ("Type", "int32", "1"),
             ("Width", "int32", str(ATLAS_SIZE))]
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<save>",
             '\t<version major="4" minor="0" revision="9" build="0" lslib_meta="v1,bswap_guids,lsf_adjacency" />',
             '\t<region id="TextureBank">', '\t\t<node id="TextureBank">', "\t\t\t<children>",
             '\t\t\t\t<node id="Resource">']
    lines += [f'\t\t\t\t\t<attribute id="{a}" type="{t}" value="{v}" />' for a, t, v in attrs]
    lines += ["\t\t\t\t</node>", "\t\t\t</children>", "\t\t</node>", "\t</region>", "</save>"]
    return "\n".join(lines) + "\n"


# Mime, Echo (user's design): on its turn a Mime may repeat the last job ability an ally used since its previous turn,
# ignoring that ability's cooldown. Every action spell of the other implemented jobs gets a "<spell>_Echo" twin without
# a cooldown, named "Echo: <ability>"; the server hands the right twin to the Mime for one turn (Server/Service.lua).
ECHO_SUFFIX = "_Echo"
ECHO_FILE = "Spell_FFTJ_Echo.txt"


def echo_spells(jobs_doc):
    """spell id -> ability id, for the action spells (grants and variants) of implemented jobs other than the Mime."""
    implemented = {j["id"] for j in jobs_doc["jobs"] if j.get("implemented") and j["id"] != "Mime"}
    out = {}
    for a in jobs_doc["abilities"]:
        if a["job"] in implemented and a["type"] == "Action":
            for g in [a["grants"]] + [v["grants"] for v in a.get("variants", [])]:
                for sid in g.get("spells", []):
                    out.setdefault(sid, a["id"])
    return out


def echo_stats(jobs_doc, entries, used):
    by_name = {e["name"]: e for e in entries}

    def spell_type(name):
        while name in by_name:
            e = by_name[name]
            for key, value in e["data"]:
                if key == "SpellType":
                    return value
            name = e["using"]
        raise BuildError(f"echo: no SpellType for {name}")

    lines = []
    for sid, aid in echo_spells(jobs_doc).items():
        if sid not in by_name:
            continue  # check_stats reports the missing grant
        key = f"ability.{aid}.echo_name"
        used.add(key)
        lines += [f'new entry "{sid}{ECHO_SUFFIX}"', 'type "SpellData"', f'data "SpellType" "{spell_type(sid)}"',
                  f'using "{sid}"', 'data "Cooldown" ""', f'data "DisplayName" "{handle_for(key)};1"', ""]
    return "\n".join(lines).rstrip("\n") + "\n"


# Arithmetician (user's design): it loads one learned magick of these jobs (a spell aimed at a creature: by our naming,
# a Target_ or Projectile_ spell) and a number on the Job Board; a rule shout then makes the server cast the magick's
# "<spell>_Arith" twin (free, no cooldown, one creature, any creature, long range) at every creature whose number fits.
ARITH_JOBS = ("WhiteMage", "BlackMage", "TimeMage", "Mystic")
ARITH_SUFFIX = "_Arith"
ARITH_FILE = "Spell_FFTJ_Arith.txt"
ARITH_RULES = {"Shout_FFTJ_Arith_Prime": "Prime", "Shout_FFTJ_Arith_MultipleOf5": "5",
               "Shout_FFTJ_Arith_MultipleOf4": "4", "Shout_FFTJ_Arith_MultipleOf3": "3"}


def arith_magicks(jobs_doc):
    """ability id -> its first creature-aimed spell, for the magicks an Arithmetician can load."""
    out = {}
    for a in jobs_doc["abilities"]:
        if a["job"] in ARITH_JOBS and a["type"] == "Action":
            spells = [s for s in a["grants"].get("spells", []) if s.startswith(("Target_", "Projectile_"))]
            if spells:
                out[a["id"]] = spells[0]
    return out


def arith_stats(jobs_doc, used):
    lines = []
    for aid, sid in arith_magicks(jobs_doc).items():
        key = f"ability.{aid}.arith_name"
        used.add(key)
        typ = "Target" if sid.startswith("Target_") else "Projectile"
        lines += [f'new entry "{sid}{ARITH_SUFFIX}"', 'type "SpellData"', f'data "SpellType" "{typ}"', f'using "{sid}"',
                  'data "UseCosts" ""', 'data "Cooldown" ""', 'data "RequirementConditions" ""',
                  'data "TargetConditions" "not Dead()"', 'data "TargetRadius" "40"', 'data "AreaRadius" "0"']
        if typ == "Projectile":
            lines += ['data "ExplodeRadius" "0"']
        lines += [f'data "DisplayName" "{handle_for(key)};1"', ""]
    return "\n".join(lines).rstrip("\n") + "\n"


def build_stats(jobs_doc, strings_doc):
    table = string_table(jobs_doc, strings_doc)
    used = set()
    outputs = {}
    entries = []
    if not STATS_SRC.is_dir():
        return outputs, table, used, entries
    job_by_id = {j["id"]: j for j in jobs_doc["jobs"]}
    for src in sorted(STATS_SRC.glob("*.txt")):

        def repl(m):
            key = KEY_OF[m.group(1)].format(m.group(2))
            if key not in table:
                raise BuildError(f"{src.name}: unknown string {m.group(0)}")
            used.add(key)
            return handle_for(key) + ";1"

        def prof(m):
            job = job_by_id.get(m.group(1))
            if not job or not job.get("equip"):
                raise BuildError(f"{src.name}: {m.group(0)}: no such job or it has no equip list")
            return ";".join(f"Proficiency({p})" for p in job["equip"])

        # Comments stay in stats_src only: the generated file holds plain stats lines (the game's parser
        # is not known to accept comments), with one blank line between entries.
        lines = []
        for raw in src.read_text(encoding="utf-8").splitlines():
            line = raw.rstrip()
            if line.lstrip().startswith("//"):
                continue
            if line.startswith("new entry") and lines and lines[-1] != "":
                lines.append("")
            if line or (lines and lines[-1] != ""):
                lines.append(PLACEHOLDER.sub(repl, PROF_PLACEHOLDER.sub(prof, TERRAIN_PLACEHOLDER.sub(terrain, line))))
        while lines and lines[-1] == "":
            lines.pop()
        out = "\n".join(lines) + "\n"
        if "{{" in out:
            raise BuildError(f"{src.name}: unresolved placeholder")
        outputs[STATS_OUT / src.name] = out
        entries += parse_stats(out, src.name)
    for name, out in ((ECHO_FILE, echo_stats(jobs_doc, entries, used)), (ARITH_FILE, arith_stats(jobs_doc, used))):
        outputs[STATS_OUT / name] = out
        entries += parse_stats(out, name)
    art = set(art_keys())
    if art:
        keys = icon_keys(jobs_doc, entries)
        entries = []
        for path in list(outputs):
            outputs[path] = inject_icons(outputs[path], keys, art)
            entries += parse_stats(outputs[path], path.name)
    return outputs, table, used, entries


def check_stats(jobs_doc, entries):
    errors = []
    defined = {}
    for e in entries:
        if e["name"] in defined:
            errors.append(f"duplicate stats entry {e['name']}")
        defined[e["name"]] = e
        if not e["type"]:
            errors.append(f"{e['name']}: no type")
    wanted = {JOB_BOARD_SPELL: "SpellData", TRAINING_SPELL: "SpellData"}
    for a in jobs_doc["abilities"]:
        for g in [a["grants"]] + [v["grants"] for v in a.get("variants", [])]:
            for sid in g.get("spells", []):
                wanted[sid] = "SpellData"
            for pid in g.get("passives", []):
                wanted[pid] = "PassiveData"
            for st in g.get("statuses", []):
                wanted[st] = "StatusData"
    for j in jobs_doc["jobs"]:
        if j.get("implemented"):
            for pid in j.get("innate", {}).get("passives", []):
                wanted[pid] = "PassiveData"
            for kind, typ in (("spells", "SpellData"), ("passives", "PassiveData"), ("statuses", "StatusData")):
                for sid in j.get("mastery", {}).get(kind, []):
                    wanted[sid] = typ
    for sid, typ in wanted.items():
        if "FFTJ" not in sid:
            continue
        if sid not in defined:
            errors.append(f"granted {typ} {sid} has no stats entry")
        elif defined[sid]["type"] != typ:
            errors.append(f"{sid}: expected type {typ}, stats has {defined[sid]['type']}")
    refs = {}

    def add(ref, kind, where):
        refs.setdefault((ref, kind), set()).add(where)

    art = set(art_keys())
    for e in entries:
        if e["using"] and e["using"] not in defined:
            add(e["using"], "using parent (" + (e["type"] or "?") + ")", e["name"])
        for key, value in e["data"]:
            if key == "Icon" and value.startswith(ICON_PREFIX):
                if value[len(ICON_PREFIX):] not in art:
                    errors.append(f"{e['name']}: icon {value} has no picture in art/icons")
            elif key == "Icon" and value:
                add(value, "icon", e["name"])
            for st in status_refs(value):
                if st not in defined:
                    add(st, "status", e["name"])
                elif defined[st]["type"] != "StatusData":
                    errors.append(f"{e['name']}: {st} is used as a status but is {defined[st]['type']}")
    if errors:
        raise BuildError("stats errors:\n  " + "\n  ".join(errors))
    return refs


def refs_outputs(refs):
    rows = sorted(refs.items(), key=lambda kv: (kv[0][1], kv[0][0]))
    md = ["# Vanilla IDs the stats drafts rely on",
          "",
          "GENERATED by `tools/build.py`. Part B: check each against the extracted game data",
          "(`python tools/validate_vanilla.py <extracted Shared+Gustav root>`), then fix `stats_src/` and rebuild.",
          "",
          "| ID | Kind | Used by |",
          "|---|---|---|"]
    for (ref, kind), where in rows:
        md.append(f"| `{ref}` | {kind} | {', '.join(sorted(where))} |")
    js = [{"id": ref, "kind": kind, "usedBy": sorted(where)} for (ref, kind), where in rows]
    return "\n".join(md) + "\n", json.dumps(js, indent=2) + "\n"


def build_loca(table, used):
    keys = sorted(used)
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<contentList>"]
    for key in keys:
        lines.append(f'  <content contentuid="{handle_for(key)}" version="1">{xml_escape(table[key])}</content>')
    lines.append("</contentList>")
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- main

def main(argv):
    check = "--check" in argv
    jobs_doc = load_json("fft_jobs.json")
    config_doc = load_json("config_defaults.json")
    strings_doc = load_json("strings.json")
    validate(jobs_doc, config_doc, strings_doc)

    outputs = {LUA_OUT: build_lua(jobs_doc, config_doc)}
    stats_outputs, table, used, entries = build_stats(jobs_doc, strings_doc)
    if stats_outputs:
        refs = check_stats(jobs_doc, entries)
        outputs.update(stats_outputs)
        outputs[LOCA_OUT] = build_loca(table, used)
        md, js = refs_outputs(refs)
        outputs[REFS_MD] = md
        outputs[REFS_JSON] = js
        art = art_keys()
        if art:
            outputs[ATLAS_LSX] = build_atlas_lsx(art)
            outputs[TEXTURE_BANK] = build_texture_bank()

    stale = []
    for path, content in outputs.items():
        if check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                stale.append(path.relative_to(ROOT))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    if check:
        if stale:
            print("stale generated files (run python3 tools/build.py):")
            for p in stale:
                print("  " + str(p))
            return 1
        print(f"build check OK ({len(outputs)} generated files up to date)")
        return 0
    n_ab = len(jobs_doc["abilities"])
    n_impl = sum(1 for j in jobs_doc["jobs"] if j.get("implemented"))
    print(f"built {len(outputs)} files: {n_impl} implemented jobs, {n_ab} abilities, "
          f"{len(entries)} stats entries, {len(used)} strings, {len(art_keys())} icons")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BuildError as e:
        print("BUILD FAILED: " + str(e))
        sys.exit(1)
