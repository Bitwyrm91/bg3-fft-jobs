# STATUS — BG3 × FFT job system

Handoff between sessions. Read this first, then `BRIEF.md` and `DESIGN.md`.

**Where the work is:** branch `claude/game-modding-research-setup-qgn88h` on GitHub (Bitwyrm91/bg3-fft-jobs). Not merged into `main` yet.

## Part A (cloud) progress

- [x] 1. Research + `DESIGN.md` (SE/Osiris APIs verified against Norbyte's docs and the generated story header, TIC data with sources, JP formulas, persistence, layout, mod UUID `3db7be3e-9387-4678-b172-044acc7ff0c2`)
- [x] 2. Data files: `data/fft_jobs.json` (all 20 TIC jobs with unlock rules, 6 implemented, 71 abilities with TIC JP costs and sources), `data/config_defaults.json` (JP config + presets), `data/strings.json`; `tools/build.py` generates `Shared/GeneratedData.lua`
- [ ] 3. Lua engine
- [ ] 4. Stats + localization drafts
- [ ] 5. Tests (Lua 5.4, mock Ext/Osi)
- [ ] 6. Pacing simulator + preset tables
- [ ] 7. `PLAYTEST.md` + final `STATUS.md` with the Part B checklist

## Unverified (could not be checked in the cloud)

- Every vanilla BG3 stats ID, `using` parent, status name and icon in the stats drafts.
- Everything that only shows in game: events firing as expected, grants, UI, notifications.
