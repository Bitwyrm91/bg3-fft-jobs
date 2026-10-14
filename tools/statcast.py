"""Job skills cast with the character's highest ability: hit chance and save DCs (NWP 18; step 1, the damage and
healing formulas, is tools/scaling.py). User, 2026-10-14: weapon skills keep the weapon's stat to hit; the highest
ability is chosen again at level-up only.

A BG3 spell rolls its spell attacks and SourceSpellDC() with its spellcasting ability; UnlockSpell's 5th argument
sets it (vanilla: UnlockSpell(Projectile_ProduceFlame_Hurl,,,,Wisdom); the Chemist flasks used it with Intelligence).
So every job spell gets six hidden passives FFTJ_Cast_<Str|Dex|Con|Int|Wis|Cha>_<spell>, and the server grants the
one of the character's highest ability instead of AddSpell (Rules.StatCastGrants). Spells that cost a spell slot
unlock with AddChildren and the spell slot resource, so their upcast levels come along (the flask pattern).

Covered: the spells of every ability (grants and variants), the jobs' innate / level / mastery spells, the Echo twins.
Not covered: hotbar menus, Soul Collector forms, the Job Board, Arithmeticks twins (the server casts those without a
spellbook entry). Weapon attacks (Attack(AttackType.*WeaponAttack)) keep the weapon's ability: the attack type
decides that, not the spellcasting ability.

Statuses that carry a fixed CalculateSpellDC(Ability.Intelligence, context.Source) (the Fulminate blast, applied by
Server/Effects.lua) get one twin per ability, `<status>_<Str|...>`; Effects picks the thrower's.
"""

PREFIX = "FFTJ_Cast_"
FILE = "Passive_FFTJ_Cast.txt"
STATUS_FILE = "Status_FFTJ_Cast.txt"
STATS = (("Strength", "Str"), ("Dexterity", "Dex"), ("Constitution", "Con"), ("Intelligence", "Int"),
         ("Wisdom", "Wis"), ("Charisma", "Cha"))
SLOT_RESOURCE = "d136c5d9-0ff0-43da-acce-a74a07f8d6bf"  # the SpellSlot action resource
INT_DC = "CalculateSpellDC(Ability.Intelligence, context.Source)"
GRANT_SOURCES = ("innate", "mastery")


def _unique(seq):
    seen, out = set(), []
    for x in seq:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def job_spells(jobs_doc):
    """Every spell a job can grant: abilities (grants and variants), then the jobs' innate, level and mastery spells."""
    out = []
    for a in jobs_doc["abilities"]:
        for g in [a["grants"]] + [v["grants"] for v in a.get("variants", [])]:
            out += g.get("spells", [])
    for j in jobs_doc["jobs"]:
        for key in GRANT_SOURCES:
            out += j.get(key, {}).get("spells", [])
        for t in j.get("levelGrants", []):
            out += t.get("spells", [])
    return _unique(out)


def defaults(jobs_doc):
    """spell -> the ability it casts with while the highest ability is not used (an ability's castStat)."""
    out = {}
    for a in jobs_doc["abilities"]:
        if a.get("castStat"):
            for g in [a["grants"]] + [v["grants"] for v in a.get("variants", [])]:
                for sid in g.get("spells", []):
                    out[sid] = a["castStat"]
    return out


def _field(entries, name, key):
    seen = set()
    while name in entries and name not in seen:
        seen.add(name)
        for k, v in entries[name]["data"]:
            if k == key:
                return v
        name = entries[name]["using"]
    return None


def is_slot_spell(entries, name):
    """The spell (or a parent of ours it inherits from) costs a spell slot."""
    return "SpellSlot" in (_field(entries, name, "UseCosts") or "")


def passive_name(spell, short):
    return f"{PREFIX}{short}_{spell}"


def unlock(entries, spell, stat):
    if is_slot_spell(entries, spell):
        return f"UnlockSpell({spell},AddChildren,{SLOT_RESOURCE},,{stat})"
    return f"UnlockSpell({spell},,,,{stat})"


def build(jobs_doc, entries_list, echo_suffix):
    """Returns (passive text, status text, Lua data). Only spells that have a stats entry get passives."""
    entries = {e["name"]: e for e in entries_list}
    base = [s for s in job_spells(jobs_doc) if s in entries]
    spells = base + [s + echo_suffix for s in base if s + echo_suffix in entries]
    dflt = defaults(jobs_doc)
    dflt.update({s + echo_suffix: dflt[s] for s in list(dflt) if s + echo_suffix in entries})
    stat_names = {name for name, _ in STATS}
    for sid, stat in dflt.items():
        if stat not in stat_names:
            raise ValueError(f"statcast: castStat {stat} of {sid} is not an ability name")
    lines = []
    for sid in spells:
        for stat, short in STATS:
            lines += [f'new entry "{passive_name(sid, short)}"', 'type "PassiveData"', 'data "Properties" "IsHidden"',
                      f'data "Boosts" "{unlock(entries, sid, stat)}"', ""]
    status_lines, twinned = [], []
    for e in entries_list:
        if e["type"] != "StatusData":
            continue
        fields = [(k, v) for k, v in e["data"] if INT_DC in v]
        if not fields:
            continue
        twinned.append(e["name"])
        for stat, short in STATS:
            status_lines += [f'new entry "{e["name"]}_{short}"', 'type "StatusData"', f'using "{e["name"]}"']
            status_lines += [f'data "{k}" "{v.replace(INT_DC, f"CalculateSpellDC(Ability.{stat}, context.Source)")}"'
                             for k, v in fields]
            status_lines.append("")
    lua = {
        "Prefix": PREFIX,
        "Short": {stat: short for stat, short in STATS},
        "Spells": {sid: True for sid in spells},
        "Default": {sid: stat for sid, stat in dflt.items() if sid in entries},
        "Statuses": {name: True for name in twinned},
    }
    text = "\n".join(lines).rstrip("\n") + "\n"
    status_text = "\n".join(status_lines).rstrip("\n") + "\n" if status_lines else ""
    return text, status_text, lua
