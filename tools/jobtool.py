#!/usr/bin/env python3
"""Adds or replaces jobs, badges, abilities and strings in data/fft_jobs.json and data/strings.json.

Usage: python tools/jobtool.py <spec.json> [--dry-run]

spec.json may hold any of:
  {"jobs": [...], "badges": [...], "abilities": [...], "strings": {"Key.Name": "...", ...}}
Entries are matched by "id": an existing entry is replaced in place, a new one is inserted after the last entry of
the same job (abilities), of the same group (jobs) or at the end (badges; abilities of a new job after a blank line).
A partial update merges fields into an existing entry: {"id": "X", "_merge": true, "implemented": true}.

The data file keeps one entry per line inside its arrays (blank lines between the jobs' abilities); this tool edits
those lines only, so everything else (meta, levelActs, leftOut) stays exactly as it is. Writes LF line ends.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOBS = ROOT / "data" / "fft_jobs.json"
STRINGS = ROOT / "data" / "strings.json"
LABEL = {"jobs": "job", "badges": "badge", "abilities": "ability"}


def dump(entry):
    return json.dumps(entry, ensure_ascii=False)


def array_span(lines, key):
    """(first line after the header, closing line) of a one-entry-per-line array '  "key": ['."""
    head = f'  "{key}": ['
    start = next(i for i, ln in enumerate(lines) if ln == head)
    end = next(i for i in range(start + 1, len(lines)) if lines[i].startswith("  ]"))
    return start + 1, end


def upsert_lines(lines, key, new, after_key=None):
    """Replace the entry with new's id in place, else insert it after the last entry with the same after_key value
    (else at the end of the array). Returns "added" or "replaced"."""
    a, b = array_span(lines, key)
    parsed = {i: json.loads(lines[i].strip().rstrip(",")) for i in range(a, b) if lines[i].strip()}
    status = "added"
    for i, e in parsed.items():
        if e.get("id") == new["id"]:
            if new.get("_merge"):
                merged = dict(e)
                merged.update({k: v for k, v in new.items() if k != "_merge"})
                new = merged
            lines[i] = f"    {dump(new)}"
            status = "replaced"
            break
    else:
        if new.get("_merge"):
            raise SystemExit(f"cannot merge into missing entry {new['id']}")
        same = [i for i, e in parsed.items() if after_key and e.get(after_key) == new.get(after_key)]
        if same:
            lines.insert(same[-1] + 1, f"    {dump(new)}")
        else:
            extra = [""] if key == "abilities" and parsed else []
            lines[b:b] = extra + [f"    {dump(new)}"]
    # commas: after every entry but the last one of the array
    a, b = array_span(lines, key)
    rows = [i for i in range(a, b) if lines[i].strip()]
    for i in rows:
        lines[i] = lines[i].rstrip().rstrip(",") + ("," if i != rows[-1] else "")
    return status


def set_string(lines, key, value):
    """strings.json, one '    "key": "value"' per line (blank lines kept): replace the line or add it at the end."""
    row = f"    {dump(key)}: {dump(value)}"
    start = next(i for i, ln in enumerate(lines) if ln.startswith('  "strings": {'))
    end = next(i for i in range(start + 1, len(lines)) if lines[i].startswith("  }"))
    for i in range(start + 1, end):
        if lines[i].startswith(f"    {dump(key)}:"):
            lines[i] = row + ("," if lines[i].rstrip().endswith(",") else "")
            return "replaced"
    last = max(i for i in range(start + 1, end) if lines[i].strip())
    lines[last] = lines[last].rstrip().rstrip(",") + ","
    lines.insert(last + 1, row)
    return "added"


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    spec = json.loads(Path(argv[0]).read_text(encoding="utf-8"))
    dry = "--dry-run" in argv
    lines = JOBS.read_text(encoding="utf-8").split("\n")
    report = []
    for key, after in (("jobs", "group"), ("badges", None), ("abilities", "job")):
        for new in spec.get(key, []):
            report.append(f"{LABEL[key]} {new['id']}: {upsert_lines(lines, key, new, after)}")
    text = "\n".join(lines)
    json.loads(text)  # still valid JSON
    slines = None
    if spec.get("strings"):
        slines = STRINGS.read_text(encoding="utf-8").split("\n")
        for k, v in spec["strings"].items():
            report.append(f"string {k}: {set_string(slines, k, v)}")
        json.loads("\n".join(slines))
    print("\n".join(report) or "nothing to do")
    if dry:
        return 0
    JOBS.write_text(text, encoding="utf-8", newline="\n")
    if slines is not None:
        STRINGS.write_text("\n".join(slines), encoding="utf-8", newline="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
