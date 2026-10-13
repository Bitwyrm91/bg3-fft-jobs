# Moved from a session scratchpad (2026-10-12). Usage: python tools/check_tokens.py Mod/Public/FFTJobs/Stats/Generated/Data
# Known false positive: AdjustRoll(...) in Interrupt_FFTJ.txt Properties.
"""Every functor/boost/condition name we use must occur in vanilla stats; every value of an enum-like field too."""
import re
import sys
from pathlib import Path

VANILLA = Path(r"C:\Users\berus\GameModding\decomp\bg3")
OURS = Path(sys.argv[1])
DATA = re.compile(r'^\s*data "([^"]+)" "(.*)"$')
CALL = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\(")
ENUM_FIELDS = {"SpellFlags", "StatusPropertyFlags", "Properties", "Cooldown", "SpellType", "StatusType",
               "InterruptContext", "InterruptContextScope", "Container", "InterruptDefaultValue",
               "StatsFunctorContext", "RemoveEvents", "TickType", "StackType", "SpellStyleGroup", "Requirements"}


def fields(path):
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = DATA.match(line)
        if m:
            yield m.group(1), m.group(2)


vanilla_text_calls, vanilla_enum = set(), {}
for f in VANILLA.rglob("*.txt"):
    if "Stats" not in f.parts:
        continue
    for k, v in fields(f):
        vanilla_text_calls.update(CALL.findall(v))
        if k in ENUM_FIELDS:
            vanilla_enum.setdefault(k, set()).update(x.strip() for x in v.split(";") if x.strip())

problems = []
for f in sorted(OURS.glob("*.txt")):
    for k, v in fields(f):
        for name in CALL.findall(v):
            if name not in vanilla_text_calls:
                problems.append(f"{f.name}: {k}: function/boost {name}( not in vanilla")
        if k in ENUM_FIELDS:
            for x in (x.strip() for x in v.split(";")):
                if x and x not in vanilla_enum.get(k, set()):
                    problems.append(f"{f.name}: {k} value {x!r} not in vanilla")
for p in sorted(set(problems)):
    print(p)
print(f"{len(set(problems))} problem(s)")
