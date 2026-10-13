#!/usr/bin/env python3
"""Schreibt RELEASE_NOTES.md: nur der oberste Block aus CHANGELOG.md, im
Aufbau, den der Packager fuer seinen eigenen Changelog nutzt (Titel,
Versionslink mit Datum, Full Changelog / Previous Releases, Punkte).

CurseForge, Wago und das GitHub-Release zeigen diese Datei. CHANGELOG.md
bleibt die volle Historie und wird von Hand gepflegt.

Laeuft im Workflow vor dem Packager. Auf einem Tag muss der oberste Block
zur Tag-Version passen, sonst bricht der Lauf ab.
"""
import os
import re
import sys
from pathlib import Path

ADDON = Path(__file__).resolve().parent.parent
CHANGELOG = ADDON / "CHANGELOG.md"
OUT = ADDON / "RELEASE_NOTES.md"
PROJECT = "VuloGearSets"
REPO = "https://github.com/mrvulo/VuloGearSets"

HEAD = re.compile(r'^##\s+(\S+)(?:\s+[—-]\s+(\d{4}-\d{2}-\d{2}))?\s*$')


def blocks():
    """[(version, datum, zeilen)] in Dateireihenfolge."""
    out = []
    for line in CHANGELOG.read_text(encoding="utf-8").splitlines():
        m = HEAD.match(line)
        if m:
            out.append((m.group(1), m.group(2), []))
        elif out:
            out[-1][2].append(line)
    return out


def render():
    """(version, datum, text) der Release-Notiz fuer den obersten Block."""
    found = blocks()
    if not found:
        sys.exit("CHANGELOG.md hat keinen '## <version>'-Block")
    version, date, body = found[0]

    tag = f"v{version}"
    if len(found) > 1:
        full = f"[Full Changelog]({REPO}/compare/v{found[1][0]}...{tag})"
    else:
        full = f"[Full Changelog]({REPO}/commits/{tag})"
    previous = f"[Previous Releases]({REPO}/releases)"

    title = f"## [{tag}]({REPO}/tree/{tag})"
    if date:
        title += f" ({date})"

    text = "\n".join(body).strip()
    return version, date, f"# {PROJECT}\n\n{title}\n{full} {previous}\n\n{text}\n"


def main():
    version, _date, text = render()
    ref = os.environ.get("GITHUB_REF_NAME", "")
    if os.environ.get("GITHUB_REF_TYPE") == "tag" and ref != f"v{version}":
        sys.exit(f"Tag {ref} passt nicht zum obersten Block '## {version}'")
    OUT.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
