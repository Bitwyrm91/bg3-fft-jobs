"""The Peddler (Fell Seal job, 2026-10-14): what its stats need besides stats_src/*_FFTJ_Peddler.txt.

Traps: the vanilla Glyph of Warding pattern. A trap spell summons an item; our item root templates are children of the
vanilla glyph trap items (PUZ_Trap_Spell_GlyphOfWarding_<Kind>: constellation "GlyphOfWarding" from their base, which
fires the template's "Projectile" parameter at an enemy that walks in, and the glyph's look and fade). Ours set their
own Projectile (Projectile_FFTJ_<Trap>_Trap), a name and a smaller trigger box (the vanilla base is 8 x 8 m for a
4 m glyph; a Peddler trap covers about one Fell Seal tile). Unverified in game: that the box drives the trigger, and
that a child template keeps the base's constellation.

Item Potency's healing: FFTJ_ItemPotency_Heal, a hidden passive in the Disciple of Life pattern (OnHeal, the healing
spell in the context): for every spell built on a Chemist potion skill (base, thrown, spell-slot levels, Echo twins,
Patented Usage forms) its own RegainHitPoints formula once more, so the healing is rolled twice.
"""
import re

# id = ability id; kind = the vanilla glyph whose look it borrows (parent template)
TRAPS = (
    {"id": "LaceratingTrap", "template": "61496804-e418-405a-b64f-55da652cbaa6",
     "parent": "08f18dbc-f862-48c2-afcc-036f2e82b2a6"},  # Fire glyph (red)
    {"id": "ImmobilizingTrap", "template": "0175f384-ba04-4ddd-9f3b-3b3a49675c17",
     "parent": "850f19a5-5548-4d19-a04f-faf618152407"},  # Cold glyph (blue)
    {"id": "PainfulTrap", "template": "398f9cc7-74a7-4361-a6d4-59e00a63e2f3",
     "parent": "0ab48ea9-84ed-43e8-8dde-b90797dba3a5"},  # Lightning glyph
    {"id": "AlluringTrap", "template": "3323687f-c8bc-4b68-83a8-6c5550f5aab3",
     "parent": "181cdccc-80ea-43c7-8ca7-3ba0214f26f3"},  # Sleep glyph (purple)
)
TRIGGER_HALF = 1.5  # metres from the trap's centre (the vanilla glyph base: 4)

POTENCY_ROOTS = ("Target_FFTJ_Potion", "Target_FFTJ_HiPotion", "Target_FFTJ_XPotion")
HEAL_PASSIVE = "FFTJ_ItemPotency_Heal"
FILE = "Passive_FFTJ_Potency.txt"


def projectile(trap_id):
    return f"Projectile_FFTJ_{trap_id}_Trap"


def _bound(kind):
    h = TRIGGER_HALF
    return ["\t\t\t\t\t\t\t\t<node id=\"Bound\">",
            '\t\t\t\t\t\t\t\t\t<attribute id="Height" type="float" value="1.3199748" />',
            f'\t\t\t\t\t\t\t\t\t<attribute id="Max" type="fvec3" value="{h:g} 1.5 {h:g}" />',
            f'\t\t\t\t\t\t\t\t\t<attribute id="Min" type="fvec3" value="-{h:g} -0.5 -{h:g}" />',
            '\t\t\t\t\t\t\t\t\t<attribute id="Radius" type="float" value="0.5463637" />',
            '\t\t\t\t\t\t\t\t\t<attribute id="Shape" type="uint8" value="1" />',
            f'\t\t\t\t\t\t\t\t\t<attribute id="Type" type="uint8" value="{kind}" />',
            "\t\t\t\t\t\t\t\t</node>"]


def trap_nodes(handle):
    """The trap items' <node id="GameObjects"> blocks (lines). handle(key) -> a loca handle (marks the string used)."""
    lines = []
    for t in TRAPS:
        lines += ['\t\t\t\t<node id="GameObjects">',
                  f'\t\t\t\t\t<attribute id="Description" type="TranslatedString" handle="{handle(f"ability.{t["id"]}.desc")}" version="1" />',
                  f'\t\t\t\t\t<attribute id="DisplayName" type="TranslatedString" handle="{handle(f"ability.{t["id"]}.name")}" version="1" />',
                  '\t\t\t\t\t<attribute id="LevelName" type="FixedString" value="" />',
                  f'\t\t\t\t\t<attribute id="MapKey" type="FixedString" value="{t["template"]}" />',
                  f'\t\t\t\t\t<attribute id="Name" type="LSString" value="FFTJ_Trap_{t["id"]}" />',
                  f'\t\t\t\t\t<attribute id="ParentTemplateId" type="FixedString" value="{t["parent"]}" />',
                  '\t\t\t\t\t<attribute id="Type" type="FixedString" value="item" />',
                  "\t\t\t\t\t<children>",
                  '\t\t\t\t\t\t<node id="Bounds">', "\t\t\t\t\t\t\t<children>"]
        for kind in (0, 1, 2):
            lines += _bound(kind)
        lines += ["\t\t\t\t\t\t\t</children>", "\t\t\t\t\t\t</node>",
                  '\t\t\t\t\t\t<node id="ConstellationConfigGlobalParameters">', "\t\t\t\t\t\t\t<children>",
                  '\t\t\t\t\t\t\t\t<node id="ConstellationConfigParameter">',
                  '\t\t\t\t\t\t\t\t\t<attribute id="Name" type="LSString" value="Projectile" />',
                  "\t\t\t\t\t\t\t\t\t<children>", '\t\t\t\t\t\t\t\t\t\t<node id="Value">', "\t\t\t\t\t\t\t\t\t\t\t<children>",
                  '\t\t\t\t\t\t\t\t\t\t\t\t<node id="Scalar">', "\t\t\t\t\t\t\t\t\t\t\t\t\t<children>",
                  '\t\t\t\t\t\t\t\t\t\t\t\t\t\t<node id="Scalar">', "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<children>",
                  '\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<node id="String">',
                  f'\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t<attribute id="String" type="LSString" value="{projectile(t["id"])}" />',
                  "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t</node>",
                  "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t</children>", "\t\t\t\t\t\t\t\t\t\t\t\t\t\t</node>",
                  "\t\t\t\t\t\t\t\t\t\t\t\t\t</children>", "\t\t\t\t\t\t\t\t\t\t\t\t</node>",
                  "\t\t\t\t\t\t\t\t\t\t\t</children>", "\t\t\t\t\t\t\t\t\t\t</node>",
                  "\t\t\t\t\t\t\t\t\t</children>", "\t\t\t\t\t\t\t\t</node>",
                  "\t\t\t\t\t\t\t</children>", "\t\t\t\t\t\t</node>",
                  "\t\t\t\t\t</children>", "\t\t\t\t</node>"]
    return lines


EMPTY_LSX = ['<?xml version="1.0" encoding="utf-8"?>', "<save>",
             '\t<version major="4" minor="0" revision="9" build="0" lslib_meta="v1,bswap_guids,lsf_adjacency" />',
             '\t<region id="Templates">', '\t\t<node id="Templates">', "\t\t\t<children>",
             "\t\t\t</children>", "\t\t</node>", "\t</region>", "</save>"]
CLOSE = "\t\t\t</children>"


def add_templates(lsx, handle):
    """RootTemplates/_merged.lsx (the text build.py wrote for the other items, or None) with the trap items added."""
    lines = (lsx.rstrip("\n").split("\n") if lsx else list(EMPTY_LSX))
    at = len(lines) - 1 - lines[::-1].index(CLOSE)
    return "\n".join(lines[:at] + trap_nodes(handle) + lines[at:]) + "\n"


def _call_arg(text, call):
    """The argument of the first call(...) in text (balanced parentheses), or None."""
    i = text.find(call + "(")
    if i < 0:
        return None
    start = i + len(call) + 1
    depth = 0
    for j in range(start, len(text)):
        if text[j] == "(":
            depth += 1
        elif text[j] == ")":
            if depth == 0:
                return text[start:j]
            depth -= 1
    return None


def _field(by_name, name, key):
    seen = set()
    while name in by_name and name not in seen:
        seen.add(name)
        for k, v in by_name[name]["data"]:
            if k == key:
                return v
        name = by_name[name]["using"]
    return None


def _root_of(by_name, name):
    seen = set()
    while name in by_name and name not in seen:
        if name in POTENCY_ROOTS:
            return name
        seen.add(name)
        name = by_name[name]["using"]
    return None


def potency_stats(entries):
    """The hidden passive FFTJ_ItemPotency_Heal: each Chemist potion spell's healing once more (stats text)."""
    by_name = {e["name"]: e for e in entries}
    by_formula = {}
    for e in entries:
        if e["type"] != "SpellData" or not _root_of(by_name, e["name"]):
            continue
        heal = None
        for key in ("SpellProperties", "SpellSuccess"):
            heal = _call_arg(_field(by_name, e["name"], key) or "", "RegainHitPoints")
            if heal:
                break
        if heal and re.search(r"\d*d\d+", heal):
            by_formula.setdefault(heal, []).append(e["name"])
    if not by_formula:
        raise ValueError("peddler: no Chemist potion spell with a healing formula found")
    functors = ";".join("IF(" + " or ".join(f"SpellId('{s}')" for s in sorted(names)) + f"):RegainHitPoints({f})"
                        for f, names in sorted(by_formula.items()))
    return "\n".join([f'new entry "{HEAL_PASSIVE}"', 'type "PassiveData"', 'data "Properties" "IsHidden"',
                      'data "StatsFunctorContext" "OnHeal"', 'data "Conditions" "HealDoneGreaterThan(0)"',
                      f'data "StatsFunctors" "{functors}"']) + "\n"
