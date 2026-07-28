# Changelog

## 1.4.0

- Status marker next to each gear set: **green** when the set is fully worn,
  **orange** when parts are in the bank, **red** when a part cannot be found at
  all. The tooltip lists which parts are where.
  Note that "not found" means "not on this character" — the client cannot tell a
  sold item from one sitting on an alt or in the mail.
- The marker updates right after equipping. Swapping runs over several frames, so
  it used to show the state from before the change.
- `/gearset tune left <n>` and `tune show` for the sidebar edges.
- Fixed: the compact slot picker always opened to the right instead of only when
  the preferred side had no room.

## 1.3.1

- A custom icon no longer disappears when you update a set. Saving and overwriting
  replaced the whole entry, dropping everything that was not gear data — including
  the chosen icon and the creation date.
- The compact slot picker flips to the other side when the character window sits
  at the edge of the screen. It used to open outwards regardless and ran off-screen.

## 1.3.0

- The sidebar now only shows on the **Character** tab. On Reputation, Skills or
  PvP an equipment sidebar has no context, so it stays out of the way and comes
  back when you switch to Character again.

## 1.2.1

Polish for the Classic style, which uses a much wider frame than the modern one.

- The sidebar now lines up with the *visible* edge of the character window
  instead of the frame bounds, which are larger and include invisible padding.
  New `/gearset tune left <n>`, plus `tune show` to print the current values.
- Rows, buttons, popup titles and item icons kept the spacing of the thin modern
  border and overlapped the Classic frame. Padding now follows the style.
- Sidebar buttons stretch to the available width instead of using fixed sizes,
  so they keep the same distance to the frame in both styles.
- The selection bar on a gear set is inset and less intense in Classic.
- Hovering an equipment slot reacts faster: 0.10s instead of 0.25s.

## 1.2.0

- Window style option. **Modern** keeps the dark look with the purple accent,
  **Classic** switches every window to Blizzard's dialog frame so they sit
  naturally next to the default interface. Buttons follow the style as well.
- The style can be changed at any time; no reload required.
- Dropdowns now use an arrow icon instead of a typed letter, and it follows the
  style like everything else.

## 1.1.0

- Discord button in the settings window. Clicking it opens a dialog with the invite
  link preselected, ready to copy with Ctrl+C — the client cannot open a browser.
- The settings window now has a footer showing the addon version.

## 1.0.1

- Interface version raised to 20506 (game version 2.5.6). The addon was flagged as
  out of date on current Anniversary clients.

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
