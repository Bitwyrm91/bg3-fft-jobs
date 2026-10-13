"""Soul Collector forms (data/souls.json) -> stats text, strings and Lua data; used by tools/build.py.

Each soul type has two forms (B = the BG3 creature, F = the FFT monster) and three tiers per form (1, 3 and 5
souls devoured). A tier is a POLYMORPHED status on Wild Shape's shapeshift rule (the creature template's body, HP and
natural attacks; your mental abilities; no gear) plus a transform spell in the Soul Incarnation container. B forms
add their two new skills at 3 and 5 souls, F forms their three FFT skills at 1, 3 and 5 souls. Forms scale with the
character's level: max HP + hp x level, damage dice from vanilla level tables (Wild Shape's for melee, cantrip dice
for the rest).
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOULS_JSON = ROOT / "data" / "souls.json"
SPELL_FILE = "Spell_FFTJ_Soul.txt"
STATUS_FILE = "Status_FFTJ_Soul.txt"
CONTAINER = "Shout_FFTJ_SoulIncarnation"
TIERS = (1, 3, 5)
SKILL_TIERS = {"B": (3, 5), "F": (1, 3, 5)}
# Wild Shape's "spawn in a puff" effect and status groups (vanilla WILDSHAPE_*_PLAYER)
APPLY_EFFECT = "f515b011-9b9d-462c-85e1-a79bc9055962"
GROUPS = "SG_Polymorph;SG_Polymorph_BeastShape;SG_DropForNonMutingDialog;SG_RemoveOnRespec"
TIER_BOOSTS = {1: "", 3: "AC(1)", 5: "AC(2);RollBonus(Attack,1)"}
TIER_TEXT = {1: "", 3: " 3 souls: +1 AC.", 5: " 5 souls: +2 AC and +1 to attack rolls."}

# Carriers (the look comes from the using parent; DESIGN section 8)
BOLT_CARRIER = {"Fire": "Projectile_ChromaticOrb_Fire", "Cold": "Projectile_ChromaticOrb_Cold",
                "Lightning": "Projectile_ChromaticOrb_Lightning", "Acid": "Projectile_ChromaticOrb_Acid",
                "Thunder": "Projectile_ChromaticOrb_Thunder", "Poison": "Projectile_ChromaticOrb_Poison",
                "Necrotic": "Projectile_RayOfSickness", "Psychic": "Projectile_EldritchBlast",
                "Force": "Projectile_EldritchBlast", "Radiant": "Projectile_EldritchBlast"}
BOLT_PHYSICAL = "Projectile_FOR_GnomeGoblin_ThrowRock"
CONE_CARRIER = {"Fire": "Zone_BurningHands", "Cold": "Zone_ConeOfCold", "Thunder": "Zone_Thunderwave",
                "Bludgeoning": "Zone_Thunderwave", "Force": "Zone_Thunderwave"}
CONE_OTHER = "Zone_ColorSpray"
COSTS = {"action": "ActionPoint:1", "bonus": "BonusActionPoint:1"}
KINDS = {"melee", "bolt", "burst", "cone", "heal", "cleanse", "buff"}


def load():
    return json.loads(SOULS_JSON.read_text(encoding="utf-8")) if SOULS_JSON.exists() else None


def form_status(t, side, tier):
    return f"FFTJ_SOUL_{t}_{side}{tier}"


def form_spell(t, side, tier):
    return f"Shout_FFTJ_Soul_{t}_{side}{tier}"


def skill_spell(sid, sk):
    kind = sk["kind"]
    if kind == "melee":
        prefix = "Target"
    elif kind == "bolt":
        prefix = "Projectile"
    elif kind == "cone":
        prefix = "Zone"
    elif kind == "heal" and sk.get("range"):
        prefix = "Target"
    elif kind == "buff" and sk.get("target") == "ally":
        prefix = "Target"
    else:
        prefix = "Shout"
    return f"{prefix}_FFTJ_Soul_{sid}"


def skill_tiers(form, side, boss=False):
    """The souls each of a form's skills needs: bosses are unique, so a boss soul gives them all at once."""
    return [1] * len(form["skills"]) if boss else list(SKILL_TIERS[side])


def tier_skills(form, side, tier, boss=False):
    """Skill ids a form has at this tier."""
    return [s for s, at in zip(form["skills"], skill_tiers(form, side, boss)) if at <= tier]


def validate(doc):
    errors = []
    skills = doc["skills"]
    seen = set()
    for s in doc["souls"]:
        if s["id"] in seen or not re.fullmatch(r"[A-Za-z]+", s["id"]):
            errors.append(f"soul {s['id']}: duplicate or not letters only")
        seen.add(s["id"])
        for side in ("B", "F"):
            f = s["forms"][side]
            if not re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", f["template"]):
                errors.append(f"soul {s['id']} {side}: bad template {f['template']}")
            if not s.get("boss") and len(f["skills"]) != len(SKILL_TIERS[side]):
                errors.append(f"soul {s['id']} {side}: needs {len(SKILL_TIERS[side])} skills")
            for k in f["skills"]:
                if k not in skills:
                    errors.append(f"soul {s['id']} {side}: unknown skill {k}")
        if not s.get("match") and not s.get("guids"):
            errors.append(f"soul {s['id']}: needs match patterns or boss guids")
        for p in s.get("match", []) + s.get("exclude", []):
            if re.sub(r"%[A-Za-z]", "", p) != re.sub(r"%[A-Za-z]", "", p).lower():
                errors.append(f"soul {s['id']}: patterns are lower case ({p})")
    for k, sk in skills.items():
        if sk["kind"] not in KINDS:
            errors.append(f"skill {k}: unknown kind {sk['kind']}")
        if sk.get("cost", "action") not in COSTS:
            errors.append(f"skill {k}: cost is action or bonus")
    return errors


def strings(doc):
    out = {}
    for s in doc["souls"]:
        out[f"soul.{s['id']}.name"] = s["name"]
        for side in ("B", "F"):
            f = s["forms"][side]
            kind = "the BG3 creature" if side == "B" else "an FFT monster"
            for tier in TIERS:
                names = ", ".join(doc["skills"][k]["name"] for k in tier_skills(f, side, tier, s.get("boss")))
                skills = f" Skills: {names}." if names else " Its own natural attacks."
                out[f"soul.{s['id']}.{side}{tier}.name"] = f"Soul Form: {f['name']}"
                out[f"soul.{s['id']}.{side}{tier}.desc"] = (
                    f"Take the form of {f['name']} ({kind}; {s['name']} soul, {tier}+ devoured): its body, hit points "
                    f"and natural attacks, plus {s['hp']} hit points per level. Your gear and spells are put away until "
                    f"you return (Dismiss, or at 0 hit points).{skills}{TIER_TEXT[tier]} Uses a Wild Shape charge.")
    for k, sk in doc["skills"].items():
        out[f"soulskill.{k}.name"] = sk["name"]
        out[f"soulskill.{k}.desc"] = sk["desc"]
    out["soul.container.name"] = "Soul Incarnation"
    out["soul.container.desc"] = ("Take the form of a creature whose soul the party devoured (Soul Brand). Each soul "
                                  "type gives two forms: the creature itself and an FFT monster. More souls of a type "
                                  "make its forms stronger (3 and 5). Uses a Wild Shape charge.")
    return out


def _status_part(st, ability=None):
    """ApplyStatus for a skill status [id, turns, save?]: behind its own save when the skill has none."""
    sid, turns = st[0], st[1]
    if ability:
        return f"IF(not SavingThrow(Ability.{ability}, ManeuverSaveDC())):ApplyStatus({sid},100,{turns})"
    return f"ApplyStatus({sid},100,{turns})"


def _damage(sk, half=False):
    n = sk.get("n", 1)
    die = f"LevelMapValue({sk['dmg']}Cantrip)"
    one = f"DealDamage(({die})/2,{sk['dtype']},Magical)" if half else f"DealDamage({die},{sk['dtype']},Magical)"
    return ";".join([one] * n)


def skill_entry(sid, sk, H):
    kind = sk["kind"]
    name = skill_spell(sid, sk)
    cost = COSTS[sk.get("cost", "action")]
    cd = sk.get("cd", "")
    head = [f'new entry "{name}"', 'type "SpellData"']
    common = [f'data "DisplayName" "{H("soulskill." + sid + ".name")}"',
              f'data "Description" "{H("soulskill." + sid + ".desc")}"', 'data "DescriptionParams" ""',
              f'data "UseCosts" "{cost}"', f'data "Cooldown" "{cd}"', 'data "RechargeValues" ""',
              'data "RequirementConditions" ""', 'data "TooltipStatusApply" ""', 'data "Level" "0"']
    statuses = [sk[k] for k in ("status", "status2", "status3") if k in sk]
    if kind == "melee":
        scale = "WildShapeDamageMedium" if sk.get("scale") == "med" else "WildShapeDamageLow"
        dmg = f"DealDamage(max(1,{sk['dice']}+LevelMapValue({scale})+UnarmedMeleeAbilityModifier),{sk['dtype']})"
        parts = [dmg]
        if sk.get("push"):
            parts.append(f"Force({sk['push']})")
        if sk.get("drain"):
            parts.append("RegainHitPoints(SELF,(DamageDone)/2)")
        parts += [_status_part(st, st[2] if len(st) > 2 else None) for st in statuses]
        cond = "Character() and not Self() and not Dead()"
        if sk.get("only"):
            cond += f" and ({sk['only']})"
        return head + ['data "SpellType" "Target"', 'using "Target_UnarmedAttack"'] + common + [
            'data "SpellRoll" "Attack(AttackType.MeleeUnarmedAttack)"', f'data "SpellSuccess" "{";".join(parts)}"',
            'data "SpellFail" ""', f'data "TargetConditions" "{cond}"', 'data "SpellFlags" "IsAttack;IsMelee;IsHarmful"',
            f'data "TooltipDamageList" "{dmg}"']
    if kind in ("bolt", "burst", "cone"):
        save = sk["save"]
        succ = ([_damage(sk)] if sk.get("dmg") else []) + [_status_part(st) for st in statuses]
        fail = _damage(sk, half=True) if sk.get("dmg") else "ApplyStatus(SAVED_AGAINST_HOSTILE_SPELL,100,0)"
        if sk.get("selfdamage"):
            succ.append(f"DealDamage(SELF,(DamageDone)/2,{sk['dtype']})")
        rows = [f'data "SpellRoll" "not SavingThrow(Ability.{save}, ManeuverSaveDC())"',
                f'data "SpellSuccess" "{";".join(succ)}"', f'data "SpellFail" "{fail}"',
                f'data "TooltipAttackSave" "{save}"',
                f'data "TooltipDamageList" "{_damage(sk) if sk.get("dmg") else ""}"']
        if kind == "bolt":
            parent = BOLT_CARRIER.get(sk.get("dtype"), BOLT_PHYSICAL)
            return head + ['data "SpellType" "Projectile"', f'using "{parent}"'] + common + rows + [
                f'data "TargetRadius" "{sk["range"]}"', 'data "ExplodeRadius" "0"', 'data "SpellProperties" ""',
                'data "TargetConditions" "Character() and not Self() and not Dead()"',
                'data "SpellFlags" "IsHarmful;IgnoreSilence"']
        if kind == "burst":
            return head + ['data "SpellType" "Shout"', 'using "Shout_ArmsOfHadar"'] + common + rows + [
                f'data "AreaRadius" "{sk["radius"]}"', 'data "SpellProperties" ""',
                'data "TargetConditions" "Enemy() and not Dead() and not Self()"', 'data "SpellFlags" "IsHarmful;IgnoreSilence"']
        parent = CONE_CARRIER.get(sk.get("dtype"), CONE_OTHER)
        return head + ['data "SpellType" "Zone"', f'using "{parent}"'] + common + rows + [
            f'data "Range" "{sk["radius"]}"', 'data "SpellProperties" ""',
            'data "TargetConditions" "not Self() and not Dead()"', 'data "SpellFlags" "IsHarmful;CanAreaDamageEvade;IgnoreSilence"']
    if kind == "heal":
        heal = ";".join([f"RegainHitPoints(LevelMapValue({sk['dmg']}Cantrip))"] * sk.get("n", 1))
        self_heal = ";".join([f"RegainHitPoints(SELF,LevelMapValue({sk['dmg']}Cantrip))"] * sk.get("n", 1))
        if sk.get("range"):
            return head + ['data "SpellType" "Target"', 'using "Target_FFTJ_Cure"'] + common + [
                f'data "TargetRadius" "{sk["range"]}"', f'data "SpellProperties" "{heal}"', 'data "SpellRoll" ""',
                'data "SpellSuccess" ""', 'data "TargetConditions" "Ally() and not Dead()"', 'data "SpellFlags" "IgnoreSilence"']
        if sk.get("radius"):
            return head + ['data "SpellType" "Shout"', 'using "Shout_FFTJ_Curaja"'] + common + [
                f'data "AreaRadius" "{sk["radius"]}"', f'data "SpellProperties" "{heal}"',
                'data "TargetConditions" "Ally() and not Dead()"', 'data "SpellFlags" "IgnoreSilence"']
        return head + ['data "SpellType" "Shout"', 'using "Shout_FFTJ_Focus"'] + common + [
            f'data "SpellProperties" "{self_heal}"',
            'data "SpellFlags" "IgnoreSilence"']
    if kind == "cleanse":
        props = "RemoveStatus(SG_Poisoned);RemoveStatus(SG_Blinded);RemoveStatus(SG_Frightened);RemoveStatus(SG_Disease)"
        return head + ['data "SpellType" "Shout"', 'using "Shout_FFTJ_Curaja"'] + common + [
            f'data "AreaRadius" "{sk["radius"]}"', f'data "SpellProperties" "{props}"',
            'data "TargetConditions" "Ally() and not Dead()"', 'data "SpellFlags" "IgnoreSilence"']
    # buff
    apply = f"ApplyStatus({sk['status']},100,{sk['turns']})"
    target = sk.get("target", "self")
    if target == "ally":
        return head + ['data "SpellType" "Target"', 'using "Target_FFTJ_Protect"'] + common + [
            f'data "TargetRadius" "{sk["range"]}"', f'data "SpellProperties" "{apply}"', 'data "SpellRoll" ""',
            'data "SpellSuccess" ""', 'data "TargetConditions" "Ally() and not Dead()"', 'data "SpellFlags" "IgnoreSilence"']
    if target == "allies":
        return head + ['data "SpellType" "Shout"', 'using "Shout_FFTJ_Curaja"'] + common + [
            f'data "AreaRadius" "{sk["radius"]}"', f'data "SpellProperties" "{apply}"',
            'data "TargetConditions" "Ally() and not Dead()"', 'data "SpellFlags" "IgnoreSilence"']
    return head + ['data "SpellType" "Shout"', 'using "Shout_FFTJ_Focus"'] + common + [
        f'data "SpellProperties" "ApplyStatus(SELF,{sk["status"]},100,{sk["turns"]})"', 'data "SpellFlags" "IgnoreSilence"']


def stats(doc, H):
    """{file name: stats text}. H(key) -> loca handle with ';1' (marks the string used)."""
    rules = doc["rules"]
    spells, statuses, children = [], [], []
    for s in doc["souls"]:
        t = s["id"]
        for side in ("B", "F"):
            f = s["forms"][side]
            for tier in TIERS:
                st = form_status(s["id"], side, tier)
                sp = form_spell(s["id"], side, tier)
                children.append(sp)
                unlock = ";".join(f"UnlockSpell({skill_spell(k, doc['skills'][k])})"
                                  for k in tier_skills(f, side, tier, s.get("boss")))
                boosts = ";".join(x for x in ("VoicebarkBlock()", "BlockSpellCast()", "UnlockSpell(Shout_WildShape_Dismiss)",
                                              f"IncreaseMaxHP(Level*{s['hp']})", unlock, TIER_BOOSTS[tier]) if x)
                statuses += [f'new entry "{st}"', 'type "StatusData"', 'data "StatusType" "POLYMORPHED"',
                             f'data "DisplayName" "{H(f"soul.{t}.{side}{tier}.name")}"',
                             f'data "Description" "{H(f"soul.{t}.{side}{tier}.desc")}"',
                             f'data "Icon" "{f["icon"]}"', 'data "StackId" "WILDSHAPE"', f'data "Boosts" "{boosts}"',
                             'data "OnApplyFunctors" "ApplyStatus(SELF,WILDSHAPE_ACTIVE,100,-1)"',
                             'data "OnRemoveFunctors" "RemoveStatus(WILDSHAPE_ACTIVE)"',
                             f'data "TemplateID" "{f["template"]}"', f'data "Rules" "{rules}"',
                             f'data "StatusGroups" "{GROUPS}"', f'data "ApplyEffect" "{APPLY_EFFECT}"', ""]
                spells += [f'new entry "{sp}"', 'type "SpellData"', 'data "SpellType" "Shout"',
                           'using "Shout_WildShape_Badger"', f'data "SpellContainerID" "{CONTAINER}"',
                           'data "ContainerSpells" ""', f'data "SpellProperties" "ApplyStatus({st},100,-1)"',
                           f'data "Icon" "{f["icon"]}"',
                           f'data "DisplayName" "{H(f"soul.{t}.{side}{tier}.name")}"',
                           f'data "Description" "{H(f"soul.{t}.{side}{tier}.desc")}"',
                           'data "DescriptionParams" ""', 'data "UseCosts" "BonusActionPoint:1;WildShape:1"',
                           'data "RequirementConditions" "not HasStatus(\'WILDSHAPE_ACTIVE\')"', ""]
    spells = [f'new entry "{CONTAINER}"', 'type "SpellData"', 'data "SpellType" "Shout"', 'using "Shout_WildShape"',
              f'data "ContainerSpells" "{";".join(children)}"', f'data "DisplayName" "{H("soul.container.name")}"',
              f'data "Description" "{H("soul.container.desc")}"', 'data "ExtraDescription" ""',
              'data "UseCosts" "BonusActionPoint:1;WildShape:1"', ""] + spells
    for k, sk in doc["skills"].items():
        spells += skill_entry(k, sk, H) + [""]
    return {SPELL_FILE: "\n".join(spells).rstrip("\n") + "\n", STATUS_FILE: "\n".join(statuses).rstrip("\n") + "\n"}


def lua_data(doc):
    """Data.Souls / Data.SoulOrder for GeneratedData.lua."""
    souls = {}
    for s in doc["souls"]:
        forms = {}
        for side in ("B", "F"):
            f = s["forms"][side]
            forms[side] = {"Name": f["name"], "Spells": {str(t): form_spell(s["id"], side, t) for t in TIERS},
                           "Skills": [{"Name": doc["skills"][k]["name"], "Souls": at}
                                      for k, at in zip(f["skills"], skill_tiers(f, side, s.get("boss")))]}
        souls[s["id"]] = {"Id": s["id"], "Name": s["name"], "Act": s["act"], "Match": s.get("match", []),
                          "Exclude": s.get("exclude", []), "Boss": bool(s.get("boss")), "Forms": forms}
    by_guid = {g: s["id"] for s in doc["souls"] for g in s.get("guids", [])}
    return souls, [s["id"] for s in doc["souls"]], CONTAINER, by_guid
