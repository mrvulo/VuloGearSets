"""Zieht die von den beiden Modulen benutzten Keys aus Vulos deDE.lua.

Erzeugt Locales/deDE.lua neu. Umbenannte Keys wandern dabei auf ihren
neuen Namen mit, entfallene werden ausgelassen.
"""
import re
from pathlib import Path

from rename_keys import DROP_KEYS, KEY_IN_CODE, RENAME_MAP, SOURCES, VULO

VULO_DE = VULO / "Locales" / "deDE.lua"
OUT = Path(__file__).resolve().parent.parent / "Locales" / "deDE.lua"

ENTRY_IN_LOCALE = re.compile(
    r'\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,'
)

HEADER = """-- =========================================================
-- VuloGearSets / Locales / deDE
-- Deutsche Uebersetzungen.
--
-- Format: <englischer Key> = <deutsche Uebersetzung>
-- Fehlende Keys fallen automatisch auf das englische Original zurueck.
-- Erzeugt von tools/extract_locales.py
-- =========================================================
local _, ns = ...

ns:RegisterLocale("deDE", {
"""

FOOTER = "})\n"

# Uebersetzungen, deren WERT angepasst werden muss. RENAME_MAP fasst nur die
# Keys an; in diesen drei deutschen Saetzen stecken die Slash-Befehle mit drin.
# Als Tabelle hier, damit ein erneuter Lauf die Korrektur nicht zurueckdreht.
VALUE_FIXES = {
    "Usage: /gearset delete <name>":
        "Benutzung: /gearset delete <Name>",
    "Usage: /gearset equip <name> | save <name> | delete <name> | list | config | unlock":
        "Benutzung: /gearset equip <Name> | save <Name> | delete <Name> | list | config | unlock",
    "|cffaaaaaaSlash commands: /gearset save <name>, /gearset equip <name>, "
    "/gearset delete <name>, /gearset list. Short alias: /vgs|r":
        "|cffaaaaaaSlash-Befehle: /gearset save <Name>, /gearset equip <Name>, "
        "/gearset delete <Name>, /gearset list. Kurzform: /vgs|r",
}

# Texte, die es in Vulos Loadouts-Modul nicht gab: Framework-Meldungen
# und alles, was erst im Standalone entsteht.
EXTRA = {
    "WARN: Module '%s' already registered.":
        "WARNUNG: Modul '%s' ist bereits registriert.",
    "|cffff5555Error enabling module '%s':|r %s":
        "|cffff5555Fehler beim Aktivieren von Modul '%s':|r %s",
    "|cffff5555Error disabling '%s':|r %s":
        "|cffff5555Fehler beim Deaktivieren von '%s':|r %s",
    "Module '%s' disabled. /reload recommended for full effect.":
        "Modul '%s' deaktiviert. /reload wird empfohlen.",
}


def main():
    used = set()
    for src in SOURCES:
        used.update(KEY_IN_CODE.findall(src.read_text(encoding="utf-8")))
    used -= set(DROP_KEYS)

    translations = dict(ENTRY_IN_LOCALE.findall(VULO_DE.read_text(encoding="utf-8")))

    entries, missing = {}, []
    for key in used:
        de = translations.get(key)
        if de is None:
            missing.append(key)
            continue
        entries[RENAME_MAP.get(key, key)] = de
    entries.update(EXTRA)

    applied = 0
    for key, fixed in VALUE_FIXES.items():
        if key in entries:
            entries[key] = fixed
            applied += 1
    if applied != len(VALUE_FIXES):
        print(f"WARNUNG: nur {applied} von {len(VALUE_FIXES)} Wertkorrekturen "
              f"griffen - Key geaendert?")

    lines = ['    ["%s"] = "%s",' % (k, entries[k]) for k in sorted(entries)]
    OUT.write_text(HEADER + "\n".join(lines) + "\n" + FOOTER, encoding="utf-8")

    print(f"{len(lines)} Uebersetzungen nach {OUT.name} geschrieben "
          f"({len(used)} aus der Quelle, {len(EXTRA)} eigene)")
    if missing:
        print(f"WARNUNG: {len(missing)} Keys ohne deutsche Uebersetzung:")
        for k in missing:
            print(f"  - {k!r}")


if __name__ == "__main__":
    main()
