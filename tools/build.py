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
MOD_VERSION = "1.0.0.2"
JOB_BOARD_SPELL = "Shout_FFTJ_JobBoard"
TRAINING_SPELL = "Shout_FFTJ_JPTraining"
ABILITY_TYPES = ("Action", "Reaction", "Support", "Movement")
GRANT_KINDS = ("spells", "passives", "statuses")
SLOT_OF_TYPE = {"Reaction": "reaction", "Support": "support", "Movement": "movement"}

DATA_DIR = ROOT / "data"
STATS_SRC = ROOT / "stats_src"
LUA_OUT = ROOT / "Mod" / "Mods" / MOD_FOLDER / "ScriptExtender" / "Lua" / "Shared" / "GeneratedData.lua"
STATS_OUT = ROOT / "Mod" / "Public" / MOD_FOLDER / "Stats" / "Generated" / "Data"
LOCA_OUT = ROOT / "Mod" / "Localization" / "English" / f"{MOD_FOLDER}.xml"
REFS_MD = ROOT / "docs" / "vanilla_refs.md"
REFS_JSON = ROOT / "docs" / "vanilla_refs.json"


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
    for j in jobs:
        for req in j.get("unlock", []):
            if req["job"] not in job_by_id:
                errors.append(f"job {j['id']}: unknown required job {req['job']}")
            if not (1 <= req["level"] <= 8):
                errors.append(f"job {j['id']}: required level {req['level']} out of range")
            if j.get("implemented") and not job_by_id.get(req["job"], {}).get("implemented"):
                errors.append(f"job {j['id']} is implemented but requires unimplemented job {req['job']}")
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
                    elif key not in ("primaryJob", "equippedEffect", "equipped"):
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


def build_lua(jobs_doc, config_doc):
    jobs = {}
    for i, j in enumerate(jobs_doc["jobs"]):
        jobs[j["id"]] = {
            "Id": j["id"], "Name": j["name"], "Skillset": j.get("skillset", ""),
            "Implemented": bool(j.get("implemented")), "Order": i + 1,
            "Unlock": [{"Job": r["job"], "Level": r["level"]} for r in j.get("unlock", [])],
            "Innate": {k.capitalize(): v for k, v in j.get("innate", {}).items()},
            "Description": j.get("description", ""),
        }
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
        if a.get("variants"):
            entry["Variants"] = [{
                "When": {"AnyOf": [{k[0].upper() + k[1:]: val for k, val in c.items()} for c in v["when"]["anyOf"]]},
                "Grants": {k.capitalize(): val for k, val in v["grants"].items()},
            } for v in a["variants"]]
        abilities[a["id"]] = entry
        by_job[a["job"]].append(a["id"])
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
    board = strings_doc["strings"]["JobPassive.Desc"]
    for j in jobs_doc["jobs"]:
        if j.get("implemented"):
            table[f"job.{j['id']}.passive_name"] = f"Job: {j['name']}"
            table[f"job.{j['id']}.passive_desc"] = f"{j.get('description', '')} {board}".strip()
    for k, v in strings_doc["strings"].items():
        table[f"str.{k}"] = v
    return table


PLACEHOLDER = re.compile(r"\{\{(name|desc|jobname|jobdesc|str):([^}]+)\}\}")
KEY_OF = {"name": "ability.{}.name", "desc": "ability.{}.desc", "jobname": "job.{}.passive_name",
          "jobdesc": "job.{}.passive_desc", "str": "str.{}"}


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


def build_stats(jobs_doc, strings_doc):
    table = string_table(jobs_doc, strings_doc)
    used = set()
    outputs = {}
    entries = []
    if not STATS_SRC.is_dir():
        return outputs, table, used, entries
    for src in sorted(STATS_SRC.glob("*.txt")):

        def repl(m):
            key = KEY_OF[m.group(1)].format(m.group(2))
            if key not in table:
                raise BuildError(f"{src.name}: unknown string {m.group(0)}")
            used.add(key)
            return handle_for(key) + ";1"

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
                lines.append(PLACEHOLDER.sub(repl, line))
        while lines and lines[-1] == "":
            lines.pop()
        out = "\n".join(lines) + "\n"
        if "{{" in out:
            raise BuildError(f"{src.name}: unresolved placeholder")
        outputs[STATS_OUT / src.name] = out
        entries += parse_stats(out, src.name)
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

    for e in entries:
        if e["using"] and e["using"] not in defined:
            add(e["using"], "using parent (" + (e["type"] or "?") + ")", e["name"])
        for key, value in e["data"]:
            if key == "Icon" and value:
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
          f"{len(entries)} stats entries, {len(used)} strings")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except BuildError as e:
        print("BUILD FAILED: " + str(e))
        sys.exit(1)
