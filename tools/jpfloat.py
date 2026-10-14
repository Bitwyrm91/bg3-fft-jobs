"""JP gains float above the head like BG3's "+HP" numbers (NWP 10; user, 2026-10-14: only JP that goes into the job
the character is playing, yellow/gold text).

BG3 floats a status's DisplayName above a character when the status is applied (vanilla TWN_DISTILLERY_UNLOCK_* and
MAG_JHANNYL_GLOVES_LESSER_RESTORATION: BOOST statuses with ForceOverhead). A status name can't change per use, so
there is one hidden status per amount: FFTJ_JPGAIN_<N>, named "+N JP". Amounts up to EXACT are exact, larger ones
round to the nearest STEP, and MAX or more shows "+MAX+ JP". Service:FloatJP picks the status with the same rule
(Rules.JPFloatAmount, Data.JPFloat).
"""

FILE = "Status_FFTJ_JPGain.txt"
PREFIX = "FFTJ_JPGAIN_"
EXACT = 200
STEP = 10
MAX = 1000
COLOR = "Yellow"
FLAGS = "ForceOverhead;DisableCombatlog;DisablePortraitIndicator"


def amounts():
    return list(range(1, EXACT + 1)) + list(range(EXACT + STEP, MAX + 1, STEP))


def label(n):
    return f"+{n}+ JP" if n >= MAX else f"+{n} JP"


def strings():
    table = {f"jpgain.{n}.name": label(n) for n in amounts()}
    table["jpgain.desc"] = "Job Points gained."
    return table


def stats(H):
    out = []
    for n in amounts():
        out.append("\n".join([
            f'new entry "{PREFIX}{n}"',
            'type "StatusData"',
            'data "StatusType" "BOOST"',
            f'data "DisplayName" "{H(f"jpgain.{n}.name")}"',
            f'data "Description" "{H("jpgain.desc")}"',
            f'data "FormatColor" "{COLOR}"',
            f'data "StackId" "{PREFIX}{n}"',
            f'data "StatusPropertyFlags" "{FLAGS}"',
        ]))
    return "\n\n".join(out) + "\n"


def lua_data():
    return {"Prefix": PREFIX, "Exact": EXACT, "Step": STEP, "Max": MAX}
