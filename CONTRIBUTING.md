# Entwicklung

Der Repo-Wurzelordner **ist** der Addon-Ordner — `VuloGearSets.toc` liegt direkt darin.
Das Repository lässt sich also unverändert ins `Interface\AddOns`-Verzeichnis bringen.
`docs/`, `tools/` und `.github/` gehören nicht zur Auslieferung.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `Core/` | Namespace, Locale, Datenbank, Modulregistry, Events, Popup-Menü, Mover, Start |
| `UI/` | Widgets und das Einstellungsfenster mit dem Renderer für die Optionsliste |
| `Modules/` | Ausrüstungssets und Slot-Auswahl |
| `Locales/` | Englisch (leer, Schlüssel sind der Text) und Deutsch |
| `tools/` | Prüf- und Hilfsskripte |
| `docs/` | Spezifikation und Umsetzungsplan |

## Werkzeuge

```bash
python tools/check.py        # TOC-, Locale- und Kopplungsprüfung
powershell tools/deploy.ps1  # ins Spielverzeichnis kopieren
```

`tools/check.py` läuft nach jeder Änderung und prüft vier Dinge:

- jede Lua-Datei steht in der TOC und umgekehrt
- jeder benutzte Locale-Schlüssel hat eine deutsche Übersetzung
- keine verwaisten Übersetzungen bleiben übrig
- die SavedVariables von VuloClassicUI werden nur in `Core/Coexistence.lua` angefasst

Lua-Kommentare werden vor der Prüfung entfernt, damit erklärender Text keine Befunde
erzeugt.

`tools/rename_keys.py --verify` prüft die Umbenennungstabelle gegen die Quelldateien;
`tools/extract_locales.py` erzeugt `Locales/deDE.lua` neu. Beide werden nur gebraucht,
wenn Übersetzungen aus VuloClassicUI nachgezogen werden sollen.

## Übersetzungen

Die Schlüssel **sind** der englische Text. `Locales/enUS.lua` bleibt leer, der
Metatable-Fallback in `Core/Locale.lua` gibt bei fehlender Übersetzung den Schlüssel
zurück. Eine Textänderung am Englischen ist deshalb immer auch ein Schlüsselwechsel und
muss gleichzeitig in `Locales/deDE.lua` passieren — `check.py` fängt Fehler dabei ab.

## Veröffentlichung

Ein Versions-Tag löst `.github/workflows/release.yml` aus. Der Workflow baut das Paket
über [BigWigsMods/packager](https://github.com/BigWigsMods/packager) und lädt es zu
CurseForge, Wago und als GitHub-Release hoch.

```bash
git tag v1.0.0 && git push origin v1.0.0
```

`.pkgmeta` hält `docs/`, `tools/`, `.github/` und die Markdown-Dateien aus dem Paket
heraus.

**Einmalig einzurichten:**

1. Projekte auf CurseForge und Wago anlegen; beide vergeben eine ID.
2. IDs in `VuloGearSets.toc` unter `## Version` eintragen:
   ```
   ## X-Curse-Project-ID: <Zahl von der CurseForge-Projektseite>
   ## X-Wago-ID: <Kürzel aus der Wago-Projekt-URL>
   ```
   Fehlt eine Zeile, überspringt der Packager den Dienst kommentarlos.
3. Unter *Settings → Secrets and variables → Actions* anlegen:
   - `CF_API_KEY` — CurseForge-API-Token
   - `WAGO_API_TOKEN` — Wago-API-Token

   `GITHUB_TOKEN` stellt GitHub selbst bereit.

Die Versionsnummer zieht der Packager aus dem Tag, nicht aus der TOC. Beide sollten
trotzdem übereinstimmen.

Über *Actions → Release → Run workflow* lässt sich der Bau testen. Der Workflow
übergibt dem Packager dabei `-d`, sodass nur gebaut und nichts hochgeladen wird —
ohne dieses Flag würde er auch ohne Tag eine Alpha veröffentlichen.

## Spielversionen

Zwei TOCs, dieselben Lua-Dateien:

| Datei | Client | Interface |
|---|---|---|
| `VuloGearSets.toc` | TBC Classic Anniversary | 20506 |
| `VuloGearSets_Vanilla.toc` | Classic Era, Season of Discovery | 11509 |

`tools/check.py` haelt beide synchron: gleiche Dateiliste, gleiche Version. Eine
Datei nur in einer TOC zu ergaenzen faellt sonst erst im Spiel auf, und zwar nur
auf einer der beiden Versionen.

Was sich zwischen den Versionen unterscheidet, faengt der Code selbst ab:
Dual-Spec-Funktionen werden ueber `GetNumTalentGroups` erkannt und samt ihrer
Einstellungen ausgeblendet, wo es sie nicht gibt.

## Client-Eigenheiten

Zwei Dinge, über die man auf dem Anniversary-Client stolpert:

- **Schriften aus Addon-Ordnern werden nicht geladen.** Gemessen wurde eine Textbreite
  von 0 für Expressway aus diesem Addon, aus Details und aus VuloClassicUI — bei
  bitgleicher Datei. Verlässlich prüfbar ist das nur funktional über
  `GetStringWidth()`; weder `FontString:GetFont()` noch der Rückgabewert von
  `Font:SetFont()` taugen dafür. Siehe `UI/Widgets.lua`.
- **StaticPopups laufen über das neue GameDialog-System.** Das Eingabefeld heißt dort
  `self.EditBox`, nicht `self.editBox`. Dialoge sollten beide Schreibweisen abfragen
  und über `StaticPopup_Hide(name)` schließen statt über `GetParent()`.
