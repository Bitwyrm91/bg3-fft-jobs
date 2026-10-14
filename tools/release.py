#!/usr/bin/env python3
"""Version bump + handoff notes for one release, then a full build.

Usage: python tools/release.py <version> [--playtest <file.md>] [--status <file.md>] [--built "<Job name>"]

  <version>     e.g. 1.0.0.41: MOD_VERSION in tools/build.py and Version64 in Mod/Mods/FFTJobs/meta.lsx
  --playtest    a "## New in <version>: ..." section; inserted above the newest one in PLAYTEST.md, and the
                "**version X**" in its first paragraph is updated
  --status      a paragraph; inserted in STATUS.md after the newest "**1.0.0.N" entry
  --built       appends "<Job name> (<version>)" to the "Built so far:" line of docs/SPECIAL_JOBS.md
Then runs tools/build.py. Every file is written with LF line ends.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def read(p):
    return (ROOT / p).read_text(encoding="utf-8")


def write(p, text):
    (ROOT / p).write_text(text, encoding="utf-8", newline="\n")


def arg(argv, name):
    if name in argv:
        i = argv.index(name)
        return argv[i + 1]
    return None


def main(argv):
    if not argv or not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", argv[0]):
        print(__doc__)
        return 2
    version = argv[0]

    build = read("tools/build.py")
    build, n = re.subn(r'^MOD_VERSION = "[\d.]+"$', f'MOD_VERSION = "{version}"', build, flags=re.M)
    assert n == 1, "MOD_VERSION not found in tools/build.py"
    write("tools/build.py", build)

    # BG3 Version64 = major << 55 | minor << 47 | revision << 31 | build (1.0.0.39 = 36028797018964007)
    major, minor, rev, bld = (int(x) for x in version.split("."))
    v64 = (major << 55) | (minor << 47) | (rev << 31) | bld
    meta = read("Mod/Mods/FFTJobs/meta.lsx")
    meta, n = re.subn(r'(id="Version64" type="int64" value=")\d+(")', rf"\g<1>{v64}\g<2>", meta)
    assert n == 2, "expected two Version64 attributes in meta.lsx"
    write("Mod/Mods/FFTJobs/meta.lsx", meta)

    playtest = arg(argv, "--playtest")
    if playtest:
        section = Path(playtest).read_text(encoding="utf-8").strip() + "\n\n"
        text = read("PLAYTEST.md")
        text, n = re.subn(r"\*\*version [\d.]+\*\*", f"**version {version}**", text, count=1)
        assert n == 1, "no **version X** in PLAYTEST.md"
        i = text.index("\n## New in ") + 1
        write("PLAYTEST.md", text[:i] + section + text[i:])

    status = arg(argv, "--status")
    if status:
        para = Path(status).read_text(encoding="utf-8").strip()
        lines = read("STATUS.md").split("\n")
        last = max(i for i, ln in enumerate(lines) if re.match(r"\*\*1\.0\.0\.\d+", ln))
        # after the whole newest entry, not its first line (that split multi-line entries before)
        while last + 1 < len(lines) and lines[last + 1].strip():
            last += 1
        lines[last + 1:last + 1] = ["", para]
        write("STATUS.md", "\n".join(lines))

    built = arg(argv, "--built")
    if built:
        text = read("docs/SPECIAL_JOBS.md")
        m = re.search(r"^(Built so far: .*)\.$", text, flags=re.M)
        assert m, "no 'Built so far:' line in docs/SPECIAL_JOBS.md"
        text = text[:m.start()] + f"{m.group(1)}, {built} ({version})." + text[m.end():]
        write("docs/SPECIAL_JOBS.md", text)

    return subprocess.call([sys.executable, str(ROOT / "tools" / "build.py")], cwd=ROOT)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
