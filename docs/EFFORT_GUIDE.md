# Effort levels for FFTJobs work

Which effort setting (Low, Medium, High, Extra high, Max) each kind of task here needs, so it is done right the first
time without spending Max on routine work. Written 2026-10-14 from the mod's history (1.0.0.1-75, 140 commits, the
playtest reports); everything up to then ran on Max.

**Sessions:** at the start of a task, find it in the table and say in the first reply if the effort should go up, or
could go down. One line is enough: "This is a Max task (new job); you're on Extra high, want to switch first?"

## The short rule

- **Max** when the task relies on BG3 behaviour we have not seen work yet, touches many files, or one mistake would
  repeat across hundreds of entries. New jobs, generators, bug hunts, multiplayer.
- **Extra high** when it copies a pattern that already works in the mod, or has to understand two sides at once
  (merges, log triage).
- **High** for one-area changes with tests: Job Board tweaks, wording sweeps, research write-ups.
- **Medium / Low** for scripted chores: config numbers, packaging, installing, pushing, STATUS notes.

## By task

| Task | Effort | Examples from this mod | Why |
|---|---|---|---|
| New job, or a job rework | **Max** | Wizard, Peddler, Ranger (from Archer), Monk martial arts, Soul Collector, the 17 special jobs | 10+ files (data, stats, Lua, generators, icons, tests), new BG3 behaviour, pacing, refunds for old saves |
| New separate mod / BG3 base class | **Max**, design first in its own session | WoW Warlock (NWP 6), skip-the-nautiloid (NWP 11) | no pattern in this repo to copy |
| Build tools that touch every spell | **Max** | statcast (3402 passives), scaling, smartcast, upcast, menu_gen, the `using` flatten fix | one mistake repeats hundreds of times and the tests can't see it |
| Bug from a playtest ("does nothing", "isn't working") | **Max** | Counter Tackle hurting its owner (SWAP), pushes, Potion slot "did nothing", hotbar menu casts (NWP 15) | the cause is engine behaviour; needs logs and careful reasoning |
| Multiplayer | **Max** | board per player, who may change whom (1.0.0.63) | client/server split, can't be tested alone |
| New skill with a new mechanic | **Max** | Mana Font, Blessed One, Strange Fluid, Quick Toss's flyout | new passive contexts, Lua hooks, containers |
| New skill on a known pattern | **Extra high** | another Chemist flask or Quick Toss vial; a skill that copies a vanilla spell with new numbers | copies something already proven in the mod |
| Job Board new page or feature | **Extra high** | Passives / Party pages (1.0.0.73) | client + server view + tests |
| Job Board layout or wording tweak | **High** (Extra high if it also renames things across the mod) | dropdown groups (1.0.0.61), tiles with JP + Set job (1.0.0.75) | one Lua file and its tests |
| Merging parallel sessions | **Extra high** | Ranger + Wizard + Peddler + Mender merges (menu counts 596/599/602) | both sides' intent, pinned counts, regenerate generated files |
| Tooltip rewrite that states numbers | **Extra high** | the "no FFT comparisons" tooltip pass | every text must match the real stats |
| Wording swap across the mod | **High** | "secondary" -> "subclass" (1.0.0.75) | mechanical, but spots hide in generators and messages |
| Reading a playtest log: what happened? | **Extra high** | the MP log that showed menu casts never arrived | many events, one cause |
| Research, design questions | **High**; **Max** if it decides an engine hack | Fell Seal data, boss badges; Jobs tab in BG3's own UI (NWP 23) | a wrong "it's possible" costs a whole build later |
| Config numbers, balance | **Medium** (**High** if JP pacing changes) | JP Boost +20%, Potion 1d4+2 | one value; the pacing self-test guards pacing |
| Package, install, push, tester zip, STATUS notes | **Low** to **Medium** | every release | scripted; Medium while other sessions run (versions, BG3 closed) |
| Icon painting | **Low** to **Medium** | tools/generate_icon_art.ps1 | scripted; you judge the look |

This session's task (1.0.0.75: tile layout, the "subclass" rename, release with another session running) was an
Extra high task run on Max.

## What effort can't fix

Most redo work in this mod did not come from too little thinking. It came from these, so they matter at every level:

1. **BG3 behaviour has to be seen in the game once.** The chemist-pass session found on 2026-10-14 (SE console,
   `Ext.Stats.Get`) that a generated spell whose parent is in our own Spell_FFTJ.txt loses everything it should
   inherit. That one fact broke the spell-slot levels, Echo/Arith twins, the hotbar Learn/Change Job entries, Patented
   Usage and the soul forms. All of it was built on Max and passed 200+ tests, because the tests run on mocks. Rule:
   the first time a build uses an engine behaviour we have not seen work, check ONE entry in game before building the
   rest (SE console `Ext.Stats.Get("<id>")`, `!fft_grants`, cast it once).
2. **Cloud sessions can't check vanilla names.** The Monk's guessed passive name (1.0.0.64, cloud) was wrong; the
   local check caught it in 1.0.0.65. Engine-heavy work belongs in a local session, or the local checks
   (`validate_vanilla.py`, `check_refs.py`) run right after.
3. **Ask, then build.** Design questions cost little at any effort; a wrong guess costs a rebuild.
4. **Parallel sessions:** own worktree each, versions taken only when landing, generated files regenerated (never
   hand-merged), a message to the others before landing, packaging or installing.
5. **Split big work.** A new job: design questions (Max, short), build (Max), then tooltips and tweaks (High or
   Extra high) in a fresh session. Shorter sessions also stay sharper than one long one.

## Usage

Max spends the most usage per task. Running chores, tweaks and sweeps one or two levels lower leaves more of the
weekly budget for the jobs, generators and bug hunts that need Max.
