"""Struktur- und Kopplungspruefung fuer VuloGearSets."""
import re
import sys
from pathlib import Path

# Repo-Root ist zugleich der Addon-Ordner.
ADDON = Path(__file__).resolve().parent.parent
TOC = ADDON / "VuloGearSets.toc"

# Ordner ohne Addon-Code, die der Pruefer nicht anfassen darf.
SKIP_DIRS = {"docs", "tools"}

# Nur diese Datei darf VuloClassicUIs SavedVariables anfassen.
# Geprueft werden die Globals selbst, nicht das blosse Wort "VuloClassicUI":
# Funktionsnamen wie ImportFromVuloClassicUI und Uebersetzungstexte, die das
# Addon erwaehnen, sind keine Kopplung.
COEXIST_FILE = "Core/Coexistence.lua"
FOREIGN_GLOBALS = [r"\bVuloClassicUIDB\b", r"\bVuloClassicUICharDB\b"]

# Symbole aus dem Vulo-Framework, die es hier nicht mehr gibt.
FORBIDDEN = [
    (r"ns\.UI\s*[:.]\s*ToggleMainFrame", "ns.UI:ToggleMainFrame gibt es hier nicht"),
    (r"ns\s*:\s*OpenConfig", "ns:OpenConfig heisst hier ns:ToggleOptions"),
    (r"LibStub", "keine Libs im Standalone"),
]

errors = []


def lua_files():
    return sorted(
        p for p in ADDON.rglob("*.lua")
        if not set(p.relative_to(ADDON).parts) & SKIP_DIRS
    )


def rel(p):
    return p.relative_to(ADDON).as_posix()


def strip_comments(text):
    """Entfernt Lua-Kommentare, laesst Strings unangetastet.

    Noetig, weil sonst jeder erklaerende Kommentar als Befund zaehlt --
    "wie in VuloClassicUI" ist Prosa, kein Kopplungsproblem.
    Kommentare werden durch Leerzeichen ersetzt, damit Zeilennummern stimmen.
    """
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        # Langer Klammerausdruck: [[ ... ]] oder [=[ ... ]=]
        if c == "[" and i + 1 < n:
            m = re.match(r"\[(=*)\[", text[i:])
            if m:
                close = "]" + m.group(1) + "]"
                end = text.find(close, i + m.end())
                end = n if end == -1 else end + len(close)
                out.append(text[i:end])          # langer String bleibt
                i = end
                continue
        if c == "-" and text.startswith("--", i):
            m = re.match(r"--\[(=*)\[", text[i:])
            if m:                                 # Blockkommentar
                close = "]" + m.group(1) + "]"
                end = text.find(close, i + m.end())
                end = n if end == -1 else end + len(close)
            else:                                 # Zeilenkommentar
                end = text.find("\n", i)
                end = n if end == -1 else end
            out.append("".join(ch if ch == "\n" else " " for ch in text[i:end]))
            i = end
            continue
        if c in "\"'":
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == c or text[j] == "\n":
                    j += 1
                    break
                j += 1
            out.append(text[i:j])
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


def code_of(p):
    return strip_comments(p.read_text(encoding="utf-8"))


def check_toc():
    if not TOC.exists():
        errors.append(f"TOC fehlt: {TOC}")
        return
    listed = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        listed.append(line.replace("\\", "/"))
    on_disk = {rel(p) for p in lua_files()}
    for entry in listed:
        if entry not in on_disk:
            errors.append(f"TOC listet nicht vorhandene Datei: {entry}")
    for f in sorted(on_disk - set(listed)):
        errors.append(f"Datei nicht in der TOC gelistet: {f}")


def used_locale_keys():
    """Alle L["..."]-Keys aus dem Addon-Code, ohne die Locale-Dateien selbst."""
    keys = set()
    pattern = re.compile(r'L\["((?:[^"\\]|\\.)*)"\]')
    for p in lua_files():
        if rel(p).startswith("Locales/"):
            continue
        keys.update(pattern.findall(code_of(p)))
    return keys


def defined_locale_keys():
    p = ADDON / "Locales" / "deDE.lua"
    if not p.exists():
        return set()
    pattern = re.compile(r'\["((?:[^"\\]|\\.)*)"\]\s*=')
    return set(pattern.findall(code_of(p)))


def check_locales():
    used = used_locale_keys()
    defined = defined_locale_keys()

    # Ein benutzter Key ohne Uebersetzung ist immer ein Fehler.
    for k in sorted(used - defined):
        errors.append(f"Key ohne deutsche Uebersetzung: {k!r}")

    orphans = sorted(defined - used)
    if not orphans:
        return
    # Solange die portierten Module fehlen, greift die Locale-Datei ihnen vor -
    # dann sind verwaiste Keys erwartbar und werden nur gezaehlt.
    if not (ADDON / "Modules" / "GearSets.lua").exists():
        print(f"Hinweis: {len(orphans)} Keys noch ungenutzt "
              f"(Modules/GearSets.lua fehlt - erwartet bis zur Portierung)")
        return
    for k in orphans:
        errors.append(f"Verwaister Key in deDE.lua: {k!r}")


def check_coupling():
    for p in lua_files():
        name = rel(p)
        text = code_of(p)
        if name != COEXIST_FILE:
            for g in FOREIGN_GLOBALS:
                if re.search(g, text):
                    errors.append(
                        f"{name}: Zugriff auf {g.strip(chr(92) + 'b')} "
                        f"gehoert nach {COEXIST_FILE}")
        for pattern, msg in FORBIDDEN:
            if re.search(pattern, text):
                errors.append(f"{name}: {msg}")


def check_lua5_1():
    """Lua-5.2+-Syntax, die der WoW-Client nicht versteht."""
    for p in lua_files():
        for n, line in enumerate(code_of(p).splitlines(), 1):
            if re.search(r"\bgoto\b", line):
                errors.append(f"{rel(p)}:{n}: goto gibt es in Lua 5.1 nicht")


def main():
    if not TOC.exists():
        print(f"FEHLER: {TOC} existiert nicht")
        return 1
    check_toc()
    check_locales()
    check_coupling()
    check_lua5_1()
    if errors:
        print(f"{len(errors)} Problem(e):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"OK - {len(lua_files())} Lua-Dateien, {len(used_locale_keys())} Locale-Keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
