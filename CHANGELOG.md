# Changelog

## 1.0.0

First release. Split out of the equipment set module of VuloClassicUI and rebuilt as a
standalone addon.

**Gear sets**

- Save, equip, overwrite and delete sets — either your full equipment or just
  trinkets, weapons, rings or armour
- Sidebar on the character frame with a custom icon per set, per-slot replacement and
  a context menu; freely movable via `/gearset unlock`
- Minimap button with the set switcher on left-click and the settings on right-click
- Automatic switching on stance and form as well as on dual spec
- Swapping is refused during combat and carried out once the fight ends

**Slot picker**

- Hovering an equipment slot shows the matching items from your bags right next to it;
  a click equips one. Nothing appears when there is nothing to swap.
- The configured click additionally opens the full window with all items, a counter
  and a movable title bar

**Compared to the module in VuloClassicUI**

- Runs on its own, no other addons required
- Its own settings window instead of the navigation sidebar
- Sets are stored per character; the account-wide pool of older versions is gone
- Existing sets are imported automatically on first login per character, so the
  separate import command is no longer needed
- Neither addon disables the other; running both just prints a notice
- `/gearset unlock` replaces the UnlockMode module, `/gearset config` opens the
  settings
- The slot picker now also reacts to plain hovering

**Known issues**

- The Anniversary client does not load font files from addon folders. The bundled
  Expressway is therefore unused for now and Arial Narrow from the client is used
  instead. Details via `/vgsfont`.
