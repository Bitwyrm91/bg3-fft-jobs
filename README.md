# BG3 x Final Fantasy Tactics: job system

A Baldur's Gate 3 mod (Script Extender) that adds FFT-style jobs on top of your BG3 class: Job Points, job levels,
FFT's unlock tree, a Job Board, a secondary skill set, one reaction slot and two passive slots (Fell Seal style),
mastery perks. FFT data from The Ivalice Chronicles (+ War of the Lions jobs).

**State (1.0.0.47):** all 20 TIC jobs, Dark Knight and Onion Knight, the 17 special jobs (badges from bosses), and the
**Soul Collector** monster job (Soul Brand a foe, devour its soul when it dies, take Wild Shape-style forms: 45 Act 1
soul types, two forms each). The core job system ran in game (versions up to 1.0.0.21); the special jobs and the Soul
Collector are built and checked against the game's data but **not yet tested in a game**: expect bugs.

## Testers: install

1. Download `FFTJobs-<version>-test.zip` from the [Releases](../../releases) page (it holds `FFTJobs.pak` and
   `HOW-TO-INSTALL.txt`).
2. Install the **BG3 Script Extender** (required): BG3 Mod Manager -> Tools -> "Download & Extract the Script Extender".
3. BG3 Mod Manager -> File -> Import Mod -> `FFTJobs.pak`; drag it into the active list; Export Order to Game.
4. Start a **new game, not Honour Mode**. A chest beside you on the nautiloid holds the **Soul Codex** (opens the Soul
   Collector). Cast the free **Job Board** spell to pick jobs; **JP Training (test)** gives JP for quick testing.
5. Bug reports: the newest file in `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender Logs` and what you did.

What to look at: [PLAYTEST.md](PLAYTEST.md) ("New in" sections, newest first).

## For development

- Plan and rules for the build: [BRIEF.md](BRIEF.md); phase 2 decisions: [docs/PHASE2.md](docs/PHASE2.md)
- Design, sources and pacing tables: [DESIGN.md](DESIGN.md)
- Progress and handoff: [STATUS.md](STATUS.md)
- Packaging: `tools\package.ps1` (needs LSLib's Divine), install on this PC: `tools\install.ps1`

## Layout

| Path | What |
|---|---|
| `data/` | jobs, abilities, unlock rules, JP config and presets, strings: edit these |
| `stats_src/` | BG3 stats templates for the abilities |
| `Mod/` | the mod as it goes into the .pak (Lua engine, generated data/stats/strings, meta.lsx) |
| `tools/build.py` | regenerates the files in `Mod/` from `data/` and `stats_src/` |
| `tools/pacing_sim.py` | JP pacing simulator |
| `tools/validate_vanilla.py` | checks the stats against the extracted game data |
| `tools/check_refs.py`, `tools/check_souls.py` | every name the stats use exists in the game; soul types vs the game's creatures |
| `data/souls.json`, `tools/souls_gen.py` | the Soul Collector's soul types, forms and skills |
| `tests/` | Lua 5.4 tests with a mock Script Extender |

Run all checks: `tools/run_tests.sh` or `tools\run_tests.ps1`.
