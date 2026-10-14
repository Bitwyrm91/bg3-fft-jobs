"""Job skills scale with the character's highest ability (user, 2026-10-14: "make the abilities scale with the player's
highest stat regardless if it's INT or whatever"). Step 1 (this file): the damage and healing formulas of our spells
get + the highest ability modifier, at build time. Step 2 (NWP 18): hit chance and save DCs follow each spell's casting
ability, which tools/statcast.py sets to the highest one; here the Battle Master style ManeuverSaveDC() (Strength or
Dexterity) becomes SourceSpellDC() so those DCs follow it too.

Rules (build.py calls apply() on Spell_FFTJ.txt and Interrupt_FFTJ.txt; souls, menus and twins are left alone, the
Echo/Arithmeticks twins inherit through `using`):
- every DealDamage(...) / RegainHitPoints(...) in SpellProperties, SpellSuccess, SpellFail, TooltipDamageList and
  DescriptionParams whose formula has dice or a LevelMapValue;
- not weapon/unarmed damage (the weapon's ability already counts), not formulas that already use a modifier or
  max()/min(), not recoil (DamageDone) or HP-based amounts;
- not the Chemist's FFT items (Potion line etc.: flat, user 2026-10-14 "Potion 1d4+2"); its custom skills do scale.
Nested max() of plain modifiers: vanilla uses max(DexterityModifier,StrengthModifier) and expressions inside max(),
so the parser takes it; unverified in game.
"""
import re

BEST = ("max(max(max(StrengthModifier,DexterityModifier),max(ConstitutionModifier,IntelligenceModifier)),"
        "max(WisdomModifier,CharismaModifier))")
FIELDS = ("SpellProperties", "SpellSuccess", "SpellFail", "TooltipDamageList", "DescriptionParams")
CALLS = ("DealDamage(", "RegainHitPoints(")
SKIP = ("Weapon", "Unarmed", "Modifier", "max(", "min(", "DamageDone", "HP")
DICE = re.compile(r"\d*d\d+|LevelMapValue\(")
DATA_RE = re.compile(r'^data "([^"]+)" "(.*)"$')
ENTRY_RE = re.compile(r'^new entry "([^"]+)"')
NOTE = " Damage and healing add your highest ability modifier."
DC_FROM, DC_TO = "ManeuverSaveDC()", "SourceSpellDC()"


def excluded_abilities(jobs_doc):
    """The Chemist's FFT item abilities (everything of the Chemist not marked custom)."""
    return {a["id"] for a in jobs_doc["abilities"]
            if a["job"] == "Chemist" and "custom" not in a.get("source", [])}


def granted_by(jobs_doc):
    """Stats entry -> ability id (grants and variants)."""
    out = {}
    for a in jobs_doc["abilities"]:
        for g in [a["grants"]] + [v["grants"] for v in a.get("variants", [])]:
            for kind in ("spells", "passives", "statuses"):
                for sid in g.get(kind, []):
                    out.setdefault(sid, a["id"])
    return out


def _first_arg_end(s, start):
    """Index just past the first argument of a call whose '(' ends at `start` (balanced parentheses)."""
    depth = 0
    i = start
    while i < len(s):
        c = s[i]
        if c == "(":
            depth += 1
        elif c == ")":
            if depth == 0:
                return i
            depth -= 1
        elif c == "," and depth == 0:
            return i
        i += 1
    return -1


def scale_value(value):
    """value with + BEST added to each qualifying formula; returns (new value, changed)."""
    out, i, changed = [], 0, False
    while True:
        hits = [(value.find(c, i), c) for c in CALLS if value.find(c, i) >= 0]
        if not hits:
            out.append(value[i:])
            break
        pos, call = min(hits)
        start = pos + len(call)
        end = _first_arg_end(value, start)
        if end < 0:
            out.append(value[i:])
            break
        formula = value[start:end]
        out.append(value[i:start])
        if DICE.search(formula) and not any(t in formula for t in SKIP):
            out.append(formula.rstrip() + "+" + BEST)
            changed = True
        else:
            out.append(formula)
        i = end
    return "".join(out), changed


def apply(text, jobs_doc):
    """Returns (new text, set of ability ids whose entries changed)."""
    by_entry = granted_by(jobs_doc)
    skip = excluded_abilities(jobs_doc)
    lines, touched = [], set()
    entry = None
    for line in text.split("\n"):
        m = ENTRY_RE.match(line)
        if m:
            entry = m.group(1)
        if DC_FROM in line:
            line = line.replace(DC_FROM, DC_TO)
        d = DATA_RE.match(line)
        if d and d.group(1) in FIELDS and by_entry.get(entry) not in skip:
            new, changed = scale_value(d.group(2))
            if changed:
                line = f'data "{d.group(1)}" "{new}"'
                if entry in by_entry:
                    touched.add(by_entry[entry])
        lines.append(line)
    return "\n".join(lines), touched
