**VERSION (2026-10-14, local session "BG3 mod continued", branch claude/jp-overhead, NOT packaged or seen in game):
NWP 10, JP above the head.** User's picks: main job gains only (shared/spillover JP into other jobs stays quiet), gold
text. BG3 floats a status's DisplayName when it is applied (vanilla TWN_DISTILLERY_UNLOCK_* / MAG_JHANNYL_*: BOOST +
`ForceOverhead`), and a name can't change per use, so new `tools/jpfloat.py` (build.py) writes Status_FFTJ_JPGain.txt:
280 hidden statuses `FFTJ_JPGAIN_<N>` ("+N JP", FormatColor Yellow, ForceOverhead;DisableCombatlog;
DisablePortraitIndicator): exact 1-200, then steps of 10 to "+1000+ JP" (Data.JPFloat, `Rules.JPFloatAmount`).
`Service:FloatJP` (from Service:AddJP when `jobId == char.Primary`) removes an active one of the same amount first,
then applies it for `Notifications.JPOverheadSeconds` (6); switch `Notifications.JPOverhead` (true).
tests/test_jpfloat.lua (4), 216 tests; validate_vanilla and check_refs clean. Unverified in game: the overhead text
itself (ForceOverhead on a status with no icon), whether a 0-second status would also show it, remove+apply in one
frame showing twice.
