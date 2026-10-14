"""Chemist skills cast with higher spell slots (user, 2026-10-14: "if i choose to use chemical mixup as a level 2 skill
it'll roll 2 die for dmg and apply 2 effects. 3 for level 3 etc.").

BG3's upcast pattern (vanilla Projectile_MagicMissile_2): an entry `<root>_<N>` using the root, with RootSpellID,
PowerLevel N and a level N slot; only the root is learned (its Level must be 1+). build.py calls stats() right after
stats_src, so the Echo twins and grant checks see the new roots.

- Flasks: damage comes from Lua (Server/Effects.lua) on the status the flask applies, so level N applies
  `<STATUS>_<N>` and Effects reads N: Mixup N dice and N effects, Caustic/Unstable N dice, Fulminate N d6 (its blast
  status `FFTJ_FULMINATE_BLAST_<N>`). Mixup and Caustic keep their free cantrip and get a slot root `<root>_Slot`
  at level 1 with BG3's own level picker for 1-6 (user, 2026-10-14: "keep the cantrip version and then add the level
  1 version"); Unstable Flask and Fulminate Flask are level 1 spells (user).
- Slot roots and their levels carry the base spell's Icon themselves (the playtest showed no icon on the Mixup and
  Caustic slot versions, which only inherited it).
- Potions (stats only): `<root>_Slot` level 1 = one more healing die than the free version, +1 die per level above;
  no cooldown (the slot is the cost); touch range like the base.
"""
import re

SPELL_FILE = "Spell_FFTJ_Upcast.txt"
STATUS_FILE = "Status_FFTJ_Upcast.txt"
MAX_LEVEL = 6
SLOT = "SpellSlotsGroup:1:1:{}"
# root spell -> (status it applies, field holding it, first slot level, separate slot root?)
FLASKS = {
    "Projectile_FFTJ_ChemicalMixup": ("FFTJ_CHEM_MIXUP", "SpellSuccess", 1, True),
    "Projectile_FFTJ_CausticFlask": ("FFTJ_CAUSTIC", "SpellSuccess", 1, True),
    "Projectile_FFTJ_UnstableFlask": ("FFTJ_UNSTABLE", "SpellSuccess", 2, False),
    "Projectile_FFTJ_FulminateFlask": ("FFTJ_FULMINATE", "SpellProperties", 2, False),
}
BLAST = "FFTJ_FULMINATE_BLAST"
POTIONS = {"Target_FFTJ_Potion": "Potion", "Target_FFTJ_HiPotion": "HiPotion", "Target_FFTJ_XPotion": "XPotion"}
LUA_STATUSES = sorted({v[0] for v in FLASKS.values()})  # Effects.lua strips "_<N>" from these
ABILITY_OF = {"Projectile_FFTJ_ChemicalMixup": "ChemicalMixup", "Projectile_FFTJ_CausticFlask": "CausticFlask"}


def _field(entries, name, key):
    seen = set()
    while name in entries and name not in seen:
        seen.add(name)
        for k, v in entries[name]["data"]:
            if k == key:
                return v
        name = entries[name]["using"]
    return None


def strings(jobs_doc):
    names = {a["id"]: a["name"] for a in jobs_doc["abilities"]}
    t = {}
    for root, aid in list(ABILITY_OF.items()) + [(r, a) for r, a in POTIONS.items()]:
        t[f"upcast.{aid}.name"] = f"{names[aid]} (spell slot)"
    t["upcast.ChemicalMixup.desc"] = ("Chemical Mixup with a spell slot: a level N slot rolls N damage dice and adds N "
                                      "effects (level 1-6).")
    t["upcast.CausticFlask.desc"] = "Caustic Flask with a spell slot: a level N slot rolls N damage dice (level 1-6)."
    for aid in POTIONS.values():
        t[f"upcast.{aid}.desc"] = (f"{names[aid]} with a spell slot: one more healing die than the free one, and one "
                                   f"more per slot level above 1. No cooldown.")
    return t


def stats(entries_list, H):
    entries = {e["name"]: e for e in entries_list}
    spells, statuses = [], []

    def icon(root):
        value = _field(entries, root.removesuffix("_Slot"), "Icon")
        return [f'data "Icon" "{value}"'] if value else []

    def variant(name, root, level, field, value, using=None, extra=()):
        spells.extend([f'new entry "{name}"', 'type "SpellData"', f'data "SpellType" "{_field(entries, root.removesuffix("_Slot"), "SpellType")}"',
                       f'using "{using or root}"', f'data "RootSpellID" "{root}"', f'data "PowerLevel" "{level}"',
                       f'data "UseCosts" "ActionPoint:1;{SLOT.format(level)}"', f'data "{field}" "{value}"', *icon(root),
                       *extra, ""])

    for root, (status, field, first, separate) in FLASKS.items():
        base = _field(entries, root, field)
        if base is None or status not in base:
            raise ValueError(f"upcast: {root}.{field} does not apply {status}")
        pat = re.compile(r"\b%s(?=,)" % status)
        top = root
        if separate:
            aid = ABILITY_OF[root]
            top = root + "_Slot"
            spells.extend([f'new entry "{top}"', 'type "SpellData"',
                           f'data "SpellType" "{_field(entries, root, "SpellType")}"', f'using "{root}"',
                           f'data "Level" "{first}"', f'data "UseCosts" "ActionPoint:1;{SLOT.format(first)}"',
                           f'data "{field}" "{pat.sub(f"{status}_{first}", base)}"', *icon(root),
                           f'data "DisplayName" "{H(f"upcast.{aid}.name")}"',
                           f'data "Description" "{H(f"upcast.{aid}.desc")}"', ""])
            levels = range(first + 1, MAX_LEVEL + 1)
        else:
            levels = range(first, MAX_LEVEL + 1)
        for n in levels:
            extra = []
            tip = _field(entries, root, "TooltipDamageList")
            if tip and re.search(r"\b1d6\b", tip) and root.endswith("FulminateFlask"):
                extra.append(f'data "TooltipDamageList" "{re.sub(r"\b1d6\b", f"{n}d6", tip)}"')
            variant(f"{top}_{n}", top, n, field, pat.sub(f"{status}_{n}", base), extra=extra)
        for n in range(first, MAX_LEVEL + 1):
            statuses.extend([f'new entry "{status}_{n}"', 'type "StatusData"', f'using "{status}"', ""])
    blast = _field(entries, BLAST, "OnApplyFunctors")
    if not blast or not re.search(r"\b1d6\b", blast):
        raise ValueError("upcast: FFTJ_FULMINATE_BLAST has no 1d6 to scale")
    for n in range(2, MAX_LEVEL + 1):
        statuses.extend([f'new entry "{BLAST}_{n}"', 'type "StatusData"', f'using "{BLAST}"',
                         f'data "OnApplyFunctors" "{re.sub(r"\b1d6\b", f"{n}d6", blast)}"', ""])
    for root, aid in POTIONS.items():
        heal = _field(entries, root, "SpellProperties")
        m = re.fullmatch(r"RegainHitPoints\((\d+)d(\d+)(\+\d+)?\)", heal or "")
        if not m:
            raise ValueError(f"upcast: {root} heal not understood: {heal}")
        dice, die, plus = int(m.group(1)), m.group(2), m.group(3) or ""
        top = root + "_Slot"

        def heal_at(level):
            return f"RegainHitPoints({dice + level}d{die}{plus})"
        spells.extend([f'new entry "{top}"', 'type "SpellData"', 'data "SpellType" "Target"', f'using "{root}"',
                       'data "Level" "1"', f'data "UseCosts" "ActionPoint:1;{SLOT.format(1)}"', 'data "Cooldown" ""',
                       f'data "SpellProperties" "{heal_at(1)}"', f'data "TooltipDamageList" "{heal_at(1)}"',
                       f'data "DisplayName" "{H(f"upcast.{aid}.name")}"', f'data "Description" "{H(f"upcast.{aid}.desc")}"',
                       ""])
        for n in range(2, MAX_LEVEL + 1):
            variant(f"{top}_{n}", top, n, "SpellProperties", heal_at(n),
                    extra=[f'data "TooltipDamageList" "{heal_at(n)}"'])
    return {SPELL_FILE: "\n".join(spells).rstrip("\n") + "\n", STATUS_FILE: "\n".join(statuses).rstrip("\n") + "\n"}
