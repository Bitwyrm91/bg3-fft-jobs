"""Smart Casting (Wizard support, Fell Seal; user, 2026-10-14: every area ability of this mod, all jobs): while the
caster has the passive FFTJ_SmartCasting, area attacks leave out the caster and its allies and area help (heals,
buffs) leaves out enemies. BG3's own spells are not touched.

How: vanilla Sculpt Spells puts `not (HasPassive('SculptSpells', context.Source) and Ally())` into each evocation's
TargetConditions; build.py calls apply() on our generated spell files (not the hotbar menus) and this module adds

    harmful area spell:  not (HasPassive('FFTJ_SmartCasting', context.Source) and (Ally() or Self()))
    helpful area spell:  not (HasPassive('FFTJ_SmartCasting', context.Source) and Enemy())

to the TargetConditions of every area spell that does not leave those targets out already. A spell is an area spell
when its AreaRadius or ExplodeRadius is above 0 or it is a Zone/Wall/Cone; harmful when it is flagged IsHarmful, its
intent is Damage/Debuff/Control, it rolls (SpellRoll) or it deals damage; helpful when it is none of that and heals or
its intent is Healing/Buff. Fields come through the `using` chain: our entries first, then the vanilla carrier from
data/vanilla_spells.json (the resolved fields of every vanilla spell our spells use; refreshed locally with
`python tools/smartcast.py --vanilla` from the extracted game data, like menu_gen.py --vanilla-icons). A child that
would inherit the new condition from its parent gets no line of its own.

The Lua-driven bursts (Chemist flasks) check the passive in Server/Effects.lua (Effects.Spared).
UNVERIFIED IN GAME: Self() inside a TargetConditions sub-clause (vanilla uses Self() in TargetConditions).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "data" / "vanilla_spells.json"
VANILLA_ROOT = Path(r"C:\Users\berus\GameModding\decomp\bg3")
PASSIVE = "FFTJ_SmartCasting"
HARM_CLAUSE = f"not (HasPassive('{PASSIVE}', context.Source) and (Ally() or Self()))"
HELP_CLAUSE = f"not (HasPassive('{PASSIVE}', context.Source) and Enemy())"
FIELDS = ("SpellType", "TargetConditions", "AreaRadius", "ExplodeRadius", "SpellFlags", "VerbalIntent", "SpellRoll",
          "SpellSuccess", "SpellFail", "SpellProperties")
SKIP_FILES = ("Spell_FFTJ_Menu.txt",)
AREA_TYPES = ("Zone", "Wall", "Cone")
NOT_AREA = ("Teleportation",)  # Raise / Revive / Phoenix Down: one corpse, whatever the carrier's radius
HARM_INTENTS = ("Damage", "Debuff", "Control")
HELP_INTENTS = ("Healing", "Buff")
ENTRY_RE = re.compile(r'^new entry "([^"]+)"')
TYPE_RE = re.compile(r'^type "([^"]+)"')
USING_RE = re.compile(r'^using "([^"]+)"')
DATA_RE = re.compile(r'^data "([^"]+)" "(.*)"$')
# a DealDamage aimed at the caster itself (recoil, HP costs) does not make a spell harmful to its targets
OWN_DAMAGE = re.compile(r"DealDamage\(\s*SELF\s*,")
EXCLUDES_ALLIES = re.compile(r"not\s+Ally\(\)|(?<!not )(?<!not\s)\bEnemy\(\)")
EXCLUDES_ENEMIES = re.compile(r"not\s+Enemy\(\)|(?<!not )(?<!not\s)\bAlly\(\)")


def _parse(text):
    """[(name, type, using, {field: value})] of one stats file, in order."""
    out, cur = [], None
    for line in text.split("\n"):
        m = ENTRY_RE.match(line)
        if m:
            cur = [m.group(1), None, None, {}]
            out.append(cur)
            continue
        if cur is None:
            continue
        m = TYPE_RE.match(line)
        if m:
            cur[1] = m.group(1)
            continue
        m = USING_RE.match(line)
        if m:
            cur[2] = m.group(1)
            continue
        m = DATA_RE.match(line)
        if m:
            cur[3][m.group(1)] = m.group(2)
    return out


def load_cache():
    return json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}


class Resolver:
    def __init__(self, entries, vanilla):
        self.entries = entries  # name -> (type, using, fields)
        self.vanilla = vanilla
        self.missing = set()

    def field(self, name, key):
        seen = set()
        while name in self.entries and name not in seen:
            seen.add(name)
            _, using, fields = self.entries[name]
            if key in fields:
                return fields[key]
            name = using
        if name and name not in self.entries:
            if name not in self.vanilla:
                self.missing.add(name)
                return None
            return self.vanilla[name].get(key)
        return None

    def tc_owner(self, name, given=()):
        """The entry (ours) whose TargetConditions `name` uses (its own line, or one this module gives it: `given`),
        or None when it comes from vanilla / nowhere."""
        seen = set()
        while name in self.entries and name not in seen:
            seen.add(name)
            _, using, fields = self.entries[name]
            if "TargetConditions" in fields or name in given:
                return name
            name = using
        return None

    def known(self, name):
        """Every field resolvable (no unknown vanilla parent on the way)."""
        before = len(self.missing)
        self.field(name, "SpellType")
        return len(self.missing) == before


def _num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def kind(res, name):
    """'harm', 'help' or None (not an area spell, or neither)."""
    st = res.field(name, "SpellType") or ""
    if st in NOT_AREA:
        return None
    area = _num(res.field(name, "AreaRadius")) > 0 or _num(res.field(name, "ExplodeRadius")) > 0 or st in AREA_TYPES
    if not area:
        return None
    flags = res.field(name, "SpellFlags") or ""
    intent = res.field(name, "VerbalIntent") or ""
    effects = ";".join(res.field(name, f) or "" for f in ("SpellSuccess", "SpellFail", "SpellProperties"))
    deals = "DealDamage(" in OWN_DAMAGE.sub("", effects)
    if "IsHarmful" in flags.split(";") or intent in HARM_INTENTS or (res.field(name, "SpellRoll") or "") or deals:
        return "harm"
    if "RegainHitPoints(" in effects or intent in HELP_INTENTS:
        return "help"
    return None


def desired_tc(res, name):
    base = res.field(name, "TargetConditions") or ""
    k = kind(res, name)
    if k == "harm" and not EXCLUDES_ALLIES.search(base) and HARM_CLAUSE not in base:
        clause = HARM_CLAUSE
    elif k == "help" and not EXCLUDES_ENEMIES.search(base) and HELP_CLAUSE not in base:
        clause = HELP_CLAUSE
    else:
        return base
    return f"({base}) and {clause}" if base.strip() else clause


def apply(texts, vanilla=None):
    """texts: {file name: stats text} of every generated stats file. Returns ({file name: new text} for the files
    that changed, sorted names of vanilla parents missing from the cache, count of spells changed)."""
    vanilla = load_cache() if vanilla is None else vanilla
    parsed = {fname: _parse(t) for fname, t in texts.items()}
    entries = {}
    for rows in parsed.values():
        for name, typ, using, fields in rows:
            entries[name] = (typ, using, fields)
    res = Resolver(entries, vanilla)
    final = {}  # name -> the TargetConditions it ends up with (ours only)

    def final_tc(name):
        if name in final:
            return final[name]
        owner = res.tc_owner(name, final)
        return final_tc(owner) if owner and owner != name else (res.field(name, "TargetConditions") or "")

    # parents before children: process in `using` depth order so final_tc of a parent is known
    def depth(name, seen=()):
        using = entries[name][1]
        return 0 if using not in entries or using in seen else 1 + depth(using, seen + (name,))

    todo = [(fname, name) for fname, rows in parsed.items() if fname not in SKIP_FILES
            for name, typ, _, _ in rows if typ == "SpellData"]
    todo.sort(key=lambda fn: depth(fn[1]))
    changes = {}  # file -> {entry: new TC}
    count = 0
    for fname, name in todo:
        if not res.known(name):
            continue
        want = desired_tc(res, name)
        own = entries[name][2].get("TargetConditions")
        if own is not None:
            if want != own:
                changes.setdefault(fname, {})[name] = want
                count += 1
            final[name] = want
            continue
        owner = res.tc_owner(name, final)
        inherited = final_tc(owner) if owner else (res.field(name, "TargetConditions") or "")
        if want != inherited:
            changes.setdefault(fname, {})[name] = want
            count += 1
            final[name] = want
    out = {}
    for fname, per in changes.items():
        out[fname] = _rewrite(texts[fname], per)
    return out, sorted(res.missing), count


def _rewrite(text, per):
    """Sets data "TargetConditions" of the entries in `per` (replacing their line, or added after the header)."""
    lines, cur, done = [], None, set()

    def add_missing():
        if cur in per and cur not in done:
            i = len(lines)
            while i > 0 and lines[i - 1] == "":
                i -= 1
            lines.insert(i, f'data "TargetConditions" "{per[cur]}"')
            done.add(cur)

    for line in text.split("\n"):
        m = ENTRY_RE.match(line)
        if m:
            add_missing()
            cur = m.group(1)
        elif cur in per and line.startswith('data "TargetConditions" '):
            line = f'data "TargetConditions" "{per[cur]}"'
            done.add(cur)
        lines.append(line)
    add_missing()
    return "\n".join(lines)


# ---------------------------------------------------------------- local refresh of the vanilla cache

def refresh(mod_texts):
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import vq  # noqa: E402  (reads the extracted game data)
    vanilla = vq.load()
    ours = {}
    for t in mod_texts:
        for name, typ, using, fields in _parse(t):
            ours[name] = using
    parents = {u for u in ours.values() if u and u not in ours}
    out = {}
    for p in sorted(parents):
        if p not in vanilla:
            continue
        row = {}
        for key in FIELDS:
            name, seen = p, set()
            while name in vanilla and name not in seen:
                seen.add(name)
                if key in vanilla[name]["data"]:
                    row[key] = vanilla[name]["data"][key]
                    break
                name = vanilla[name]["using"]
        out[p] = row
    CACHE.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(out)} vanilla spells written to {CACHE.relative_to(ROOT)}")


if __name__ == "__main__":
    if "--vanilla" in sys.argv:
        stats_dir = ROOT / "Mod" / "Public" / "FFTJobs" / "Stats" / "Generated" / "Data"
        refresh([p.read_text(encoding="utf-8") for p in sorted(stats_dir.glob("Spell_*.txt"))])
    else:
        print(__doc__)
