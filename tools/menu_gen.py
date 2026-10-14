"""Job menus in BG3's own UI (NWP item 7): spell containers on the hotbar, generated from data/fft_jobs.json.

- Change Job (Shout_FFTJ_ChangeJob) and Change Subclass (Shout_FFTJ_SecondaryJob): one entry per job. Like Soul
  Incarnation, the containers list nothing (a container shows every ContainerSpells entry, learned or not); the
  server grants each entry, which joins its container by SpellContainerID. Regular jobs (no group, or WotL) are always
  listed: open ones by name, locked ones as a greyed "???" entry whose tooltip says what unlocks the job (user,
  2026-10-14). Special jobs appear only once the character unlocks them. Soul Collector is left out (NWP).
- Learn: one container per job (Shout_FFTJ_LearnFrom_<Job>), granted for the job and the secondary; its entries are
  the job's abilities the character has not learned (Shout_FFTJ_Learn_<AbilityId>). The tooltip gives the JP cost;
  ExtraDescription is one string per job that the client rewrites with the controlled character's unspent JP.

Casting any entry does nothing by itself; Service:OnMenuSpell acts on CastedSpell (SetPrimary / SetSecondary / Learn).

  python tools/menu_gen.py --vanilla-icons   refreshes data/vanilla_icons.json from the extracted vanilla stats
                                             (needs decomp\\bg3; run after build.py when new vanilla parents appear)
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VANILLA_ICONS = ROOT / "data" / "vanilla_icons.json"
STATS_DIR = ROOT / "Mod" / "Public" / "FFTJobs" / "Stats" / "Generated" / "Data"
SPELL_FILE = "Spell_FFTJ_Menu.txt"

CHANGE = "Shout_FFTJ_ChangeJob"
SECONDARY = "Shout_FFTJ_SecondaryJob"
CLEAR = "Shout_FFTJ_SecondaryJob_None"
LEARN_FROM = "Shout_FFTJ_LearnFrom_"
LEARN = "Shout_FFTJ_Learn_"
LOCKED_SUFFIX = "_Locked"
# never granted: a locked entry's RequirementConditions asks for it, so the entry is always greyed out
NEVER_PASSIVE = "FFTJ_MenuLocked"
PARENT = "Shout_FFTJ_JobBoard"  # free, Level 0, self-cast, does nothing
EXCLUDED_GROUPS = ("Soul",)  # Soul Collector: NWP (user, 2026-10-14)
REGULAR_GROUPS = ("", "WotL", "FellSeal")

ICONS = {CHANGE: "PassiveFeature_PactOfTheTome", SECONDARY: "PassiveFeature_BookOfAncientSecrets",
         CLEAR: "Skill_Warlock_DismissPactWeapon", "locked": "Spell_Abjuration_ArcaneLock",
         "fallback": "Skill_Wizard_LearnSpell"}
GRANT_KINDS = ("spells", "passives", "statuses")
TYPE_TEXT = {"Action": "Action: usable while this is your job or subclass.",
             "Reaction": "Reaction: equip it in the reaction slot (Job Board).",
             "Support": "Passive: equip it in a passive slot (Job Board).",
             "Movement": "Passive: equip it in a passive slot (Job Board)."}


def menu_jobs(jobs_doc):
    return [j for j in jobs_doc["jobs"] if j.get("implemented") and j.get("group", "") not in EXCLUDED_GROUPS]


def is_regular(job):
    return job.get("group", "") in REGULAR_GROUPS


def requirement_text(jobs_doc, job):
    names = {j["id"]: j["name"] for j in jobs_doc["jobs"]}
    badges = {b["id"]: b["name"] for b in jobs_doc.get("badges", [])}
    parts = []
    for r in job.get("unlock", []):
        if "badge" in r:
            parts.append(badges.get(r["badge"], r["badge"]))
        elif "badges" in r:
            parts.append(f"any {r['badges']} boss badges")
        elif "kills" in r:
            parts.append(f"{r['kills']} kills")
        elif r.get("mastered"):
            parts.append(f"{names[r['job']]} mastered")
        else:
            parts.append(f"{names[r['job']]} Lv{r['level']}")
    return ", ".join(parts) or "nothing"


def strings(jobs_doc):
    t = {"menu.change.name": "Change Job",
         "menu.change.desc": "Pick this character's job. Locked jobs show as ???; hover one to see what unlocks it. "
                             "Out of combat only (config).",
         "menu.secondary.name": "Change Subclass",
         "menu.secondary.desc": "Pick a subclass: a second job whose learned actions this character can also use.",
         "menu.clear.name": "No Subclass",
         "menu.clear.desc": "Clears the subclass.",
         "menu.locked.name": "???"}
    for j in menu_jobs(jobs_doc):
        jid, name = j["id"], j["name"]
        need = requirement_text(jobs_doc, j)
        t[f"menu.job.{jid}.name"] = name
        t[f"menu.job.{jid}.desc"] = f"{j.get('description', '')} Makes {name} this character's job.".strip()
        t[f"menu.sec.{jid}.name"] = f"{j.get('skillset') or name} ({name})"
        t[f"menu.sec.{jid}.desc"] = f"Use {name}'s learned actions as the subclass."
        t[f"menu.locked.{jid}.desc"] = f"Locked job. Needs: {need}."
        t[f"menu.learn.{jid}.name"] = f"Learn: {name}"
        t[f"menu.learn.{jid}.desc"] = (f"Spend {name} JP on its abilities. Learned ones leave this list; "
                                       f"the Job Board shows them all.")
        # rewritten in game by the client (Client/JobMenu.lua) with the controlled character's JP
        t[f"menu.have.{jid}"] = f"{name} JP: open the Job Board once to refresh."
    jobs = {j["id"] for j in menu_jobs(jobs_doc)}
    for a in jobs_doc["abilities"]:
        if a["job"] in jobs:
            t[f"menu.ability.{a['id']}.desc"] = (f"{a['description']} {TYPE_TEXT.get(a['type'], '')} "
                                                 f"Cost: {a['cost']} JP.").replace("  ", " ")
    return t


def _resolver(entries, vanilla):
    by_name = {e["name"]: e for e in entries}

    def icon(name):
        seen = set()
        while name and name not in seen:
            seen.add(name)
            e = by_name.get(name)
            if e is None:
                return vanilla.get(name)
            for key, value in e["data"]:
                if key == "Icon" and value:
                    return value
            name = e["using"]
        return None
    return icon


def ability_icon(a, icon):
    for kind in GRANT_KINDS:
        for sid in a["grants"].get(kind, []):
            found = icon(sid)
            if found:
                return found
    return None


def stats(jobs_doc, entries, H):
    """The menu spells (text of SPELL_FILE) and the extra icon keys (entry -> art key) for build.inject_icons."""
    vanilla = json.loads(VANILLA_ICONS.read_text(encoding="utf-8")) if VANILLA_ICONS.exists() else {}
    icon = _resolver(entries, vanilla)
    keys = {}
    out = []

    def entry(name, container=None, flags=None, **data):
        out.extend([f'new entry "{name}"', 'type "SpellData"', 'data "SpellType" "Shout"', f'using "{PARENT}"'])
        if flags is not None:
            out.append(f'data "SpellFlags" "{flags}"')
        if container is not None:
            out.append('data "ContainerSpells" ""')
        out.append('data "SpellContainerID" ""')
        for k, v in data.items():
            out.append(f'data "{k}" "{v}"')
        out.append("")

    def child(name, parent, **data):
        out.extend([f'new entry "{name}"', 'type "SpellData"', 'data "SpellType" "Shout"', f'using "{PARENT}"',
                    f'data "SpellContainerID" "{parent}"'])
        for k, v in data.items():
            out.append(f'data "{k}" "{v}"')
        out.append("")

    for cid, key in ((CHANGE, "change"), (SECONDARY, "secondary")):
        entry(cid, container=True, flags="IsLinkedSpellContainer", Icon=ICONS[cid],
              DisplayName=H(f"menu.{key}.name"), Description=H(f"menu.{key}.desc"))
    child(CLEAR, SECONDARY, Icon=ICONS[CLEAR], DisplayName=H("menu.clear.name"), Description=H("menu.clear.desc"))
    locked = {"Icon": ICONS["locked"], "DisplayName": H("menu.locked.name"),
              "RequirementConditions": f"HasPassive('{NEVER_PASSIVE}',context.Source)"}
    jobs = menu_jobs(jobs_doc)
    abilities_by_job = {}
    for a in jobs_doc["abilities"]:
        abilities_by_job.setdefault(a["job"], []).append(a)
    for j in jobs:
        jid = j["id"]
        emblem = None
        for pid in j.get("innate", {}).get("passives", []):
            emblem = emblem or icon(pid)
        emblem = emblem or ICONS["fallback"]
        for cid, prefix, name_key in ((CHANGE, CHANGE, f"menu.job.{jid}.name"), (SECONDARY, SECONDARY, f"menu.sec.{jid}.name")):
            sp = f"{prefix}_{jid}"
            keys[sp] = "Job_" + jid
            desc = f"menu.job.{jid}.desc" if cid == CHANGE else f"menu.sec.{jid}.desc"
            child(sp, cid, Icon=emblem, DisplayName=H(name_key),
                  Description=H(desc))
            if is_regular(j):
                child(sp + LOCKED_SUFFIX, cid, Description=H(f"menu.locked.{jid}.desc"), **locked)
        abilities = abilities_by_job.get(jid, [])
        if not abilities:
            continue
        lf = LEARN_FROM + jid
        keys[lf] = "Job_" + jid
        entry(lf, container=True, flags="IsLinkedSpellContainer", Icon=emblem,
              DisplayName=H(f"menu.learn.{jid}.name"), Description=H(f"menu.learn.{jid}.desc"))
        for a in abilities:
            sp = LEARN + a["id"]
            keys[sp] = a["id"]
            child(sp, lf, Icon=ability_icon(a, icon) or emblem, DisplayName=H(f"ability.{a['id']}.name"),
                  Description=H(f"menu.ability.{a['id']}.desc"), ExtraDescription=H(f"menu.have.{jid}"))
    return "\n".join(out).rstrip("\n") + "\n", keys


def lua_data(jobs_doc, handle):
    """JobMenu table for Shared/GeneratedData.lua (Rules.MenuGrants, Service:OnMenuSpell, Client/JobMenu.lua)."""
    jobs = menu_jobs(jobs_doc)
    has_abilities = {a["job"] for a in jobs_doc["abilities"]}
    learn = {a["id"]: LEARN + a["id"] for a in jobs_doc["abilities"] if a["job"] in {j["id"] for j in jobs}}
    return {
        "Change": CHANGE, "Secondary": SECONDARY, "Clear": CLEAR,
        "Jobs": [j["id"] for j in jobs],
        "Regular": {j["id"]: True for j in jobs if is_regular(j)},
        "Primary": {j["id"]: f"{CHANGE}_{j['id']}" for j in jobs},
        "SecondaryOf": {j["id"]: f"{SECONDARY}_{j['id']}" for j in jobs},
        "LockedSuffix": LOCKED_SUFFIX,
        "LearnFrom": {j["id"]: LEARN_FROM + j["id"] for j in jobs if j["id"] in has_abilities},
        "Learn": learn,
        # localization handles (no ";1") of the per-job JP line the client rewrites
        "HaveHandle": {j["id"]: handle(f"menu.have.{j['id']}") for j in jobs},
    }


def refresh_vanilla_icons():
    """Icons of the vanilla entries our generated stats inherit from (resolved through `using`)."""
    sys.path.insert(0, str(ROOT / "tools"))
    import vq  # noqa: E402 (reads C:\\Users\\berus\\GameModding\\decomp\\bg3)
    van = vq.load()
    ours, used = set(), set()
    for f in STATS_DIR.glob("*.txt"):
        text = f.read_text(encoding="utf-8")
        ours |= set(re.findall(r'^new entry "([^"]+)"', text, re.M))
        used |= set(re.findall(r'^using "([^"]+)"', text, re.M))
    jobs_doc = json.loads((ROOT / "data" / "fft_jobs.json").read_text(encoding="utf-8"))
    for a in jobs_doc["abilities"]:
        for kind in GRANT_KINDS:
            used |= set(a["grants"].get(kind, []))
    out = {}
    for name in sorted(used - ours):
        seen, cur = set(), name
        while cur in van and cur not in seen:
            seen.add(cur)
            ic = van[cur]["data"].get("Icon")
            if ic:
                out[name] = ic
                break
            cur = van[cur]["using"]
    VANILLA_ICONS.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(out)} vanilla icons written to {VANILLA_ICONS.relative_to(ROOT)}")


if __name__ == "__main__":
    if "--vanilla-icons" in sys.argv:
        refresh_vanilla_icons()
    else:
        print(__doc__)
