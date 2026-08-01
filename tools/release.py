"""Vorflugpruefung und Versionsbump fuer VuloGearSets.

Ohne Argument: berichtet Version, letzten Tag, alle Commits seitdem und den
Zustand des Arbeitsbaums - die Vorlage, aus der der Changelog geschrieben
wird. Ein Aufruf statt vier.

Mit <version>: prueft alles, was sonst nur erinnert wurde, und setzt danach
die Version. Bricht bei jedem Problem mit Code 1 ab.

Committet, taggt und pusht NICHT. Das bleibt bewusst von Hand, weil es
andere Leute erreicht.

    python tools/release.py
    python tools/release.py 1.8.1
"""
import re
import subprocess
import sys
from pathlib import Path

ADDON = Path(__file__).resolve().parent.parent
TOC = ADDON / "VuloGearSets.toc"
NAMESPACE = ADDON / "Core" / "Namespace.lua"
CHANGELOG = ADDON / "CHANGELOG.md"

# Die Version steht an DREI Stellen, und tools/check.py vergleicht nur die
# TOCs gegeneinander - ns.VERSION nicht. Genau deshalb gibt es diese Datei:
# von Hand bumpen hiess dreimal daran denken.
NS_VERSION_RE = re.compile(r'(ns\.VERSION\s*=\s*")([^"]*)(")')
TOC_VERSION_RE = re.compile(r'(?mi)^(##\s*Version:\s*)(.*?)(\s*)$')

VERSION_RE = re.compile(r'^\d+\.\d+\.\d+$')


def git(*args, strip=True):
    """git im Repo-Root. Gibt stdout zurueck, bei Fehler None.

    strip=False fuer 'status --porcelain': dort steht der Statuscode in den
    ERSTEN zwei Spalten, und bei einer nur im Baum geaenderten Datei ist die
    erste davon ein Leerzeichen. Ein strip() ueber die Gesamtausgabe frisst
    genau dieses Zeichen der ersten Zeile - der Pfad war danach um eins
    verschoben und passte auf keine Ausnahme mehr.
    """
    try:
        out = subprocess.run(
            ["git", "-C", str(ADDON), *args],
            capture_output=True, text=True, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return None
    if out.returncode != 0:
        return None
    return out.stdout.strip() if strip else out.stdout


def all_tocs():
    return sorted(ADDON.glob("VuloGearSets*.toc"))


def read_keep_newlines(path):
    """Liest ohne Zeilenende-Uebersetzung, damit ein Schreiben nichts umbricht.

    Ueber open() statt Path.read_text: dessen newline-Argument gibt es erst
    ab Python 3.13, und ohne das schriebe der Bump auf Windows die ganze
    Datei auf CRLF um - ein Riesendiff fuer eine geaenderte Ziffer.
    """
    with open(path, "r", encoding="utf-8", newline="") as fh:
        return fh.read()


def write_keep_newlines(path, text):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def toc_version(toc):
    m = TOC_VERSION_RE.search(read_keep_newlines(toc))
    return m.group(2).strip() if m else None


def ns_version():
    if not NAMESPACE.exists():
        return None
    m = NS_VERSION_RE.search(read_keep_newlines(NAMESPACE))
    return m.group(2) if m else None


def version_spots():
    """[(Anzeigename, Pfad, gefundene Version)] fuer alle drei Stellen."""
    spots = [(t.name, t, toc_version(t)) for t in all_tocs()]
    spots.append((NAMESPACE.relative_to(ADDON).as_posix(), NAMESPACE, ns_version()))
    return spots


def changelog_top_version():
    """Die Version des obersten ## -Blocks in CHANGELOG.md."""
    if not CHANGELOG.exists():
        return None
    for line in CHANGELOG.read_text(encoding="utf-8").splitlines():
        m = re.match(r'^##\s+(\S+)', line.strip())
        if m:
            return m.group(1)
    return None


def last_tag():
    return git("describe", "--tags", "--abbrev=0")


def tag_exists(version):
    """Lokal ODER auf dem Remote - ein Tag, den es schon gibt, laesst sich
    nicht neu veroeffentlichen, und das faellt sonst erst beim Pushen auf."""
    tag = f"v{version}"
    local = git("tag", "--list", tag)
    if local:
        return "lokal"
    remote = git("ls-remote", "--tags", "origin", tag)
    if remote:
        return "auf origin"
    return None


# =========================================================
# Bericht ohne Argument
# =========================================================
def report():
    print("VuloGearSets")
    for name, _path, ver in version_spots():
        print(f"  {name:<30} {ver or '|FEHLT|'}")

    versions = {v for _n, _p, v in version_spots()}
    if len(versions) != 1:
        print("  !! Die Versionsstellen weichen voneinander ab")

    print(f"  {'CHANGELOG.md (oberster Block)':<30} {changelog_top_version() or '-'}")

    tag = last_tag()
    print(f"  {'letzter Tag':<30} {tag or '-'}")
    print(f"  {'Branch':<30} {git('rev-parse', '--abbrev-ref', 'HEAD') or '-'}")

    if tag:
        log = git("log", f"{tag}..HEAD", "--oneline")
        print(f"\nCommits seit {tag}:")
        if log:
            for line in log.splitlines():
                print(f"  {line}")
            print("\n  ^ Das ist die Vorlage fuer den Changelog. Aus dieser Liste"
                  "\n    schreiben, nicht aus dem Gedaechtnis der Sitzung.")
        else:
            print("  (keine - es gibt nichts zu veroeffentlichen)")

    status = git("status", "--porcelain", "--untracked-files=all", strip=False)
    print("\nArbeitsbaum:")
    if status and status.strip():
        for line in status.splitlines():
            print(f"  {line}")
    else:
        print("  sauber")
    return 0


# =========================================================
# Vorflugpruefung
# =========================================================
def preflight(version, problems):
    if not VERSION_RE.match(version):
        problems.append(f"Version {version!r} ist nicht X.Y.Z")
        return  # alles Weitere haengt an einer gueltigen Version

    where = tag_exists(version)
    if where:
        problems.append(f"Tag v{version} existiert bereits ({where})")

    top = changelog_top_version()
    if top != version:
        problems.append(
            f"CHANGELOG.md beginnt mit '## {top or '?'}' statt '## {version}'. "
            "Erst die Notizen schreiben - hinterher geschriebene Notizen sind "
            "vergessene Notizen.")

    for name, _path, ver in version_spots():
        if ver is None:
            problems.append(f"{name}: keine Versionszeile gefunden")
        elif ver == version:
            problems.append(f"{name}: steht bereits auf {version}")

    # Feature-Arbeit gehoert VOR das Release in eigene Commits. Liegt beim
    # Bump noch Ungesichertes herum, landet es unbesehen im Release-Commit -
    # so waere um ein Haar ein Werkzeug-Artefaktordner mitveroeffentlicht
    # worden.
    #
    # Der Changelog-Block wird PER ABLAUF vor dem Bump geschrieben, ist also
    # zu Recht schon geaendert; dasselbe gilt fuer die Versionsstellen, falls
    # ein vorheriger Lauf an der Pruefung scheiterte. Alles andere nicht.
    allowed = {CHANGELOG.name}
    allowed |= {t.name for t in all_tocs()}
    allowed.add(NAMESPACE.relative_to(ADDON).as_posix())

    stray = []
    raw = git("status", "--porcelain", "--untracked-files=all", strip=False) or ""
    for line in raw.splitlines():
        # Format: XY <pfad>, bei Umbenennungen "alt -> neu".
        path = line[3:].strip().strip('"').split(" -> ")[-1]
        if path not in allowed:
            stray.append(line)
    if stray:
        problems.append(
            "Arbeitsbaum enthaelt Aenderungen, die nicht zum Release gehoeren. "
            "Feature-Arbeit vorher separat committen, damit der Release-Commit "
            "nur Changelog und Version traegt:\n      "
            + "\n      ".join(stray))


# =========================================================
# Bump
# =========================================================
def bump(version):
    changed = []
    for toc in all_tocs():
        text = read_keep_newlines(toc)
        new = TOC_VERSION_RE.sub(lambda m: f"{m.group(1)}{version}{m.group(3)}",
                                 text, count=1)
        if new != text:
            write_keep_newlines(toc, new)
            changed.append(toc.name)

    text = read_keep_newlines(NAMESPACE)
    new = NS_VERSION_RE.sub(lambda m: f"{m.group(1)}{version}{m.group(3)}",
                            text, count=1)
    if new != text:
        write_keep_newlines(NAMESPACE, new)
        changed.append(NAMESPACE.relative_to(ADDON).as_posix())
    return changed


def run_check():
    out = subprocess.run([sys.executable, str(ADDON / "tools" / "check.py")],
                         capture_output=True, text=True,
                         encoding="utf-8", errors="replace")
    return out.returncode, (out.stdout + out.stderr).strip()


def new_textures(tag):
    """Neue .tga seit dem letzten Tag - die brauchen einen Client-Neustart."""
    if not tag:
        return []
    out = git("diff", "--name-only", "--diff-filter=A", f"{tag}..HEAD")
    if not out:
        return []
    return [f for f in out.splitlines() if f.lower().endswith(".tga")]


def main(argv):
    if not TOC.exists():
        print(f"FEHLER: {TOC} existiert nicht")
        return 1
    if len(argv) < 2:
        return report()
    if len(argv) > 2:
        print(__doc__)
        return 1

    version = argv[1].lstrip("v")
    problems = []
    preflight(version, problems)
    if problems:
        print(f"{len(problems)} Problem(e) - nichts geaendert:")
        for p in problems:
            print(f"  - {p}")
        return 1

    tag = last_tag()
    changed = bump(version)
    print(f"Version auf {version} gesetzt:")
    for name in changed:
        print(f"  {name}")

    code, out = run_check()
    print(f"\ntools/check.py: {out}")
    if code != 0:
        print("\nPruefung fehlgeschlagen. Die Versionsstellen stehen bereits auf "
              f"{version} - erst das Problem beheben, dann weiter.")
        return 1

    tga = new_textures(tag)
    if tga:
        print("\nNeue Texturen in diesem Stand:")
        for f in tga:
            print(f"  {f}")
        print("  -> Der Client baut seinen Dateiindex beim Start. Diese "
              "Dateien\n     erscheinen NUR nach einem vollen Neustart, "
              "nicht nach /reload.")
    else:
        print("\nKeine neuen Texturen - ein /reload genuegt den Spielern.")

    branch = git("rev-parse", "--abbrev-ref", "HEAD") or "main"
    print(f"""
Bereit. Jetzt von Hand (Commit-Botschaft: keine fremden Addon-Namen,
keine Abkuerzungen, kein Co-Authored-By):

  git add -A
  git commit          # v{version}: <kurze Zusammenfassung> + Stichpunkte
  git push origin {branch}
  git tag -a v{version} -m "v{version}: <kurze Zusammenfassung>"
  git push origin v{version}

Der Tag veroeffentlicht: release.yml laesst den Packager laufen.
Danach den Lauf bestaetigen:

  https://github.com/mrvulo/VuloGearSets/actions/workflows/release.yml
""")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
