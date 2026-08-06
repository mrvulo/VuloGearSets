# VuloGearSets — Sets von der Bank anlegen

Datum: 2026-08-06
Status: Design freigegeben

## Ziel

Liegen Teile eines Sets in der Bank, sollen sie beim Anlegen mitkommen — solange das
Bankfenster offen ist. Bisher sucht das Anlegen nur in den Taschen; Bankteile gelten als
fehlend, obwohl sie zwei Handgriffe entfernt liegen.

## Ausgangslage

`equipLoadout` sucht über `findItemInBags` in `bag = 0 .. NUM_BAG_SLOTS`. Was dort nicht
liegt, wird noch an den anderen Ausrüstungsslots gesucht (vertauschte Ringe) und sonst als
fehlend gezählt.

`getSetStatus` kennt die Bank bereits — als Differenz `GetItemCount(id, true) -
GetItemCount(id)` — und färbt den Statuspunkt danach. Der Punkt sagte also "vorhanden",
das Anlegen sagte "fehlt".

## Aufbau

### Erreichbarkeit

`bankIsOpen()` fragt `BankFrame:IsShown()`. Nur dann behandelt der Client die Bankfächer
wie Taschenfächer: was sich von Hand auf einen Ausrüstungsslot ziehen lässt, lässt sich
auch über `EquipCursorItem` anlegen. Ist das Fenster zu, liefern die Fächer nichts —
dann wird gar nicht erst dort gesucht.

### Suchraum

`containerIDs(includeBank)` liefert die Containerliste: erst die Taschen, dann
`BANK_CONTAINER` (-1) und die Bankbeutel ab `NUM_BAG_SLOTS + 1`. Taschen bleiben vorne,
ein Teil aus der Tasche wird dem gleichen Teil an der Bank also weiter vorgezogen.

`findItemInBags(itemID, includeBank)` läuft über diese Liste und meldet als drittes
Ergebnis, ob der Fund aus einem Bankfach kam.

### Anlegen

`equipLoadout` hält einmal am Anfang fest, ob die Bank offen ist — der Suchraum soll sich
während des Anlegens nicht ändern — und gibt das an die Suche weiter. An der Mechanik
ändert sich nichts: `ns:EquipBagItemToSlot` legt Bankteile genauso an wie Taschenteile.

Eine Ausnahme: der `UseContainerItem`-Fallback gilt nur noch für Taschen. Auf ein Bankfach
angewandt legt der Aufruf nichts an, er schiebt das Teil in die Taschen — und das wäre als
"angelegt" gezählt worden.

Das verdrängte Teil landet in dem Bankfach, aus dem das neue kam, genau wie beim Ziehen
von Hand. Wer ein Bank-Set anlegt, hat sein altes Zeug danach an der Bank liegen.

### Meldung

Bei geschlossener Bank wird ein dort liegendes Teil nicht mehr als fehlend gezählt,
sondern eigens gemeldet:

> 3 Teile liegen in der Bank — öffne das Bankfenster, um sie anzulegen.

Gezählt wird über dieselbe Differenz wie in `getSetStatus`, mit Abzug je gemeldetem Teil:
ein einzelnes Exemplar soll nicht für zwei Slots gemeldet werden.

Die Zeile steht neben den bisherigen Meldungen. "Bereits angelegt" erscheint nicht mehr,
wenn in Wahrheit Teile an der Bank fehlen.

## Nicht dabei

- Slot-Picker und "Slot ersetzen" bleiben bei den Taschen
- Speichern eines Sets greift nicht auf die Bank zu
- Der Statuspunkt bleibt, wie er ist: er unterscheidet schon zwischen Bank und fehlend
- Der Tempo-Schmuck (Reitgerte) sucht weiter nur in den Taschen
