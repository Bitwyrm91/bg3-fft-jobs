#!/usr/bin/env python3
"""Soul Collector data vs the game: which soul type each level character gives, and whether each form's template exists.

Usage:  python -I tools/check_souls.py [--all]   (--all also lists every distinct match)

Reads data/souls.json and, from C:\\Users\\berus\\GameModding\\decomp\\bg3: root templates (rt/: RootTemplates/_merged.lsf
from Shared.pak and Gustav.pak, extracted with Divine and converted to .lsx), the level characters (levels/) and the
English loca (loca/english.xml). Each level character's keys are built the way Game:CreatureKeys builds them in game
(root template name + GUID, stats id, display name, lower case) and run through Souls.TypeOf's rules (boss GUIDs first,
then the match/exclude patterns in order). Prints the count per soul type, a sample per type, the distinct unmatched
characters (humanoids are not devourable by design) and every form template with its name and stats. Exit code 1 when a
form template is missing, not a character, or its stats' Vitality differs from the form's templateHp. Add the Act 2/3 levels to LEVELS when those souls are built.
"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
import xml.etree.ElementTree as ET

DEC = Path(r"C:\Users\berus\GameModding\decomp\bg3")
PROJ = Path(__file__).resolve().parent.parent
LEVELS = ["Mods/Gustav/Levels/TUT_Avernus_C", "Mods/Gustav/Levels/WLD_Main_A", "Mods/Gustav/Levels/WLD_UnderdarkSubs_C",
          "Mods/Gustav/Globals/TUT_Avernus_C", "Mods/Gustav/Globals/WLD_Main_A",
          "Mods/GustavDev/Levels/CRE_Main_A", "Mods/GustavDev/Globals/CRE_Main_A",
          "Mods/GustavDev/Levels/TUT_Avernus_C", "Mods/GustavDev/Levels/WLD_Main_A", "Mods/GustavDev/Globals/WLD_Main_A"]


def objs(path):
    """Attribute dicts of every GameObjects node."""
    for _, el in ET.iterparse(path, events=("end",)):
        if el.tag == "node" and el.get("id") == "GameObjects":
            a = {}
            for at in el.findall("attribute"):
                a[at.get("id")] = at.get("value") if at.get("value") is not None else at.get("handle")
            yield a
            el.clear()


def vitality_index():
    """Character stats name -> (using parent, Vitality) from every module, later modules overriding."""
    out = {}
    for mod in ("Shared/Public/Shared", "Shared/Public/SharedDev", "Gustav/Public/Gustav", "Gustav/Public/GustavDev",
                "GustavX/Public/GustavX"):
        f = DEC / mod / "Stats" / "Generated" / "Data" / "Character.txt"
        cur = None
        for line in (f.read_text(encoding="utf-8", errors="replace").splitlines() if f.exists() else []):
            m = re.match(r'new entry "([^"]+)"', line)
            if m:
                cur = out.setdefault(m.group(1), [None, None])
            elif cur is not None and line.startswith('using "'):
                cur[0] = line.split('"')[1]
            elif cur is not None and line.startswith('data "Vitality"'):
                cur[1] = int(line.split('"')[3])
    return out


def lua_to_re(p):
    """The few Lua pattern features souls.json uses, as a Python regex."""
    p = p.replace("%f[%a]", r"(?<![a-z])").replace("%f[%A]", r"(?![a-z])").replace("%-", r"\-")
    return re.compile(p)


def main(argv):
    rt = {}
    for f in (DEC / "rt").rglob("_merged.lsx"):
        for a in objs(f):
            if a.get("MapKey"):
                rt[a["MapKey"]] = a
    if not rt:
        print(f"no root templates under {DEC / 'rt'}")
        return 1
    loca = {}
    for _, el in ET.iterparse(DEC / "loca" / "english.xml", events=("end",)):
        if el.tag == "content":
            loca[el.get("contentuid")] = el.text or ""
            el.clear()

    def rt_attr(key, attr):
        t, depth = rt.get(key), 0
        while t is not None and depth < 12:
            if t.get(attr):
                return t[attr]
            t, depth = rt.get(t.get("ParentTemplateId") or ""), depth + 1
        return None

    doc = json.loads((PROJ / "data" / "souls.json").read_text(encoding="utf-8"))
    souls = [(s["id"], [lua_to_re(p) for p in s.get("match", [])], [lua_to_re(p) for p in s.get("exclude", [])])
             for s in doc["souls"]]
    by_guid = {g: s["id"] for s in doc["souls"] for g in s.get("guids", [])}

    def type_of(keys, guid):
        if guid in by_guid:
            return by_guid[guid]
        for sid, m, x in souls:
            if any(r.search(keys) for r in m) and not any(r.search(keys) for r in x):
                return sid
        return None

    rows = []
    for lv in LEVELS:
        f = DEC / "levels" / lv / "Characters" / "_merged.lsx"
        if not f.exists():
            continue
        for a in objs(f):
            guid, root = a.get("MapKey"), a.get("TemplateName")
            rname = rt_attr(root, "Name") or "?"
            stats = a.get("Stats") or rt_attr(root, "Stats") or ""
            dn = a.get("DisplayName") or rt_attr(root, "DisplayName") or ""
            name = loca.get(dn.split(";")[0], "")
            keys = f"{rname}_{root} {stats} {name}".lower()
            rows.append((a.get("Name"), rname, stats, name, type_of(keys, guid)))

    print("level characters:", len(rows))
    for k, v in Counter(r[4] for r in rows).most_common():
        print(f"  {k}: {v}")
    print("\n== sample per type (level name | root | stats | display)")
    seen = defaultdict(set)
    for r in rows:
        if r[4] and len(seen[r[4]]) < 4 and r[1:4] not in seen[r[4]]:
            seen[r[4]].add(r[1:4])
            print(f"  {r[4]:<18} {r[0]} | {r[1]} | {r[2]} | {r[3]}")
    if "--all" in argv:
        print("\n== matched, distinct (root | stats | display)")
        done = set()
        for r in rows:
            if r[4] and (r[4],) + r[1:4] not in done:
                done.add((r[4],) + r[1:4])
                print(f"  {r[4]:<18} {r[1]} | {r[2]} | {r[3]}")
    print("\n== unmatched, distinct (root | stats | display)")
    done = set()
    for r in rows:
        if r[4] is None and r[1:4] not in done:
            done.add(r[1:4])
            print(f"  {r[1]} | {r[2]} | {r[3]}")
    print("distinct unmatched:", len(done))
    print("\n== form templates (vanilla Vitality vs templateHp in souls.json)")
    vit = vitality_index()

    def vitality(stats, depth=0):
        e = vit.get(stats or "")
        while e is not None and depth < 20:
            if e[1] is not None:
                return e[1]
            e, depth = vit.get(e[0] or ""), depth + 1
        return None
    bad = 0
    for s in doc["souls"]:
        for side in "BF":
            t = s["forms"][side]["template"]
            hp = vitality(rt_attr(t, "Stats"))
            problem = ("NOT A CHARACTER TEMPLATE" if rt_attr(t, "Type") != "character" else
                       f"templateHp {s['forms'][side].get('templateHp')} but Vitality {hp}"
                       if s["forms"][side].get("templateHp") != hp else "")
            bad += 1 if problem else 0
            print(f"  {s['id']}{side} {t} -> {rt_attr(t, 'Name')} stats={rt_attr(t, 'Stats')} hp={hp}"
                  + (f"  <-- {problem}" if problem else ""))
    print(f"check_souls: {len(rows)} characters, {bad} form template problem(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
