# Entscheidungen

Nur anhängen, neueste unten. `assumed` = Claude hat eine Vorgabe gewählt, der Nutzer kann sie
kippen. `rejected` = abgelehnt, nicht wieder anbieten.

Format: Datum · Entscheidung · Quelle · Feature

Sitzungen vor dem 2026-09-27 liegen auf dem Gaming-PC; bis dahin sind Commits die Quelle.

- 2026-07-28 · Eigenständiges Addon statt Modul in VuloClassicUI; Sets einmalig aus VuloClassicUI übernehmen · da714be (Spezifikation) · F001
- 2026-07-28 · Kein Schlafmodus neben VuloClassicUI – VuloGearSets läuft immer · 77ca40a · —
- 2026-08-01 · Classic-Stil ist Standard (auf Forever später der Forever-Stil) · 4c12f4b, 83288ff · —
- 2026-09-27 · Addon auf WoW: Forever lauffähig machen, mit Forever-Stil · user „kannst du das addon auch für WoW Forever nutztbar machen und es dem style anpassen“ · —
- 2026-09-27 · Sets auf Forever zusätzlich in Blizzards Ausrüstungsmanager spiegeln (C_EquipmentSet) · user „Mach deinen Vorschlag“ · —
- 2026-09-28 · Verbesserungsvorschläge 1–5 umsetzen, danach 6 · user „Ja“ · Liste ist im N100-Protokoll nicht erhalten; umgesetzt wurden u. a. Aktionsleiste, Symbolauswahl über der Leiste
- 2026-09-28 · Aus der nächsten Vorschlagsliste: „mach 1 und 2“ (Zurück zur vorherigen Ausrüstung, Sets in die Bank) · user · —
- 2026-09-28 · Eigene Texte in Expressway · user „können wir die schritart uaf expresessway machen“ · —
- 2026-09-28 · Setnamen und Fenstertitel bleiben Blizzard-Schrift · user „nein setnamen soll so bleiben“ · I-04
- 2026-09-28 · rejected · „In die Bank legen“ zieht getragene Teile aus · user „nein“ · I-16
- 2026-09-28 · Set-Modul auf acht Dateien aufteilen (ohne Verhaltensänderung) · Vorschlag angenommen · 45743e2
- 2026-10-01 · CurseForge-Text: nur die 2–3 wichtigsten Slash-Befehle; „World of Warcraft: Forever“ ausdrücklich nennen, README genauso · user · —
- 2026-10-04 · Symbole des Spiels statt der 209 eigenen Symbol-Dateien, abgerufen wie bei Blizzard · user · I-09
- 2026-10-04 · assumed · Sets mit einem entfernten eigenen Symbol fallen auf das automatische Symbol zurück (Migration) · —
- 2026-10-04 · Symbolauswahl und Slot-Flyout im Forever-Look · user „können wir das auch in dem wow forever style machen“ · I-08
- 2026-10-04 · assumed · Slot-Flyout bekommt den schmalen Theme-Rand statt Blizzards Popup-Rahmen (dessen Ecken sind über 70 px hoch) · user „abstand und rahmen dicke kleiner“ · I-08
- 2026-10-06 · Vier weitere Sprachen · user „mach die 4 wichtigsten sprachen“ · —
- 2026-10-06 · assumed · Gewählt: frFR, esES (gilt für esMX), ruRU, zhCN; ptBR und koKR nicht · —
- 2026-10-06 · assumed · Auf ruRU/zhCN/zhTW/koKR Blizzards Standardschrift statt Expressway · I-05
- 2026-10-06 · Sockel-Leiste: auf Forever kein Hinweis auf VuloClassicUI · user · I-14
- 2026-10-09 · Projektregeln festhalten, damit nichts kaputtgeht oder verschwindet · user · I-02, I-03
- 2026-10-09 · assumed · Keine große Umstrukturierung des Codes – Aufbau ist schon modular, Umbau wäre das größere Risiko · —
- 2026-10-09 · Kein Schlagschatten im Forever-Stil · user „schatten … entfernen“ · I-08
- 2026-10-09 · assumed · Schatten bleibt in Classic und Modern · I-08
- 2026-10-10 · Item-Tooltip darf nicht flackern · user · I-10
- 2026-10-10 · Leere Knopftexte „ein für alle mal“ beheben · user „fix das bitte ein für alle mal“ · I-05
- 2026-10-10 · `/vgs` allein öffnet die Einstellungen, Hilfe unter `/vgs help` · user „mach dass /vgs allein die einstellungen öffnet“ · F-Eintrag in features.md
- 2026-10-10 · Projektgedächtnis unter `docs/pro/` (Skill pro) · user `/pro` · —
- 2026-10-10 · assumed · Keine Code-Verschiebungen beim pro-Setup; nur Dokumente und Prüfer · —
- Laufend · Release nur auf ausdrückliches „release“ · user · I-20
- 2026-10-11 · F049 im Spiel bestätigt, Release 1.17.3 · user „passt alles, release“ · F049
- 2026-10-11 · Speichern in Blizzards Ausrüstungsmanager soll auch bei uns speichern · user „wenn wir in blizzard ausrüstungsmanager das gear speichern es bei uns gespeichert wird?“ · F050
- 2026-10-11 · assumed · Kein eigener Schalter: läuft unter „Sets auch in Blizzards Ausrüstungsmanager führen“ · F050
- 2026-10-11 · assumed · Umbenennen/Löschen in Blizzards Fenster nicht übernommen, vorhandene Blizzard-Sets nicht importiert (als Ideen F051, F052 notiert) · F050
- 2026-10-11 · assumed · Hemd und Wappenrock zählen beim Abgleich mit Blizzards Kopie nicht mehr, damit in Blizzards Fenster angelegte Sets nicht still überschrieben werden · F050
- 2026-10-11 · Umbenennen und Symbolwechsel in Blizzards Bearbeiten-Fenster übernehmen · user „kannst du das auch machen“ · F051
- 2026-10-11 · assumed · Löschen in Blizzards Fenster löscht unser Set weiterhin nicht (I-03) · F051
