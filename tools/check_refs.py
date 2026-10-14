#!/usr/bin/env python3
"""Cross-reference check of our stats against vanilla: every name our entries mention must exist.

Usage:  python tools/check_refs.py [<extracted-root>]   (default C:\\Users\\berus\\GameModding\\decomp\\bg3)

BG3 does not complain about a status, spell or parent that doesn't exist: the functor or boost silently does nothing
(a form that never appears, a skill that never shows up). This finds those names before a playtest:
  - `using` parents;
  - statuses in ApplyStatus / RemoveStatus / HasStatus / StatusImmunity, spells in UnlockSpell / ContainerSpells /
    SpellContainerID / UseSpell, passives in Passives / PassivesOnEquip / UnlockPassive;
  - LevelMapValue(...) names, ActionResource / UseCosts resources and SG_ status groups, compared with every name
    vanilla itself uses (the definitions are not in the extracted stats).
Exit code 1 when something is unknown. It never changes files.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUR_STATS = ROOT / "Mod" / "Public" / "FFTJobs" / "Stats" / "Generated" / "Data"
DEFAULT_VANILLA = Path(r"C:\Users\berus\GameModding\decomp\bg3")

ENTRY = re.compile(r'^\s*new entry "([^"]+)"')
TYPE = re.compile(r'^\s*type "([^"]+)"')
USING = re.compile(r'^\s*using "([^"]+)"')
DATA = re.compile(r'^\s*data "([^"]+)" "(.*)"\s*$')

TARGETS = {"SELF", "TARGET", "SOURCE", "SWAP", "OBSERVER_TARGET", "OBSERVER_SOURCE", "OBSERVER_OBSERVER", "CASTER",
           "ATTACKER", "AURA_SOURCE", "PARENT", "OWNER", "ALLY", "ENEMY"}
# statuses the engine makes itself (no stats entry)
ENGINE_STATUSES = {"DYING", "HEAL", "KNOCKED_DOWN", "LYING", "SMELLY", "SNEAKING", "SITTING", "UNLOCK", "TELEPORT_FALLING",
                   "MATERIAL", "CLIMBING", "DOWNED", "INSURFACE", "BOOST", "ROTATE", "STORY_FROZEN", "UNCONSCIOUS"}


def read(path):
    return path.read_text(encoding="utf-8", errors="replace").splitlines()


def parse(files):
    entries = {}
    for f in files:
        cur = None
        for line in read(f):
            m = ENTRY.match(line)
            if m:
                cur = {"name": m.group(1), "type": None, "using": None, "data": {}, "file": f.name}
                entries[cur["name"]] = cur
                continue
            if cur is None:
                continue
            m = TYPE.match(line)
            if m:
                cur["type"] = m.group(1)
                continue
            m = USING.match(line)
            if m:
                cur["using"] = m.group(1)
                continue
            m = DATA.match(line)
            if m:
                cur["data"][m.group(1)] = m.group(2)
    return entries


def args_of(text, func):
    """The argument strings of every call func(...) in text (nested parentheses kept)."""
    out = []
    for m in re.finditer(r"\b" + func + r"\(", text):
        depth, i = 1, m.end()
        while i < len(text) and depth:
            depth += {"(": 1, ")": -1}.get(text[i], 0)
            i += 1
        out.append(text[m.end():i - 1])
    return out


def split_args(s):
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
            continue
        depth += {"(": 1, ")": -1}.get(ch, 0)
        cur += ch
    parts.append(cur.strip())
    return parts


def ident(s):
    s = s.strip().strip("'\"")
    return s if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", s) else None


def refs(entry):
    """(kind, name) pairs one entry mentions."""
    out = []
    if entry["using"]:
        out.append(("parent", entry["using"]))
    for key, val in entry["data"].items():
        for a in args_of(val, "ApplyStatus"):
            for p in split_args(a):
                n = ident(p)
                if n and n not in TARGETS:
                    out.append(("status", n))
                    break
        for func in ("RemoveStatus", "HasStatus", "StatusImmunity", "HasAnyStatus"):
            for a in args_of(val, func):
                for p in split_args(a):
                    n = ident(p)
                    if n and n not in TARGETS and not n.startswith("context"):
                        out.append(("group" if n.startswith("SG_") else "status", n))
                        if func != "HasAnyStatus":
                            break
        for a in args_of(val, "UnlockSpell"):
            n = ident(split_args(a)[0])
            if n:
                out.append(("spell", n))
        for a in args_of(val, "UseSpell"):
            for p in split_args(a):
                n = ident(p)
                if n and n not in TARGETS:
                    out.append(("spell", n))
                    break
        for a in args_of(val, "UnlockPassive"):
            n = ident(split_args(a)[0])
            if n:
                out.append(("passive", n))
        for func, kind in (("HasPassive", "passive"), ("SpellId", "spell")):
            for a in args_of(val, func):
                n = ident(split_args(a)[0])
                if n:
                    out.append((kind, n))
        for a in args_of(val, "LevelMapValue"):
            n = ident(a)
            if n:
                out.append(("levelmap", n))
        for a in args_of(val, "ActionResource"):
            n = ident(split_args(a)[0])
            if n:
                out.append(("resource", n))
        if key in ("ContainerSpells",):
            out += [("spell", x) for x in val.split(";") if x.strip()]
        if key == "SpellContainerID" and val:
            out.append(("spell", val))
        if key in ("Passives", "PassivesOnEquip", "PassivesRemovedOnEquip") and val:
            out += [("passive", x.strip()) for x in val.split(";") if x.strip()]
        if key in ("UseCosts", "HitCosts", "DualWieldingUseCosts"):
            for part in val.split(";"):
                n = ident(part.split(":")[0])
                if n:
                    out.append(("resource", n))
        if key == "StatusGroups":
            out += [("group", x.strip()) for x in val.split(";") if x.strip()]
    return out


KIND_TYPES = {"status": ("StatusData",), "spell": ("SpellData",), "passive": ("PassiveData",)}


def main(argv):
    vroot = Path(argv[1]) if len(argv) > 1 else DEFAULT_VANILLA
    vfiles = [f for f in vroot.rglob("*.txt") if "Stats" in f.parts and "Data" in f.parts and "Generated" in f.parts]
    if not vfiles:
        print(f"no vanilla stats under {vroot}")
        return 1
    vanilla = parse(sorted(vfiles))
    ours = parse(sorted(OUR_STATS.glob("*.txt")))
    every = dict(vanilla)
    every.update(ours)
    # names vanilla itself uses (definitions live outside the stats)
    used = {"levelmap": set(), "resource": set(), "group": set()}
    for e in vanilla.values():
        for kind, name in refs(e):
            if kind in used:
                used[kind].add(name)
    # our status groups are defined by our statuses using them
    for e in ours.values():
        for g in e["data"].get("StatusGroups", "").split(";"):
            if g.strip():
                used["group"].add(g.strip())

    problems = []
    counts = {}
    for e in ours.values():
        for kind, name in refs(e):
            counts[kind] = counts.get(kind, 0) + 1
            if kind == "parent":
                if name not in every:
                    problems.append(f"{e['file']}: {e['name']}: parent {name} does not exist")
            elif kind in KIND_TYPES:
                target = every.get(name)
                if target is None:
                    if kind == "status" and name in ENGINE_STATUSES:
                        continue
                    problems.append(f"{e['file']}: {e['name']}: {kind} {name} does not exist")
                elif (target["type"] or "") not in KIND_TYPES[kind]:
                    problems.append(f"{e['file']}: {e['name']}: {name} is {target['type']}, not a {kind}")
            elif kind in used and name not in used[kind]:
                problems.append(f"{e['file']}: {e['name']}: {kind} {name} is not used anywhere in vanilla")
    for p in problems:
        print("PROBLEM:", p)
    summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    print(f"check_refs: {len(ours)} entries, references checked: {summary}; {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
