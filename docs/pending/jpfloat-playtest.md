## New in VERSION: JP gains float above the head (NWP 10)

- When JP goes into the job a character is playing (abilities in a fight, kills, wins, rests), a gold **"+N JP"**
  floats above their head, like the +HP numbers. Shared and spillover JP into other jobs stays quiet.
- Exact numbers up to 200, then rounded to 10 (e.g. +240 JP); 1000 or more shows "+1000+ JP".
- Config: `Notifications.JPOverhead` (on/off), `Notifications.JPOverheadSeconds` (6 = one turn).

Please check:
- Use a job ability in a fight: "+N JP" above the caster, in gold. Quick test outside a fight: `!fft_addjp 25` in the
  SE console -> "+25 JP" above the host.
- The text does not show in the combat log or as an icon on the portrait.
- Two gains of the same size in one turn show twice.
- If nothing shows: try `Notifications.JPOverheadSeconds` 0, and tell me.
