# Moved from a session scratchpad (2026-10-12). Usage: python tools/vq.py --find kw [kw...] / --show Name [Name...] [--fields a,b]
"""Query vanilla BG3 stats (all types): vq.py --find kw [kw...] | --show Name [Name...] [--fields a,b] [--grep regex]"""
import re
import sys
from pathlib import Path

ROOT = Path(r"C:\Users\berus\GameModding\decomp\bg3")
ENTRY = re.compile(r'^new entry "([^"]+)"')
USING = re.compile(r'^using "([^"]+)"')
DATA = re.compile(r'^data "([^"]+)" "(.*)"$')
TYPE = re.compile(r'^type "([^"]+)"')


def load():
    entries = {}
    files = sorted(ROOT.rglob("*.txt"))
    files = [f for f in files if "Stats" in f.parts and "Generated" in f.parts]
    for f in files:
        cur = None
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            m = ENTRY.match(line)
            if m:
                cur = {"name": m.group(1), "type": None, "using": None, "data": {}, "file": f.name}
                entries[cur["name"]] = cur
                continue
            if cur is None:
                continue
            m = TYPE.match(line)
            if m:
                cur["type"] = m.group(1)
                continue
            m = USING.match(line)
            if m:
                cur["using"] = m.group(1)
                continue
            m = DATA.match(line)
            if m:
                cur["data"][m.group(1)] = m.group(2)
    return entries


def resolved(entries, name):
    chain = []
    e = entries.get(name)
    while e and len(chain) < 20:
        chain.append(e)
        e = entries.get(e["using"]) if e["using"] else None
    data = {}
    for e in reversed(chain):
        data.update(e["data"])
    return chain, data


def main(argv):
    entries = load()
    fields = None
    if "--fields" in argv:
        i = argv.index("--fields")
        fields = argv[i + 1].split(",")
        argv = argv[:i] + argv[i + 2:]
    if argv and argv[0] == "--find":
        for kw in argv[1:]:
            hits = [n for n in entries if kw.lower() in n.lower()]
            print(f"[{kw}] {len(hits)}: " + ", ".join(f"{n}({entries[n]['type'][:6] if entries[n]['type'] else '?'})" for n in sorted(hits)[:40]))
    elif argv and argv[0] == "--grep":
        rx = re.compile(argv[1])
        n = 0
        for name, e in entries.items():
            for k, v in e["data"].items():
                if rx.search(v):
                    print(f"{name} [{e['type']}] {k}: {v[:220]}")
                    n += 1
                    break
            if n >= int(argv[2]) if len(argv) > 2 else n >= 25:
                break
    elif argv and argv[0] == "--show":
        for name in argv[1:]:
            if name not in entries:
                print(f"== {name}: NOT FOUND")
                continue
            chain, data = resolved(entries, name)
            print(f"== {name} [{chain[0]['type']}] using {' > '.join(c['name'] for c in chain[1:]) or '-'}")
            for k, v in data.items():
                if fields is None or k in fields:
                    print(f"   {k}: {v[:300]}")


if __name__ == "__main__":
    main(sys.argv[1:])
