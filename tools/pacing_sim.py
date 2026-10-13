#!/usr/bin/env python3
"""Pacing simulator for the FFT job system in BG3.

Plays a whole party through a BG3 playthrough with the same JP formulas as the Lua engine
(Server/Rules.lua) and reports, per preset and per LOW/TYPICAL/HIGH estimate, when jobs unlock and are mastered.

Usage:
  python3 tools/pacing_sim.py                     summary for every preset
  python3 tools/pacing_sim.py --preset Classic --detail TYPICAL
  python3 tools/pacing_sim.py --set JP.XPShare=0.2 --set JP.Victory.Base=30
  python3 tools/pacing_sim.py --jp-boost          characters equip JP Boost once learned
  python3 tools/pacing_sim.py --markdown          the tables used in DESIGN.md
  python3 tools/pacing_sim.py --selftest          formula checks + the pacing target for the default preset

Every estimate below is an assumption, not a measurement: replace them with the in-game telemetry
(Script Extender/FFTJobs/telemetry.jsonl) once there is real data.
"""
import argparse
import copy
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# BG3 cumulative XP for levels 1-12 (Wargamer / Gamer Guides table; eip.gg lists slightly lower values for 6-11).
XP_TABLE = [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000, 85000, 100000]

# Playthrough estimates. fights: combat encounters the party fights per act (Larian counted ~80 encounters in
# Early Access, i.e. Act 1). casts: counted casts (actions and bonus actions) per character per fight.
# xp: cumulative XP at the end of each act (player reports: ~L6-7.5 after Act 1, ~L10-11 after Act 2, L12 in Act 3).
# rests: long rests per act.
ESTIMATES = {
    "LOW": {"fights": [30, 20, 30], "casts": 4, "bonusShare": 0.25, "xp": [9000, 40000, 85000], "rests": [8, 6, 8]},
    "TYPICAL": {"fights": [45, 30, 45], "casts": 6, "bonusShare": 0.25, "xp": [18000, 55000, 100000], "rests": [12, 9, 12]},
    "HIGH": {"fights": [65, 40, 65], "casts": 9, "bonusShare": 0.25, "xp": [30000, 75000, 100000], "rests": [16, 12, 16]},
}

# Enemies each fighter defeats per fight (unlock requirements like the Dark Knight's 20 kills); an assumption.
KILLS_PER_FIGHT = 1

# The party: four fighters (active party) and two companions waiting in camp, each with a job plan along the unlock
# tree. A character masters the jobs of its plan in order; when the next one is still locked it levels the missing
# prerequisite first (pick_job). Implemented jobs missing from a plan are appended at its end.
PARTY = [
    {"name": "Fighter", "active": True, "order": [
        "Squire", "Knight", "Monk", "Archer", "Thief", "Geomancer", "Dragoon", "Samurai", "Ninja", "Dancer",
        "Chemist", "WhiteMage", "BlackMage", "Mystic", "TimeMage", "Orator", "Summoner", "Bard", "Arithmetician", "Mime"]},
    {"name": "Caster", "active": True, "order": [
        "Chemist", "BlackMage", "WhiteMage", "TimeMage", "Mystic", "Summoner", "Orator", "Arithmetician", "Bard",
        "Squire", "Knight", "Archer", "Monk", "Thief", "Geomancer", "Dragoon", "Dancer", "Samurai", "Ninja", "Mime"]},
    {"name": "Healer", "active": True, "order": [
        "Chemist", "WhiteMage", "Mystic", "Orator", "Mime", "BlackMage", "TimeMage", "Summoner", "Bard",
        "Arithmetician", "Squire", "Archer", "Knight", "Monk", "Thief", "Geomancer", "Dragoon", "Dancer", "Ninja", "Samurai"]},
    {"name": "Ranger", "active": True, "order": [
        "Squire", "Archer", "Thief", "Dragoon", "Chemist", "Knight", "Monk", "Geomancer", "Ninja", "Dancer",
        "WhiteMage", "BlackMage", "Samurai", "Mystic", "TimeMage", "Orator", "Summoner", "Bard", "Arithmetician", "Mime"]},
    {"name": "Camp A", "active": False, "order": [
        "Squire", "Knight", "Archer", "Monk", "Thief", "Chemist", "Geomancer", "Dragoon", "WhiteMage", "BlackMage",
        "Samurai", "Ninja", "Mystic", "TimeMage", "Orator", "Summoner", "Dancer", "Bard", "Arithmetician", "Mime"]},
    {"name": "Camp B", "active": False, "order": [
        "Chemist", "WhiteMage", "BlackMage", "Mystic", "TimeMage", "Squire", "Knight", "Archer", "Orator", "Summoner",
        "Monk", "Thief", "Arithmetician", "Bard", "Geomancer", "Dragoon", "Dancer", "Samurai", "Ninja", "Mime"]},
]


def load():
    jobs_doc = json.loads((ROOT / "data" / "fft_jobs.json").read_text(encoding="utf-8"))
    cfg_doc = json.loads((ROOT / "data" / "config_defaults.json").read_text(encoding="utf-8"))
    return jobs_doc, cfg_doc


def merge(base, over):
    out = copy.deepcopy(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def effective_config(cfg_doc, preset, sets):
    cfg = merge(cfg_doc["defaults"], cfg_doc["presets"][preset]["values"])
    for item in sets or []:
        key, _, raw = item.partition("=")
        node = cfg
        parts = key.split(".")
        for p in parts[:-1]:
            node = node[p]
        old = node[parts[-1]]
        node[parts[-1]] = (raw.lower() == "true") if isinstance(old, bool) else type(old)(float(raw)) if isinstance(old, (int, float)) else raw
    return cfg


# ---------------------------------------------------------------- the engine's formulas (mirror Server/Rules.lua)

def job_level(earned, thresholds):
    level = 1
    for t in thresholds:
        if earned >= t:
            level += 1
        else:
            break
    return level


def action_formula(jp, job_lv, char_lv):
    a = jp["Action"]
    v = a["Base"] + a["PerJobLevel"] * job_lv
    if a["CharLevelDivisor"] > 0:
        v += math.floor(char_lv / a["CharLevelDivisor"])
    return v


def boost(jp, source, has_boost):
    return jp["Boost"]["Multiplier"] if has_boost and jp["Boost"][source] else 1.0


def action_jp(jp, job_lv, char_lv, weight, has_boost):
    f = action_formula(jp, job_lv, char_lv)
    g = jp["GlobalMultiplier"]
    own = f * (1 + jp["Action"]["EnhancedBonus"]) * jp["Action"]["Multiplier"] * weight * boost(jp, "Action", has_boost) * g
    spill = f * jp["Action"]["Multiplier"] * weight * jp["Spillover"]["Share"] * g
    return own, spill


def victory_jp(jp, char_lv, has_boost):
    return (jp["Victory"]["Base"] + jp["Victory"]["PerCharLevel"] * char_lv) * boost(jp, "Victory", has_boost) * jp["GlobalMultiplier"]


def xp_jp(jp, xp, has_boost):
    return xp * jp["XPShare"] * boost(jp, "XP", has_boost) * jp["GlobalMultiplier"]


def rest_jp(jp, has_boost):
    return jp["LongRest"] * boost(jp, "LongRest", has_boost) * jp["GlobalMultiplier"]


def char_level(xp):
    lv = 1
    for i, need in enumerate(XP_TABLE):
        if xp >= need:
            lv = i + 1
    return lv


# JP source (as counted in telemetry) -> its key in JP.Shared.Sources. Spill, Manual and Shared itself never share.
SHARED_SOURCE_KEY = {"Action": "Action", "Victory": "Victory", "XP": "XP", "Rest": "LongRest", "Camp": "Camp"}


def shared_jp(jp, amount, source):
    """Shared learning: the part of a character's own JP gain that also goes into each of its other jobs."""
    sh = jp["Shared"]
    key = SHARED_SOURCE_KEY.get(source)
    if sh["Share"] <= 0 or key is None or not sh["Sources"].get(key, False):
        return 0.0
    return amount * sh["Share"]


def shared_targets(jp, impl, from_job, unlocked, fight_jobs):
    """The jobs that get shared JP: every other implemented job (AllJobs) or only the jobs used in the fight (FightJobs)."""
    sh = jp["Shared"]
    out = []
    for j in impl:
        if j == from_job:
            continue
        if sh["Scope"] != "AllJobs" and j not in fight_jobs:
            continue
        if sh["RequireUnlocked"] and j not in unlocked:
            continue
        out.append(j)
    return out


# ---------------------------------------------------------------- simulation

class Char:
    def __init__(self, plan, jobs, abilities, cfg):
        self.name = plan["name"]
        self.active = plan["active"]
        self.order = [j for j in plan["order"] if j in jobs] + [j for j in jobs if j not in plan["order"]]
        self.earned = {j: 0.0 for j in jobs}
        self.unspent = {j: 0.0 for j in jobs}
        self.learned = set()
        self.unlocked = set(cfg["Rules"]["StartingUnlocked"])
        self.primary = self.order[0]
        self.unlocked_at = {j: "start" for j in self.unlocked}
        self.mastered_at = {}
        self.boost = False
        self.total = 0.0
        self.kills = 0
        self.sources = {}


def simulate(jobs_doc, cfg, estimate, jp_boost=False):
    jp = cfg["JP"]
    th = cfg["JobLevels"]["Thresholds"]
    impl = [j["id"] for j in jobs_doc["jobs"] if j.get("implemented")]
    unlock_rules = {j["id"]: j.get("unlock", []) for j in jobs_doc["jobs"]}
    abilities = {}
    by_job = {j: [] for j in impl}
    for a in jobs_doc["abilities"]:
        abilities[a["id"]] = a
        by_job[a["job"]].append(a["id"])
    party = [Char(p, impl, abilities, cfg) for p in PARTY]
    est = ESTIMATES[estimate]
    weight = (1 - est["bonusShare"]) + est["bonusShare"] * jp["Action"]["BonusActionWeight"]
    if not jp["Action"]["RequireActionCost"]:
        weight = 1.0

    def level_of(c, j):
        return job_level(c.earned[j], th)

    def credit(c, j, amount, source):
        c.earned[j] += amount
        c.unspent[j] += amount
        c.total += amount
        c.sources[source] = c.sources.get(source, 0.0) + amount

    def add(c, j, amount, source):
        credit(c, j, amount, source)
        share = shared_jp(jp, amount, source)
        if share > 0:
            # FightJobs: the fighters' jobs. Every JP gain in this model belongs to the current or the latest fight.
            fight_jobs = {d.primary for d in party if d.active}
            for t in shared_targets(jp, impl, j, c.unlocked, fight_jobs):
                credit(c, t, share, "Shared")

    top_level = len(th) + 1

    def mastered(c, j):
        # like Rules.IsMastered: a job without abilities (Mime) is mastered at the top job level
        if not by_job[j]:
            return j in c.unlocked and level_of(c, j) >= top_level
        return all(a in c.learned for a in by_job[j])

    def req_met(c, r):
        # badges are assumed found; kills come with the fights (KILLS_PER_FIGHT)
        if "kills" in r:
            return c.kills >= r["kills"]
        if "job" not in r:
            return True
        if r.get("mastered"):
            return r["job"] in c.unlocked and mastered(c, r["job"])
        return level_of(c, r["job"]) >= r["level"]

    def route(c, j, seen):
        """The job to work in to get j: j itself once unlocked, else the first prerequisite still missing."""
        if j in c.unlocked:
            return j
        for r in unlock_rules[j]:
            if "job" in r and r["job"] in impl and r["job"] not in seen and not req_met(c, r):
                got = route(c, r["job"], seen | {j})
                if got:
                    return got
        return None

    def pick_job(c):
        """The first job of the plan not mastered yet, or the prerequisite that opens it."""
        for j in c.order:
            if j in c.unlocked and mastered(c, j):
                continue
            got = route(c, j, set())
            if got:
                return got
        return c.primary

    def unlock(c, when):
        for j in impl:
            if j not in c.unlocked and all(req_met(c, r) for r in unlock_rules[j]):
                c.unlocked.add(j)
                c.unlocked_at[j] = when

    def settle(c, when):
        for j in impl:
            if j not in c.unlocked:
                continue
            for aid in sorted(by_job[j], key=lambda a: abilities[a]["cost"]):
                if aid not in c.learned and c.unspent[j] >= abilities[aid]["cost"]:
                    c.unspent[j] -= abilities[aid]["cost"]
                    c.learned.add(aid)
            if j not in c.mastered_at and mastered(c, j):
                c.mastered_at[j] = when
        if jp_boost and "JPBoost" in c.learned:
            c.boost = True
        c.primary = pick_job(c)

    xp = 0.0
    fight_no = 0
    for act in range(3):
        fights = est["fights"][act]
        xp_per_fight = (est["xp"][act] - (est["xp"][act - 1] if act else 0)) / fights
        rest_every = fights / est["rests"][act]
        next_rest = rest_every
        for f in range(1, fights + 1):
            fight_no += 1
            when = f"A{act + 1}.{f}"
            lv = char_level(xp)
            fighters = [c for c in party if c.active]
            own = {}
            for c in fighters:
                c.kills += KILLS_PER_FIGHT
                o, s = action_jp(jp, level_of(c, c.primary), lv, weight, c.boost)
                own[c.name] = o * est["casts"]
                add(c, c.primary, own[c.name], "Action")
                for d in fighters:
                    if d is not c and (not jp["Spillover"]["RequireUnlocked"] or c.primary in d.unlocked):
                        add(d, c.primary, s * est["casts"], "Spill")
            for c in fighters:
                v = victory_jp(jp, lv, c.boost)
                own[c.name] += v
                add(c, c.primary, v, "Victory")
            camp = sum(own.values()) / len(own) * jp["Camp"]["Share"]
            for c in party:
                if not c.active:
                    add(c, c.primary, camp, "Camp")
            xp += xp_per_fight
            for c in party:
                add(c, c.primary, xp_jp(jp, xp_per_fight, c.boost), "XP")
            if f >= next_rest - 1e-9:
                next_rest += rest_every
                for c in party:
                    add(c, c.primary, rest_jp(jp, c.boost), "Rest")
            for c in party:
                unlock(c, when)
                settle(c, when)
    return party, fight_no


def act_of(when):
    return 99 if when is None else (0 if when == "start" else int(when[1]))


def full_tree_requirement(jobs_doc, th):
    need = {}
    for j in jobs_doc["jobs"]:
        for r in j.get("unlock", []):
            if "job" in r:
                need[r["job"]] = max(need.get(r["job"], 1), len(th) + 1 if r.get("mastered") else r["level"])
    return sum(th[lv - 2] for lv in need.values() if lv >= 2), need


# ---------------------------------------------------------------- reports

def summary_rows(jobs_doc, cfg_doc, presets, sets, jp_boost):
    rows = []
    for preset in presets:
        cfg = effective_config(cfg_doc, preset, sets)
        tree_jp, _ = full_tree_requirement(jobs_doc, cfg["JobLevels"]["Thresholds"])
        for est in ESTIMATES:
            party, _ = simulate(jobs_doc, cfg, est, jp_boost)
            fighters = [c for c in party if c.active]
            camp = [c for c in party if not c.active]
            def span(counts):
                return f"{min(counts)}-{max(counts)}" if min(counts) != max(counts) else str(min(counts))

            mastered_by = [span([sum(1 for w in c.mastered_at.values() if act_of(w) <= act) for c in fighters]) for act in (1, 2, 3)]
            unlocked_by = [span([sum(1 for w in c.unlocked_at.values() if act_of(w) <= act) for c in fighters]) for act in (1, 2, 3)]
            camp_m = [len(c.mastered_at) for c in camp]
            first = min((w for c in fighters for w in c.mastered_at.values()), key=fight_key, default="-")
            all_open = party_all_open(party, jobs_doc)
            avg_total = sum(c.total for c in fighters) / len(fighters)
            rows.append({
                "preset": preset, "estimate": est, "jp": avg_total, "camp_jp": sum(c.total for c in camp) / len(camp),
                "mastered": mastered_by, "unlocked": unlocked_by, "all_open": all_open or "never",
                "camp": span(camp_m), "first": first, "tree": avg_total / tree_jp,
                "min_mastered": min(len(c.mastered_at) for c in fighters),
                "min_unlocked": min(len(c.unlocked_at) for c in fighters),
            })
    return rows


def fight_key(when):
    return (act_of(when), 0 if when in (None, "start") else int(when.split(".")[1]))


def target_jobs(jobs_doc):
    """The jobs the pacing target counts: the 20 TIC jobs. Bonus jobs (a "group" such as WotL) come on top."""
    return [j["id"] for j in jobs_doc["jobs"] if j.get("implemented") and not j.get("group")]


def party_all_open(party, jobs_doc):
    """When the last TIC job became open to someone in the party (unlocks are per character; the party sees them)."""
    firsts = []
    for j in target_jobs(jobs_doc):
        times = [c.unlocked_at[j] for c in party if j in c.unlocked_at]
        if not times:
            return None
        firsts.append(min(times, key=fight_key))
    return max(firsts, key=fight_key)


def print_summary(rows, markdown):
    head = ["Preset", "Estimate", "JP per fighter", "Jobs mastered per fighter, end of Act 1 / 2 / 3",
            "Jobs unlocked per fighter, end of Act 1 / 2 / 3", "Every TIC job open in the party", "Camp members' jobs mastered",
            "First mastery"]
    if markdown:
        print("| " + " | ".join(head) + " |")
        print("|" + "---|" * len(head))
    for r in rows:
        cells = [r["preset"], r["estimate"], f"{r['jp']:,.0f}", " / ".join(r["mastered"]), " / ".join(r["unlocked"]),
                 r["all_open"], r["camp"], r["first"]]
        if markdown:
            print("| " + " | ".join(cells) + " |")
        else:
            print("  ".join(f"{c:<14}" for c in cells))


def print_detail(jobs_doc, cfg, estimate, jp_boost, markdown):
    party, total_fights = simulate(jobs_doc, cfg, estimate, jp_boost)
    impl = [j["id"] for j in jobs_doc["jobs"] if j.get("implemented")]
    names = {j["id"]: j["name"] for j in jobs_doc["jobs"]}
    # one row per job (20+ jobs don't fit as columns), one column per character
    head = ["Job"] + [c.name + ("" if c.active else " (camp)") for c in party]
    rows = []
    for j in impl:
        cells = [names[j]]
        for c in party:
            u = c.unlocked_at.get(j, "-")
            m = c.mastered_at.get(j)
            cells.append(f"{u} / **{m}**" if (m and markdown) else f"{u} / {m or '-'}")
        rows.append(cells)
    rows.append(["Jobs mastered"] + [str(len(c.mastered_at)) for c in party])
    rows.append(["JP total"] + [f"{c.total:,.0f}" for c in party])
    if markdown:
        print("| " + " | ".join(head) + " |")
        print("|" + "---|" * len(head))
    for cells in [head] * (not markdown) + rows:
        if markdown:
            print("| " + " | ".join(cells) + " |")
        else:
            print("  ".join(f"{x:<16}" for x in cells))


def print_sources(jobs_doc, cfg_doc, presets, sets, jp_boost, markdown):
    order = ["Action", "Spill", "Victory", "XP", "Camp", "Rest", "Shared"]
    head = ["Preset", "Estimate", "Who"] + order + ["Total"]
    if markdown:
        print("| " + " | ".join(head) + " |")
        print("|" + "---|" * len(head))
    for p in presets:
        cfg = effective_config(cfg_doc, p, sets)
        for est in ESTIMATES:
            party, _ = simulate(jobs_doc, cfg, est, jp_boost)
            for who, group in (("fighter", [c for c in party if c.active]), ("camp", [c for c in party if not c.active])):
                avg = {k: sum(c.sources.get(k, 0) for c in group) / len(group) for k in order}
                tot = sum(avg.values())
                cells = [p, est, who] + [f"{avg[k]:,.0f} ({avg[k] / tot:.0%})" if tot else "0" for k in order] + [f"{tot:,.0f}"]
                if markdown:
                    print("| " + " | ".join(cells) + " |")
                else:
                    print("  ".join(f"{x:<14}" for x in cells))


def selftest(jobs_doc, cfg_doc):
    jp = merge(cfg_doc["defaults"], {"JP": {"GlobalMultiplier": 1.0, "Action": {"Base": 8, "PerJobLevel": 2,
               "CharLevelDivisor": 4, "EnhancedBonus": 0.3, "Multiplier": 1.0}, "Spillover": {"Share": 0.25},
               "Victory": {"Base": 20, "PerCharLevel": 2}, "XPShare": 0.1, "LongRest": 25,
               "Boost": {"Multiplier": 1.5, "Action": True, "Victory": True, "XP": True, "LongRest": True}}})["JP"]
    checks = [
        (action_jp(jp, 1, 3, 1, False), (13.0, 2.5)),          # same numbers as tests/test_rules.lua
        (action_jp(jp, 1, 3, 1, True)[0], 19.5),
        (round(action_jp(jp, 3, 8, 1, False)[0], 6), round(16 * 1.3, 6)),
        (victory_jp(jp, 3, False), 26.0),
        (xp_jp(jp, 300, True), 45.0),
        (rest_jp(jp, False), 25.0),
        (job_level(199, [200, 400, 700, 1100, 1600, 2200, 3000]), 1),
        (job_level(3000, [200, 400, 700, 1100, 1600, 2200, 3000]), 8),
        (char_level(6500), 5),
        (char_level(100000), 12),
    ]
    sh = merge(cfg_doc["defaults"], {"JP": {"Shared": {"Share": 0.15, "Scope": "AllJobs", "RequireUnlocked": False}}})["JP"]
    impl = [j["id"] for j in jobs_doc["jobs"] if j.get("implemented")]
    fight_scope = merge(sh, {"Shared": {"Scope": "FightJobs"}})
    unlocked_only = merge(sh, {"Shared": {"RequireUnlocked": True}})
    checks += [                                                # same cases as tests/test_rules.lua
        (shared_jp(sh, 100, "Action"), 15.0),
        (shared_jp(sh, 100, "Rest"), 15.0),
        (shared_jp(sh, 100, "Spill"), 0.0),
        (shared_jp(sh, 100, "Shared"), 0.0),
        (",".join(shared_targets(sh, impl, "Squire", {"Squire", "Chemist"}, set())), ",".join(j for j in impl if j != "Squire")),
        (",".join(shared_targets(fight_scope, impl, "Squire", {"Squire", "Chemist"}, {"Squire", "Knight"})), "Knight"),
        (",".join(shared_targets(fight_scope, impl, "Squire", {"Squire", "Chemist"}, set())), ""),
        (",".join(shared_targets(unlocked_only, impl, "Squire", {"Squire", "Chemist"}, set())), "Chemist"),
    ]
    ok = True
    for got, want in checks:
        if got != want:
            print(f"selftest: expected {want}, got {got}")
            ok = False
    # The pacing target (user, 2026-10-12): a TYPICAL playthrough opens every job in the party by Act 3 and each
    # fighter masters about half of the 20 jobs; even a LOW (story-focused) one masters 5.
    preset = cfg_doc["defaultPreset"]
    cfg = effective_config(cfg_doc, preset, [])
    party, _ = simulate(jobs_doc, cfg, "LOW")
    worst = min(len(c.mastered_at) for c in party if c.active)
    if worst < 5:
        print(f"selftest: pacing target missed: in the LOW estimate a fighter masters only {worst} jobs with {preset}")
        ok = False
    party, _ = simulate(jobs_doc, cfg, "TYPICAL")
    typical = min(sum(1 for j in c.mastered_at if j in target_jobs(jobs_doc)) for c in party if c.active)
    n_jobs = len(target_jobs(jobs_doc))
    if typical < int(n_jobs * 0.4):
        print(f"selftest: pacing target missed: in the TYPICAL estimate a fighter masters only {typical} of the {n_jobs} TIC jobs with {preset}")
        ok = False
    opened = party_all_open(party, jobs_doc)
    if opened is None or act_of(opened) > 3:
        print(f"selftest: pacing target missed: in the TYPICAL estimate some TIC job never opens in the party with {preset}")
        ok = False
    totals = {}
    for p in ("Grindy", preset, "Fast"):
        party, _ = simulate(jobs_doc, effective_config(cfg_doc, p, []), "TYPICAL")
        totals[p] = sum(c.total for c in party if c.active)
    if not (totals["Grindy"] < totals[preset] < totals["Fast"]):
        print(f"selftest: presets out of order: {totals}")
        ok = False
    print("pacing simulator self-test " + ("OK" if ok else "FAILED")
          + f" ({preset}: every fighter masters {worst}+ jobs in LOW, {typical}+ of the {n_jobs} TIC jobs in TYPICAL;"
          + f" every TIC job open in the party at {opened})")
    return 0 if ok else 1


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preset", action="append", help="preset(s) to report (default: all)")
    ap.add_argument("--set", action="append", default=[], help="override a config value, e.g. JP.XPShare=0.2")
    ap.add_argument("--detail", choices=list(ESTIMATES), help="per-character unlock/mastery table for one estimate")
    ap.add_argument("--jp-boost", action="store_true", help="characters equip JP Boost once learned")
    ap.add_argument("--markdown", action="store_true")
    ap.add_argument("--sources", action="store_true", help="where the JP comes from, per source")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args(argv)
    jobs_doc, cfg_doc = load()
    if args.selftest:
        return selftest(jobs_doc, cfg_doc)
    presets = args.preset or list(cfg_doc["presets"].keys())
    if args.sources:
        print_sources(jobs_doc, cfg_doc, presets, args.set, args.jp_boost, args.markdown)
        return 0
    if args.detail:
        for p in presets:
            print(f"\n{p}, {args.detail}: unlocked / mastered (A2.14 = Act 2, 14th fight of the act)")
            print_detail(jobs_doc, effective_config(cfg_doc, p, args.set), args.detail, args.jp_boost, args.markdown)
        return 0
    print_summary(summary_rows(jobs_doc, cfg_doc, presets, args.set, args.jp_boost), args.markdown)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
