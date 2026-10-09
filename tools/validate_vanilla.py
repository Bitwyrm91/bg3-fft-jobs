#!/usr/bin/env python3
"""Part B: check the stats drafts against the game's extracted data.

Usage:  python tools/validate_vanilla.py <extracted-root> [<extracted-root> ...]

<extracted-root> is a folder with the unpacked game data (e.g. C:\\Users\\berus\\GameModding\\decomp\\bg3, holding
Shared.pak / Gustav.pak contents). The script searches it recursively for:
  - Stats/Generated/Data/*.txt         -> every vanilla stats entry and its type
  - Stats/Generated/Structure/Modifiers.txt (if present) -> valid "data" keys per stats type
  - *.lsx icon atlases (MapKey values) (if present)       -> valid icon names

It checks:
  1. every vanilla ID in docs/vanilla_refs.json exists, with the right type (using parents keep their child's type,
     statuses are StatusData);
  2. every `data "Key"` in our generated stats is a known attribute of that type (needs Modifiers.txt);
  3. none of our entry names overrides a vanilla entry by accident;
  4. icons exist (only when atlases were found).
Exit code 1 when something is wrong. It never changes files.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUR_STATS = ROOT / "Mod" / "Public" / "FFTJobs" / "Stats" / "Generated" / "Data"
REFS = ROOT / "docs" / "vanilla_refs.json"

ENTRY = re.compile(r'^\s*new entry "([^"]+)"')
TYPE = re.compile(r'^\s*type "([^"]+)"')
DATA = re.compile(r'^\s*data "([^"]+)"')
MOD_TYPE = re.compile(r'^\s*modifier type "([^"]+)"')
MOD_ATTR = re.compile(r'^\s*modifier "([^"]+)"')
MAPKEY = re.compile(r'id="MapKey"[^>]*value="([^"]+)"')


def read(path):
    return path.read_text(encoding="utf-8", errors="replace")


def index_stats(files):
    entries = {}
    for f in files:
        cur = None
        for line in read(f).splitlines():
            m = ENTRY.match(line)
            if m:
                cur = m.group(1)
                entries.setdefault(cur, None)
                continue
            m = TYPE.match(line)
            if m and cur:
                entries[cur] = m.group(1)
    return entries


def index_modifiers(files):
    attrs = {}
    for f in files:
        cur = None
        for line in read(f).splitlines():
            m = MOD_TYPE.match(line)
            if m:
                cur = m.group(1)
                attrs.setdefault(cur, set())
                continue
            m = MOD_ATTR.match(line)
            if m and cur:
                attrs[cur].add(m.group(1))
    return attrs


def our_entries():
    out = []
    for f in sorted(OUR_STATS.glob("*.txt")):
        cur = None
        for line in read(f).splitlines():
            m = ENTRY.match(line)
            if m:
                cur = {"name": m.group(1), "type": None, "keys": [], "file": f.name}
                out.append(cur)
                continue
            m = TYPE.match(line)
            if m and cur:
                cur["type"] = m.group(1)
            m = DATA.match(line)
            if m and cur:
                cur["keys"].append(m.group(1))
    return out


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    roots = [Path(a) for a in argv]
    for r in roots:
        if not r.is_dir():
            print(f"not a folder: {r}")
            return 2
    stats_files, modifier_files, lsx_files = [], [], []
    for r in roots:
        for p in r.rglob("*.txt"):
            parts = [x.lower() for x in p.parts]
            if "stats" in parts and "generated" in parts:
                if p.parent.name.lower() == "data":
                    stats_files.append(p)
                elif p.name.lower() == "modifiers.txt":
                    modifier_files.append(p)
        for p in r.rglob("*.lsx"):
            if "gui" in [x.lower() for x in p.parts] or "icons" in p.name.lower():
                lsx_files.append(p)
    vanilla = index_stats(stats_files)
    modifiers = index_modifiers(modifier_files)
    icons = set()
    for f in lsx_files:
        icons.update(MAPKEY.findall(read(f)))
    print(f"vanilla stats files: {len(stats_files)}, entries: {len(vanilla)}; Modifiers.txt: {len(modifier_files)}; "
          f"icon atlases: {len(lsx_files)} ({len(icons)} icons)")
    if not vanilla:
        print("no vanilla stats found: point the script at the folder with the extracted Shared/Gustav data")
        return 2

    problems = []
    ours = our_entries()
    our_types = {e["name"]: e["type"] for e in ours}
    refs = json.loads(read(REFS))
    for ref in refs:
        rid, kind = ref["id"], ref["kind"]
        if kind.startswith("using parent"):
            want = kind[kind.find("(") + 1:kind.find(")")]
            have = vanilla.get(rid, "MISSING")
            if have == "MISSING":
                problems.append(f"using parent {rid} does not exist (used by {', '.join(ref['usedBy'])})")
            elif have != want:
                problems.append(f"using parent {rid} is {have}, expected {want}")
        elif kind == "status":
            if rid not in vanilla:
                problems.append(f"status {rid} does not exist (used by {', '.join(ref['usedBy'])})")
            elif vanilla[rid] != "StatusData":
                problems.append(f"status {rid} is {vanilla[rid]}, not StatusData")
        elif kind == "icon":
            if icons and rid not in icons:
                problems.append(f"icon {rid} not found in the atlases (used by {', '.join(ref['usedBy'])})")
    for e in ours:
        if e["name"] in vanilla:
            problems.append(f"{e['name']} overrides a vanilla entry with the same name")
        if modifiers:
            valid = modifiers.get(e["type"])
            if valid is None:
                problems.append(f"{e['name']}: type {e['type']} not in Modifiers.txt")
            else:
                for k in e["keys"]:
                    if k not in valid:
                        problems.append(f"{e['name']}: data key {k} is not a {e['type']} attribute")
    if not modifiers:
        print("Modifiers.txt not found: data keys were not checked")
    if not icons:
        print("no icon atlases found: icons were not checked")
    if problems:
        print(f"{len(problems)} problem(s):")
        for p in problems:
            print("  - " + p)
        return 1
    print(f"OK: {len(refs)} vanilla references and {len(ours)} entries checked")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
