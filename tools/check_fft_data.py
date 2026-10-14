"""Check data/fft_jobs.json against the vanilla FFT: The Ivalice Chronicles game data.

The game data never goes into this repo. Extract it on your own PC first
(vanilla packs only, never modded*.pac or anything from Reloaded\\Mods):

  FF16Tools.CLI unpack-all -g fft -i "<TIC>\\data\\enhanced\\0004.pac"    -o <out>\\0004    --filter nxd/
  FF16Tools.CLI unpack-all -g fft -i "<TIC>\\data\\enhanced\\0004.en.pac" -o <out>\\0004.en --filter nxd/
  (copy both nxd folders into one folder)
  FF16Tools.CLI nxd-to-sqlite -g fft -i <nxd folder> -o <out>\\fft_enhanced.sqlite

Then:  python tools/check_fft_data.py <out>\\fft_enhanced.sqlite [--apply]

What it reads:
- 'Ability-en': JP cost = JpCost1 + 256 * JpCost2 (two bytes of one 16-bit value;
  e.g. Reraise 232 + 3*256 = 1000).
- 'GeneralJob': per job, RequiredJobExp (JP thresholds for job levels 0..8) and the
  unlock rule (RequiredJobIds / RequiredJobLevels). Keys 0..19 are the generic jobs
  in the classic order below; the order is confirmed by every unlock rule matching.
--apply writes the game's costs and unlock rules into data/fft_jobs.json and
marks the source "tic_game_data". Run tools/build.py afterwards.
"""
import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "fft_jobs.json"
CONFIG = ROOT / "data" / "config_defaults.json"

GENERAL_JOB_ORDER = [
    "Squire", "Chemist", "Knight", "Archer", "Monk", "WhiteMage", "BlackMage",
    "TimeMage", "Summoner", "Thief", "Orator", "Mystic", "Geomancer", "Dragoon",
    "Samurai", "Ninja", "Arithmetician", "Bard", "Dancer", "Mime",
]

# Our name -> TIC table name, where they differ.
ALIASES = {"Hi-Potion": "High Potion", "Hi-Ether": "High Ether"}

SOURCE_ID = "tic_game_data"
SOURCE_TEXT = ("FFT: The Ivalice Chronicles game data (vanilla Enhanced nex tables "
               "'Ability' and 'GeneralJob', read with FF16Tools 1.13.3 on the user's PC, 2026-10-12)")


def load_game(db_path):
    c = sqlite3.connect(db_path)
    costs = {}
    for name, cost in c.execute(
            "select Name, JpCost1 + 256 * JpCost2 from 'Ability-en' where Name is not null"):
        costs.setdefault(name, cost)  # first (lowest key) wins: some names repeat
    jobs = {}
    for key, exp, ids, lvls in c.execute(
            "select Key, RequiredJobExp, RequiredJobIds, RequiredJobLevels from GeneralJob"):
        if key < len(GENERAL_JOB_ORDER):
            ids, lvls = json.loads(ids), json.loads(lvls)
            jobs[GENERAL_JOB_ORDER[key]] = {
                "thresholds": json.loads(exp),
                "unlock": [{"job": GENERAL_JOB_ORDER[i], "level": l} for i, l in zip(ids, lvls)],
            }
    return costs, jobs


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    apply = "--apply" in sys.argv
    if not args:
        print(__doc__)
        return 2
    costs, gjobs = load_game(args[0])
    problems = 0

    def check_ability(entry, where):
        nonlocal problems
        tic = costs.get(ALIASES.get(entry["name"], entry["name"]))
        if tic is None:
            print(f"  NOT FOUND in game data: {where} {entry['name']}")
            problems += 1
            return False
        if tic != entry["cost"]:
            print(f"  cost {where} {entry['job']}/{entry['name']}: {entry['cost']} -> {tic}")
            problems += 1
            entry["note"] = (entry.get("note", "") + f" Guides said {entry['cost']}.").strip()
            entry["cost"] = tic
        return True

    def check_job(entry):
        nonlocal problems
        g = gjobs.get(entry["id"])
        if g is None:
            print(f"  job not in GeneralJob: {entry['id']}")
            problems += 1
            return False
        if g["unlock"] != entry["unlock"]:
            print(f"  unlock {entry['id']}: {entry['unlock']} -> {g['unlock']}")
            problems += 1
            entry["unlock"] = g["unlock"]
        return True

    # The file is laid out by hand (one line per job/ability), so edit it line by line.
    out, section = [], None
    other = set()  # jobs from other FFT versions (a "group", e.g. War of the Lions): not in TIC's tables, skipped
    for line in DATA.read_text(encoding="utf-8").split("\n"):
        m = re.match(r'^  "(\w+)": ', line)
        if m:
            section = m.group(1)
        if line.startswith("    {") and section in ("jobs", "abilities", "leftOut"):
            comma = line.endswith(",")
            entry = json.loads(line.strip().rstrip(","))
            if section == "jobs" and entry.get("group"):
                other.add(entry["id"])
            # abilities of our own or from Fell Seal (source "custom": Chemist flasks, the Ranger) are not in TIC
            if "custom" in entry.get("source", []):
                pass
            elif (entry["id"] if section == "jobs" else entry.get("job")) not in other:
                ok = check_job(entry) if section == "jobs" else check_ability(entry, section)
                if ok and SOURCE_ID not in entry.setdefault("source", []):
                    entry["source"].insert(0, SOURCE_ID)
                line = "    " + json.dumps(entry, ensure_ascii=False) + ("," if comma else "")
        out.append(line)
        if line == '    "sources": {' and section == "meta" and SOURCE_ID not in "\n".join(out[:-1]):
            out.append(f'      "{SOURCE_ID}": {json.dumps(SOURCE_TEXT, ensure_ascii=False)},')

    print("Job level thresholds:")
    cfg = json.loads(CONFIG.read_text(encoding="utf-8"))
    ours = cfg["defaults"]["JobLevels"]["Thresholds"]
    for t in {tuple(g["thresholds"]) for g in gjobs.values()}:
        # index = job level; levels 2..8 are what the mod configures
        if list(t[2:]) != ours:
            print(f"  thresholds differ: ours {ours}, game levels 2..8 {list(t[2:])} (full {list(t)})")
            problems += 1
        else:
            print(f"  OK: levels 2..8 = {list(t[2:])} (the game table also has Lv1 = {t[1]})")

    if apply:
        text = "\n".join(out)
        json.loads(text)  # still valid JSON
        with open(DATA, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print(f"applied to {DATA.relative_to(ROOT)} (thresholds are not changed automatically)")
    print(f"{problems} difference(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
