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

## Mitarbeit

Aufbau des Projekts, Prüfwerkzeuge, Übersetzungen und der Release-Ablauf stehen in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Lizenz

Siehe LICENSE.
