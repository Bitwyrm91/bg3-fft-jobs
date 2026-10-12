#!/usr/bin/env python3
"""Shows vanilla BG3 spells from the extracted game data, with every field resolved through the `using` chain, so a
spell's look (animation, effects, projectile) can be compared and copied.

Usage: python tools/vanilla_spell.py <extracted-root> <SpellName> [<SpellName> ...] [--visual]
       python tools/vanilla_spell.py <extracted-root> --find <text>      spell names containing <text>
  --visual  only the fields that make up the look (VISUAL_FIELDS below)
<extracted-root> is the folder validate_vanilla.py uses (e.g. C:\\Users\\berus\\GameModding\\decomp\\bg3).
"""
import re
import sys
from pathlib import Path

VISUAL_FIELDS = (
    "SpellAnimation", "SpellAnimationIntentType", "PrepareEffect", "PrepareSound", "PrepareLoopSound", "CastEffect",
    "CastSound", "CastTextEvent", "TargetEffect", "TargetSound", "TargetHitEffect", "PositionEffect", "BeamEffect",
    "HitEffect", "HitAnimationType", "ImpactEffect", "ReappearEffect", "DisappearEffect", "Trajectories",
    "ProjectileCount", "ProjectileDelay", "ProjectileTerrainOffset", "SpellStyleGroup", "VerbalIntent",
    "SpellSoundMagnitude", "SpellSoundAftertrigger", "WeaponTypes", "SpellJumpType", "AreaEffect",
    "Icon", "TooltipAttackSave",
)
ENTRY = re.compile(r'^new entry "([^"]+)"')
USING = re.compile(r'^using "([^"]+)"')
DATA = re.compile(r'^data "([^"]+)" "(.*)"$')
TYPE = re.compile(r'^type "([^"]+)"')


def load(root):
    entries = {}
    for f in sorted(Path(root).rglob("Spell_*.txt")):
        if "Stats" not in f.parts or "Generated" not in f.parts:
            continue
        cur = None
        for raw in f.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip()
            m = ENTRY.match(line)
            if m:
                cur = {"name": m.group(1), "using": None, "data": {}, "type": None, "file": f.name}
                entries[cur["name"]] = cur  # later files (patches) override earlier ones
                continue
            if cur is None:
                continue
            m = USING.match(line)
            if m:
                cur["using"] = m.group(1)
                continue
            m = TYPE.match(line)
            if m:
                cur["type"] = m.group(1)
                continue
            m = DATA.match(line)
            if m:
                cur["data"][m.group(1)] = m.group(2)
    return entries


def resolved(entries, name):
    """Fields of name with inherited ones filled in; each value is (value, the entry it comes from)."""
    chain, seen = [], set()
    while name and name in entries and name not in seen:
        seen.add(name)
        chain.append(entries[name])
        name = entries[name]["using"]
    out = {}
    for e in reversed(chain):
        for k, v in e["data"].items():
            out[k] = (v, e["name"])
    return out, [e["name"] for e in chain]


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    entries = load(argv[0])
    if argv[1] == "--find":
        text = argv[2].lower()
        for name in sorted(entries):
            if text in name.lower():
                print(name)
        return 0
    visual = "--visual" in argv
    for name in [a for a in argv[1:] if not a.startswith("--")]:
        if name not in entries:
            print(f"== {name}: not found")
            continue
        fields, chain = resolved(entries, name)
        print(f"== {name}  ({' <- '.join(chain)})")
        for k in sorted(fields):
            if visual and k not in VISUAL_FIELDS:
                continue
            v, src = fields[k]
            where = "" if src == name else f"   [from {src}]"
            print(f"  {k} = {v}{where}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
