# VuloGearSets — Set-Zugehörigkeit im Item-Tooltip

Datum: 2026-08-06
Status: Design freigegeben

## Ziel

Jeder Item-Tooltip nennt die Sets, in denen das Item vorkommt. Eine Zeile, alphabetisch,
komma-getrennt:

```
Feuriger Kriegshelm
Gebunden wenn aufgehoben
...

Sets: Tank, PvP
```

Wirkt überall dort, wo der Client einen Item-Tooltip zeigt: Taschen, Bank, angelegte
Ausrüstung, Händler, Chat-Links.

## Ausgangslage

Die Sets liegen pro Charakter in `VuloGearSetsCharDB.sets` als
`sets[name].slots[equipSlot] = itemLink` (`Modules/GearSets.lua:58`). Alles, was der
Tooltip braucht, steht dort — die Modul-internen Helfer von `GearSets.lua` werden nicht
gebraucht.

`GearSets.lua` hat 3099 Zeilen. Die Anzeige kommt deshalb nicht dort hinein.

## Aufbau

### Neue Datei `Modules/ItemTooltip.lua`

Verstecktes Modul (`group = "_hidden"`) wie SlotPicker und SocketBar: die Einstellung steht
auf der Optionsseite des Set-Moduls, eine eigene Seite würde nie aufgerufen.

Abhängigkeiten: `ns:GetCharDB()`, `ns.L`, `ns:RegisterModule`. Sonst nichts. Das Modul liest
nur — es fasst weder Sets noch Blizzard-Frames verändernd an.

Eintrag in beide TOCs nach `Modules/SocketBar.lua`.

### Index

`ItemID → { Setnamen }`, beim ersten Tooltip eines Frames gebaut und mit
`C_Timer.After(0, ...)` wieder verworfen. Dasselbe Muster wie `getAvailIndex()`
(`Modules/GearSets.lua:274`).

Der Vorteil gegenüber einem dauerhaften Cache: jede Set-Änderung — speichern, löschen,
umbenennen, einzelnen Slot ersetzen — ist sofort sichtbar, ohne dass an jeder dieser
Stellen eine Invalidierung nachgezogen werden muss. Die Kosten sind eine Neuberechnung
je Frame, in dem überhaupt ein Tooltip erscheint: bei zwanzig Sets à siebzehn Teilen
sind das 340 Schleifendurchläufe.

### Vergleich

Über die Item-ID aus dem Link, plus Zufalls-Suffix, wenn **beide** Links eins tragen.
Ohne den Suffix fielen "Ring des Bären" und "Ring der Eule" zusammen — in Classic teilen
sich Items mit Zufallsverzauberung die ID. Verzauberung und Steine bleiben außen vor:
das ist derselbe Gegenstand.

### Tooltip-Hook

`TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` wenn vorhanden,
sonst `HookScript("OnTooltipSetItem")` auf `GameTooltip` und `ItemRefTooltip`. Kein
Versionstest, nur Proben und Zurückfallen — wie im Rest des Addons.

Ein Merker je Tooltip verhindert die doppelte Zeile; er wird beim Aufräumen des Tooltips
zurückgesetzt (`OnTooltipCleared` / `OnHide`). Der Hook feuert bei Taschen-Items auf
manchen Clients zweimal.

Hooks lassen sich nicht wieder lösen. Der Schalter wird deshalb im Hook selbst geprüft,
nicht beim Setzen — abgeschaltet läuft der Hook weiter, gibt aber sofort zurück.

### Ausgabe

Leerzeile, dann `Sets:` in Lila (`|cff9b6cff`), dahinter die Namen in Weiß, alphabetisch
sortiert, mit `, ` verbunden. Der Tooltip wird danach neu vermessen, damit der Rahmen zur
neuen Zeile passt.

### Einstellung

Ein Schalter im Abschnitt "Ausrüstungssets" der Optionsseite, standardmäßig an:
*Set-Zugehörigkeit im Item-Tooltip anzeigen*. Er schaltet das Modul über
`ns:ToggleModule` — wie bei Slot-Picker und Sockel-Leiste liegt das Ein/Aus damit pro
Charakter, der Standard kontoweit.

### Locale

Neue Keys in `Locales/deDE.lua` von Hand ergänzen (`enUS` ist leer, dort sind die Keys
selbst der Text).

## Nicht dabei

- Slot-Angabe je Set und Set-Symbole im Tooltip — hält die Zeile kurz
- Sets anderer Charaktere: Sets liegen pro Charakter, ein Item eines anderen Charakters
  ist von hier aus nicht auflösbar
