# VuloGearSets

Ausrüstungsset-Verwaltung für WoW TBC Classic Anniversary (Interface 20505).

Speichere deine aktuelle Ausrüstung als benannte Sets und wechsle mit einem Klick
zwischen ihnen. Läuft eigenständig, ohne weitere Addons.

## Funktionen

- **Sets speichern und anlegen** — komplett oder nur Teilbereiche: Schmuckstücke,
  Waffen, Ringe, Rüstung
- **Seitenleiste am Charakterfenster** mit eigenem Symbol je Set, Slot-weisem
  Ersetzen und Kontextmenü
- **Minimap-Button** — Linksklick öffnet die Set-Auswahl, Rechtsklick die
  Einstellungen, Ziehen verschiebt ihn
- **Slot-Auswahl** — beim Überfahren eines Ausrüstungsslots erscheinen die
  passenden Teile aus deinen Taschen direkt daneben; ein Klick legt sie an.
  Der eingestellte Klick öffnet zusätzlich das große Fenster mit allen Teilen.
- **Automatischer Wechsel** bei Haltung und Gestalt (Krieger-Haltungen,
  Druiden-Gestalten) und bei Dual-Spec
- **Kampfsperre** — im Kampf wird nicht umgerüstet; ein währenddessen
  ausgelöster Wechsel wird nachgeholt, sobald der Kampf endet
- Deutsch und Englisch

## Slash-Befehle

| Befehl | Wirkung |
|---|---|
| `/gearset save <Name>` | aktuelle Ausrüstung als Set speichern |
| `/gearset equip <Name>` | Set anlegen |
| `/gearset delete <Name>` | Set löschen |
| `/gearset list` | gespeicherte Sets auflisten |
| `/gearset spec` | Spec-Bindungen anzeigen und setzen |
| `/gearset config` | Einstellungen öffnen |
| `/gearset unlock` | Seitenleiste verschiebbar machen |
| `/gearset tune top\|bottom\|reset <n>` | Höhe der Seitenleiste feinjustieren |
| `/vgs` | Kurzform von `/gearset` |
| `/rl` | Oberfläche neu laden (nicht im Kampf) |
| `/vgsfont` | Schriftdiagnose |

Ein Set lässt sich auch direkt anlegen: `/gearset <Name>`.

## Verhältnis zu VuloClassicUI

VuloGearSets ist aus dem Ausrüstungsset-Modul von VuloClassicUI hervorgegangen und
läuft völlig unabhängig davon.

Ist VuloClassicUI installiert, übernimmt VuloGearSets beim **ersten Start auf einem
Charakter** dessen gespeicherte Sets samt Spec- und Gestalt-Bindungen. Die Daten von
VuloClassicUI werden dabei nur gelesen und bleiben unverändert.

Kein Addon schaltet das andere ab. Sind beide mit aktivem Set-Modul unterwegs, siehst
du zwangsläufig zwei Minimap-Buttons und zwei Seitenleisten; VuloGearSets weist einmal
pro Sitzung im Chat darauf hin. Wenn dich das stört, deaktiviere eines von beiden.

> **Reihenfolge beachten:** Wer VuloClassicUI entfernt, **bevor** VuloGearSets zum
> ersten Mal gestartet ist, hat keine gespeicherten Daten mehr zum Auslesen — der
> Import läuft dann ins Leere. Also erst VuloGearSets einmal starten, dann
> VuloClassicUI entfernen.

## Daten

| SavedVariable | Inhalt |
|---|---|
| `VuloGearSetsDB` | kontoweit: Darstellungsoptionen, Minimap-Button, Slot-Auswahl |
| `VuloGearSetsCharDB` | pro Charakter: Sets, Spec- und Gestalt-Bindungen, Position der Seitenleiste |

Sets liegen pro Charakter, weil sie sich auf dessen Ausrüstung beziehen.

## Bekannte Einschränkung: Schrift

Das Addon liefert Expressway mit, dieselbe Schrift wie VuloClassicUI. Auf dem
Anniversary-Client werden Schriftdateien aus Addon-Ordnern jedoch nicht geladen —
das betrifft nicht nur dieses Addon, sondern gleichermaßen dieselbe Datei aus
Details oder VuloClassicUI (gemessene Textbreite jeweils 0). Deshalb wird auf
Arial Narrow aus dem Client zurückgegriffen, das im Schnitt ähnlich schmal ist.
Nimmt ein Client Expressway an, wird sie automatisch benutzt.

`/vgsfont` zeigt, welche Schrift aktiv ist und was die Messung ergibt.

## Entwicklung

Der Repo-Ordner **ist** der Addon-Ordner — `VuloGearSets.toc` liegt im Wurzelverzeichnis.
`docs/` und `tools/` gehören nicht zur Auslieferung.

```
python tools/check.py      # TOC-, Locale- und Kopplungsprüfung
powershell tools/deploy.ps1  # ins Spielverzeichnis kopieren
```

`tools/check.py` prüft, dass jede Lua-Datei in der TOC steht und umgekehrt, dass
jeder benutzte Locale-Schlüssel eine deutsche Übersetzung hat und keine verwaisten
übrig sind, und dass die SavedVariables von VuloClassicUI nur in
`Core/Coexistence.lua` angefasst werden.

## Veröffentlichung

Ein Tag löst den Workflow in `.github/workflows/release.yml` aus, der das Paket über
[BigWigsMods/packager](https://github.com/BigWigsMods/packager) baut und zu CurseForge,
Wago und als GitHub-Release hochlädt.

```bash
git tag v1.0.0 && git push origin v1.0.0
```

`.pkgmeta` schließt `docs/`, `tools/`, `.github/` und die README aus dem Paket aus —
ausgeliefert wird nur, was das Spiel braucht.

**Vor dem ersten Release einmalig einrichten:**

1. Projekte auf CurseForge und Wago anlegen. Beide vergeben eine ID.
2. Diese IDs in `VuloGearSets.toc` eintragen, direkt unter `## Version`:
   ```
   ## X-Curse-Project-ID: <Zahl aus der CurseForge-Projektseite>
   ## X-Wago-ID: <Kürzel aus der Wago-Projekt-URL>
   ```
   Fehlt eine Zeile, überspringt der Packager den jeweiligen Dienst kommentarlos.
3. In den GitHub-Repo-Einstellungen unter *Secrets and variables → Actions* anlegen:
   - `CF_API_KEY` — CurseForge-API-Token aus dem Konto-Bereich
   - `WAGO_API_TOKEN` — Wago-API-Token aus den Kontoeinstellungen

   `GITHUB_TOKEN` stellt GitHub selbst bereit, das ist nichts einzurichten.

Die Versionsnummer zieht der Packager aus dem Tag, nicht aus der TOC. Beide sollten
trotzdem übereinstimmen.

## Lizenz

Siehe LICENSE.
