"""Umbenennungstabelle Loadout -> Gear Set, plus Anwendung auf Lua-Dateien.

Die Keys sind gleichzeitig der sichtbare englische Text, deshalb aendert jede
Textaenderung auch den Key. Beide Seiten (Modulcode + deDE.lua) muessen
zusammen wandern.

Aufruf:
    python tools/rename_keys.py --verify          Map gegen die Quelle pruefen
    python tools/rename_keys.py <datei.lua> ...   Map anwenden
"""
import re
import sys
from pathlib import Path

VULO = Path(r"C:\Users\aobiw\Desktop\entpackte addons\VuloClassicUI")
SOURCES = [VULO / "Modules" / "Loadouts.lua", VULO / "Modules" / "SlotPicker.lua"]

# Bewusst explizit statt regelbasiert: ein blindes "loadout" -> "gear set"
# erzeugt Grammatikfehler wie "a gear sets".
RENAME_MAP = {
    "Loadouts":
        "Gear Sets",
    "Saved Loadouts":
        "Saved Gear Sets",
    "Saved loadouts:":
        "Saved gear sets:",
    "Confirm before deleting a loadout":
        "Confirm before deleting a gear set",
    "Delete loadout '%s'?":
        "Delete gear set '%s'?",
    "Loadout '%s' already equipped.":
        "Gear set '%s' already equipped.",
    "Loadout '%s' deleted.":
        "Gear set '%s' deleted.",
    "Loadout '%s' does not exist.":
        "Gear set '%s' does not exist.",
    "Loadout '%s' equipped (%d items swapped).":
        "Gear set '%s' equipped (%d items swapped).",
    "Loadout '%s' equipped (%d swapped, %d missing from bags).":
        "Gear set '%s' equipped (%d swapped, %d missing from bags).",
    "Loadout '%s' saved (%d items).":
        "Gear set '%s' saved (%d items).",
    "Loadout '%s' updated with current gear.":
        "Gear set '%s' updated with current gear.",
    "Loadout '%s': %d items missing from bags, nothing swapped.":
        "Gear set '%s': %d items missing from bags, nothing swapped.",
    "Loadout '%s': slot updated.":
        "Gear set '%s': slot updated.",
    "No loadouts saved yet.":
        "No gear sets saved yet.",
    "Please provide a name for the loadout.":
        "Please provide a name for the gear set.",
    "Save current equipment as a new loadout. Enter name:":
        "Save current equipment as a new gear set. Enter name:",
    "Equip this loadout automatically when the chosen stance/form is activated.":
        "Equip this gear set automatically when the chosen stance/form is activated.",
    "Equip this loadout automatically when you switch to this spec.":
        "Equip this gear set automatically when you switch to this spec.",
    "Automatically equips a loadout when you switch between Spec 1 and Spec 2 (dual spec). "
    "Bind each loadout to a spec below. Requires dual spec to be active.":
        "Automatically equips a gear set when you switch between Spec 1 and Spec 2 (dual spec). "
        "Bind each gear set to a spec below. Requires dual spec to be active.",
    "Automatically equips a loadout when your stance/form changes (warrior stances, druid forms). "
    "Out-of-combat only \u2014 if a stance change happens in combat, the swap is deferred until combat ends.":
        "Automatically equips a gear set when your stance/form changes (warrior stances, druid forms). "
        "Out-of-combat only \u2014 if a stance change happens in combat, the swap is deferred until combat ends.",
    "Usage: /loadout delete <name>":
        "Usage: /gearset delete <name>",
    "Usage: /loadout equip <name> | save <name> | delete <name> | list":
        "Usage: /gearset equip <name> | save <name> | delete <name> | list | config | unlock",
    "|cffaaaaaaNo loadouts saved yet. Use the button above to save your current gear.|r":
        "|cffaaaaaaNo gear sets saved yet. Use the button above to save your current gear.|r",
    "|cffaaaaaaSlash commands: /loadout save <name>, /loadout equip <name>, "
    "/loadout delete <name>, /loadout list. Short alias: /lo|r":
        "|cffaaaaaaSlash commands: /gearset save <name>, /gearset equip <name>, "
        "/gearset delete <name>, /gearset list. Short alias: /vgs|r",
    "|cffffffffLOADOUTS SIDEBAR|r\\n|cffaaaaaaDrag or arrow keys|r":
        "|cffffffffGEAR SETS SIDEBAR|r\\n|cffaaaaaaDrag or arrow keys|r",
}

# Diese Keys betreffen den alten kontoweiten Legacy-Import aus VuloClassicUI.
# Sie werden nicht umbenannt, sondern durch neue Texte fuer den
# VuloClassicUI-Import ersetzt und hier deshalb ersatzlos entfernt.
DROP_KEYS = [
    "Import account-wide loadouts",
    "Imported %d account-wide loadout(s) onto this character.",
    "No account-wide loadouts to import.",
    "You have account-wide loadouts from an older version. Type /lo import to copy them onto this character.",
    "|cffaaaaaaYou have gear sets saved account-wide by an older version. Loadouts are now per-character "
    "\u2014 import copies them onto THIS character.|r",
]

KEY_IN_CODE = re.compile(r'L\["((?:[^"\\]|\\.)*)"\]')


def source_keys():
    keys = set()
    for src in SOURCES:
        keys.update(KEY_IN_CODE.findall(src.read_text(encoding="utf-8")))
    return keys


def verify():
    """Jeder Key der Map muss in der Quelle vorkommen - sonst ist er vertippt."""
    keys = source_keys()
    bad = [k for k in list(RENAME_MAP) + DROP_KEYS if k not in keys]
    if bad:
        print(f"FEHLER: {len(bad)} Key(s) kommen in der Quelle nicht vor:")
        for k in bad:
            print(f"  - {k!r}")
        return 1
    total = len(RENAME_MAP) + len(DROP_KEYS)
    print(f"OK - alle {total} Keys in der Quelle nachgewiesen "
          f"({len(RENAME_MAP)} umbenannt, {len(DROP_KEYS)} entfallen)")
    return 0


def apply_to_file(path):
    """Ersetzt alte durch neue Keys. Gibt die Anzahl der Ersetzungen zurueck."""
    text = path.read_text(encoding="utf-8")
    count = 0
    # Laengste zuerst, damit "Loadouts" keine laengeren Keys zerschneidet.
    for old in sorted(RENAME_MAP, key=len, reverse=True):
        needle = '"' + old + '"'
        if needle in text:
            count += text.count(needle)
            text = text.replace(needle, '"' + RENAME_MAP[old] + '"')
    path.write_text(text, encoding="utf-8")
    return count


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args or args[0] == "--verify":
        sys.exit(verify())
    total = 0
    for arg in args:
        n = apply_to_file(Path(arg))
        print(f"{arg}: {n} Ersetzungen")
        total += n
    print(f"gesamt: {total}")
