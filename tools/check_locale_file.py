"""Prueft eine Uebersetzungsdatei gegen Locales/deDE.lua.

    python tools/check_locale_file.py Locales/frFR.lua

Gleiche Keys wie deDE, und in jedem Wert dieselben Platzhalter (%s, %d,
%.1f ...) in derselben Reihenfolge, dieselben Farbcodes |c...|r, |n und
Zeilenumbrueche. Ein vertauschter Platzhalter laesst string.format im
Spiel abstuerzen, ein fehlendes |r faerbt den Rest der Zeile.
"""
import re
import sys
from pathlib import Path

ADDON = Path(__file__).resolve().parent.parent
ENTRY = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)",?\s*$', re.M)
FMT = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?[sdifgxXcq%]')
CODES = re.compile(r'\|c[0-9a-fA-F]{8}|\|r|\|n|\\n')


def entries(path):
    return dict(ENTRY.findall(path.read_text(encoding="utf-8")))


def problems(target):
    """Befunde einer Uebersetzungsdatei gegen deDE.lua, leer = in Ordnung."""
    ref = entries(ADDON / "Locales" / "deDE.lua")
    tr = entries(target)
    errors = []
    for k in sorted(set(ref) - set(tr)):
        errors.append(f"fehlt: {k!r}")
    for k in sorted(set(tr) - set(ref)):
        errors.append(f"unbekannter Key: {k!r}")
    for k, v in tr.items():
        if k not in ref:
            continue
        if FMT.findall(k) != FMT.findall(v):
            errors.append(f"Platzhalter {FMT.findall(v)} statt {FMT.findall(k)}: {k!r}")
        if sorted(CODES.findall(k)) != sorted(CODES.findall(v)):
            errors.append(f"Farb-/Zeilencodes weichen ab: {k!r}")
        if not v.strip():
            errors.append(f"leer: {k!r}")
    return errors, len(tr), len(ref)


def main():
    target = Path(sys.argv[1])
    if not target.is_absolute():
        target = ADDON / target
    errors, n, total = problems(target)
    for e in errors:
        print(e)
    print(f"{'FEHLER' if errors else 'OK'} - {target.name}: {n}/{total} Keys, {len(errors)} Befunde")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
