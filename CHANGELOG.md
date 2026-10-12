## 1.18.1 — 2026-10-11

- Fixed (Forever): an icon picked in Blizzard's edit window for a linked set now carries over to VuloGearSets, as renaming already did.

## 1.18.0 — 2026-10-11

Blizzard's equipment manager now works both ways on Forever.

- New (Forever): a set you create or save in Blizzard's equipment manager is saved in VuloGearSets too, with the slots Blizzard stored and the icon you picked, and stays linked.
- New: Renaming a linked set or changing its icon in Blizzard's edit window carries over, including its key binding, spec and form binding, and macro.
- New: Deleting a set in Blizzard's window never deletes it in VuloGearSets.
- Improved: Shirt and tabard no longer count when comparing a set with Blizzard's copy, so a set made in Blizzard's window is not silently rewritten.

## 1.17.3 — 2026-10-11

- Changed: `/vgs` (or `/gearset`) on its own now opens and closes the settings. The command list moved to `/vgs help`.

## 1.17.2 — 2026-10-10

- Fixed: The "Equip" and "Save" buttons in the sidebar no longer come up without text after logging in or reloading. The sidebar is built while the loading screen is still up, before the addon's font can draw; every text is now redrawn as soon as its window appears.
- Fixed (Forever): item tooltips no longer flicker when hovering a gear set item at a vendor or in your bags.

## 1.17.1 — 2026-10-09

- Changed (Forever): windows and menus no longer have a soft shadow, which looked like a grey rim around the metal frame. Classic and Modern keep it.
- Fixed: The "Equip" and "Save" buttons could still come up without text after logging in. Every button of the addon now draws its own label.

## 1.17.0 — 2026-10-06

- New: New languages: French, Spanish, Russian and Simplified Chinese, next to English and German. Spanish covers both the European and the Mexican client.
- New: On Russian, Chinese and Korean clients the addon's texts use Blizzard's font, since the bundled font has no Cyrillic or Chinese letters.
- Fixed: The "Equip" and "Save" buttons in the sidebar sometimes showed no text after logging in.
- Fixed: Dropdown lists in the settings opened partly behind the window. They now open on top, right below the list.
- Fixed (Forever): the socket bar's tooltip no longer mentions an addon that does not exist there.

## 1.16.0 — 2026-10-04

- New: The icon picker offers the game's own icons, the same list Blizzard's equipment manager and macro window use: every spell and item icon of your client, after "Auto" and the icons of the set's items.
- New: Filter between all icons, spells and items. The current icon is marked and in view when the picker opens. Drag the scroll bar to get through the list quickly.
- New: A chosen game icon also shows on the set's macro and, on Forever, on Blizzard's copy of the set.
- New (Forever): with the Blizzard themes the icon picker looks like Blizzard's own, with its frame, item-slot backgrounds, filter dropdown and scroll bar.
- Changed: The 209 bundled set icons are gone. A set that used one of them falls back to its automatic icon; pick a new one from the game's list.
- Changed (Forever): the slot flyout on the character frame has a slim frame in your theme's colour and sits tighter around the items.

## 1.15.0 — 2026-09-28

After updating, restart the game once: this version brings new files, which a `/reload` does not load.

- New: Back to previous gear. Every set switch remembers what the affected slots held before. Put it back on from the minimap menu, from its own key in Blizzard's key bindings (under VuloGearSets) or with `/gearset back`. Press it again to switch forward.
- New: Put a set in the bank. With the bank open, right-click a set and choose "Put in bank": the set's pieces in your bags move into free bank slots; what you are wearing stays on. Also as `/gearset bank <name>`.
- New: Place a set on your action bar. Right-click a set and choose "Place on action bar". On Forever you get Blizzard's copy of the set, otherwise a macro with the set's icon. Renaming, deleting or changing the icon keeps the macro in step; a macro you rewrote yourself is left alone.
- New (Forever): sets are also kept in Blizzard's equipment manager as soon as you save or fully wear them, so they are stored on the server and other addons and bag windows see which items belong to them. Renaming, deleting and icon changes follow along; Blizzard sets that are not ours stay untouched. Switch: "Also keep sets in Blizzard's equipment manager", on by default.
- Improved: The addon's own texts (menus, buttons, settings) now use the Expressway font. It was bundled all along but never picked up.
- Improved: The automatic set icon is always the one of the first item in slot order instead of a random one.
- Improved: Set names are trimmed at the edges when saving, like when renaming.
- Improved: Item tooltips no longer list a set twice when Blizzard's own line already names it.
- Fixed: Blizzard's icon picker for a new set in the equipment manager opened underneath the gear sets sidebar.

## 1.14.0 — 2026-09-27

- New: World of Warcraft: Forever support. The addon loads on the Forever client and does everything it does on Anniversary: saving and equipping sets, binding sets to your two talent groups, stance and form switching, equipping from the bank's tabs, the slot picker, the socket bar and the set line in item tooltips. The sidebar sits next to the character window's side tabs.
- New: "Forever" window style, the default on Forever. It takes the look of VuloForeverUI: its colors and, with its Blizzard themes, the client's metal frame. The sidebar wears the background and border of Blizzard's own equipment manager, with Blizzard's "New Set" button.
- Changed: The "New Set" button has a new look on every client: a dark card with a thin gold border, a green plus and green text.
- Fixed: Stance and form names on Anniversary and Classic Era. The form list only showed "Form 1/2/3" and flight form was never recognized, so druids never got the Charm of Swift Flight in flight form. Forms now show their real names.

## 1.13.0 — 2026-08-29

- New: Slots that were empty when a set was saved are emptied when you equip it. A set saved wearing only a few pieces, say nothing but jewelry for a graveyard run, used to answer "already equipped" and leave your armor on. Equipping now takes off whatever sits in those slots and puts it in your bags, with its own chat line and a warning when your bags have no room. Even a set with no items at all works now.
- New: Removing an item from a set in the editor now means "this slot should be empty" rather than "leave this slot alone". Sets saved before masks existed behave as before.
- Improved: The status dot counts those extra worn pieces too: a set only turns green once its empty slots really are empty.

## 1.12.2 — 2026-08-29

- Fixed: Two copies of the same item with different gems or enchants now actually swap. Sets tell the exact copy apart by its gems, enchant and random suffix, and equipping swaps in the one the set was saved with.
- Fixed: The sidebar status dot uses the same logic as the equip button, including a hint when the right copy is sitting in the closed bank.
- Fixed: If a saved copy can no longer be found anywhere, for example after re-gemming it, the set falls back to matching by item ID so nothing is wrongly reported as missing.

## 1.12.1 — 2026-08-17

- New: A set can show or hide your helmet and cloak. Right-click a set in the sidebar: the Helmet and Cloak entries cycle between leave as is, show and hide. The choice applies whenever the set is equipped, even if no item had to move.
- New: The default is leave as is, so existing sets behave exactly as before. The set tooltip only mentions the setting when the set actually changes something.

## 1.12.0 — 2026-08-17

- New: Gear sets can be put in your own order. Right-click a set for Move up and Move down, or drag it: a shadow of the row follows the pointer, a coloured line marks where it will land, and the list scrolls on its own at the top and bottom edge.
- New: The order is kept per character and applies everywhere sets are listed: the sidebar, the quick-switcher menu, the settings page and the tooltip line.
- New: Until you move something, the list stays alphabetical. Afterwards, new sets join at the bottom.

## 1.11.1 — 2026-08-06

- Fixed: A set that is already on no longer repeats itself in chat. The outcome of an attempt that moved nothing is remembered and reported once.
- Fixed: If a missing piece turns up in your bags in the meantime, the line is news again and comes back. The refusal during combat works the same way. Anything reporting a real swap always comes through.

## 1.11.0 — 2026-08-06

- New: A gear set can sit on a key. Right-click a set, pick Set key, and the next key you press belongs to it. Pressing it equips the set like a double-click on the row, wherever you are. Modifiers count, so Shift-1 and Alt-F are separate keys; the middle mouse button along with mouse 4 and 5 work as well.
- New: The row tooltip names the key, and the right-click menu has an entry to take it away. A key belongs to exactly one set: hand it to another and the previous owner loses it and is told so. Renaming a set carries its key along, deleting the set drops it, and the assignment lives per character.
- New: Blizzard's own key bindings are never rewritten and nothing is left behind when the addon is off. While the addon runs, the key takes precedence over whatever else uses it and does not show up in Blizzard's key binding list. Keys cannot be changed during combat; a change made there is applied when combat ends.
- Changed: The item list for the weapon slots opens downward, since the three weapon slots sit as a row under the character model. It only flips up when there is no room.

## 1.10.0 — 2026-08-06

- New: Item tooltips name the gear sets an item belongs to. Hover anything in your bags, at the bank, on your character or a link in chat, and a line at the bottom lists its sets. Can be turned off under Gear Sets.
- New: Gear sets equip from the bank. With the bank window open, the parts of a set sitting in your bank go on together with the rest. Your bags are searched first. The piece you were wearing goes into the bank slot the new one came from.
- Improved: Tooltip matching uses item ID plus random suffix, so an enchant or gem never hides the line, while a Ring of the Bear and a Ring of the Owl stay apart.
- Improved: With the bank closed, items waiting there are no longer counted as missing. They get their own line telling you to open the bank, and a set that is only short of bank items no longer claims it is already equipped.

## 1.9.1 — 2026-08-05

- New: A socket that already holds a gem asks before it is overwritten, since the old gem is destroyed. Empty sockets never ask, and the question can be turned off in the Socket Bar section. Answering yes only sockets if the same gem is still sitting there.
- New: The tooltip on a socketed gem now says that clicking replaces it.
- Fixed: The speed trinket is taken off again. Putting it away only tried your backpack; if that was full, the trinket slid back into the slot and stayed on for good. A free bag slot is now picked deliberately, with profession bags skipped, and a failed attempt is retried instead of dropped.
- Fixed: The trinket also comes off after logging out mounted and logging in on foot, and when the gear set module is switched off.

## 1.9.0 — 2026-08-03

- New: A socket bar under the sidebar shows every socket on your equipped gear in one strip. Clicking an empty socket opens a picker with the gems from your bags; clicking a gem sets it. Empty sockets are framed in red, which can be turned off separately. The bar only appears when your gear has sockets.
- Fixed: The sidebar buttons follow the window style again. Equip, Save and New Set kept Blizzard's artwork even in the Modern style; they now go through the addon's own button.
- Fixed: Every other button kept Blizzard's artwork in Modern as well. A button's own textures are now collected when it is built, however they hang off it.
- Fixed: In the Modern style a greyed-out Equip no longer looks clickable.
- Improved: Less work during a fight: `UNIT_AURA` is only subscribed while the speed trinket option is on.
- Improved: The window style list starts with Classic, which is the default.

## 1.8.0 — 2026-08-02

- New: Equip a speed trinket when mounting. The Riding Crop (or Carrot on a Stick) moves from your bags into a trinket slot when you mount and goes back when you dismount, together with the trinket it displaced. Druids in flight form get the Charm of Swift Flight instead. Off by default, out of combat only; a swap that falls into combat waits until combat ends.
- New: Switching between mount and flight form swaps only the trinket itself. If nothing suitable is in your bags, the previous trinket is put back.
- New: The remembered state survives a reload, so a speed trinket never gets stuck in your trinket slot.
- Improved: The sidebar makes room for a stats column: if another addon attaches one to the right of the character window, the sidebar sits outside it and follows it being collapsed or expanded. Adjustable with `/gearset tune stats <n>`.
- Improved: The sidebar is wide enough for a full row of item icons. In the Classic style the last icon of every row no longer wraps onto the next line.

## 1.7.1 — 2026-08-01

- Changed: Classic is now the default window style. Fresh installs start with Blizzard's dialog frame look; a style you already picked is left untouched.
- Fixed: The icon picker window got a close button, and long set names in its title are truncated instead of running underneath it.

## 1.7.0 — 2026-08-01

- New: Over 200 new set icons. The icon picker (right-click a set → Change icon) offers a large icon collection on top of the set's own item icons and the role symbols, with a scroll area: eight columns, mouse wheel and a thin bar.
- New: Equipping can swap worn items between slots. If a set's ring or trinket is already on your character but in the other slot, Equip moves it over instead of reporting it missing. Works for weapons too.
- Improved: Status dots count copies, not item IDs. A set holding two identical rings or trinkets showed "equipped" as soon as one was worn; now each piece needs its own copy.
- Improved: The green dot means every piece sits in its intended slot. Crossed pairs show as ready, matching what Equip will do.
- Improved: Bank detection is more precise: bag copies no longer count as bank copies.
- Improved: The sidebar status refresh is batched: equipping a full set updates the list once instead of once per swapped item.
- Improved: The settings window reuses its widgets instead of rebuilding them on each change.
- Improved: Event handlers are cleanly unregistered when the module is disabled, and translations are cached after the first lookup.
- Fixed: Sidebar and minimap button reappear right away when the module is re-enabled, instead of staying hidden until a reload.
- Fixed: Renaming an expanded set keeps it expanded.

## 1.6.2 — 2026-07-30

- New: Gear sets can be renamed: right-click a set in the sidebar and pick Rename. The dialog is pre-filled with the current name, and the set keeps its gear, custom icon, and its spec and stance/form bindings.

## 1.6.1 — 2026-07-29

- Fixed: Classic style: the expanded item grid no longer loses its last column. The grid fits its column count to the actual row width.

## 1.6.0 — 2026-07-29

- New: The sidebar set list scrolls with the mouse wheel. A thin bar on the right appears only when there is something to scroll.
- New: Quick-save groups for rings and armor, next to trinkets and weapons in the minimap menu and the settings.
- Fixed: Equipping compares item IDs instead of item links. An enchanted or gemmed piece was reported as "missing from bags" even while worn.
- Fixed: Logging in no longer auto-equips the spec-bound set; the login itself looked like a spec change.
- Fixed: The expanded item view under a set closes reliably again.
- Fixed: The popup menu closes when you click somewhere else.
- Fixed: Settings window: the Slot Picker section can collapse, the set list updates right after deleting or saving a set, the third quick-save button is no longer cut off, and sliders show the value they are set to.
- Fixed: Disabling a module hides its open windows instead of leaving them behind.
- Fixed: The slot picker window is titled with the proper, translated slot name ("Off Hand" instead of the internal frame name).

## 1.5.0 — 2026-07-29

- New: Support for Classic Era and Season of Discovery (interface 11509). The addon ships a second TOC for that client; everything else is shared.
- Improved: Dual spec settings only appear where dual spec exists. On Classic Era they are hidden, and the two-second spec poll no longer runs there.

## 1.4.1 — 2026-07-29

- Fixed: An ADDON_ACTION_BLOCKED error on login. Keyboard input is now only enabled in edit mode, edit mode refuses to start in combat, and it ends by itself when combat begins.

## 1.4.0 — 2026-07-29

- New: Status marker next to each gear set: green when the set is fully worn, orange when parts are in the bank, red when a part cannot be found. The tooltip lists which parts are where. "Not found" means "not on this character": the client cannot tell a sold item from one on an alt or in the mail.
- New: `/gearset tune left <n>` and `tune show` for the sidebar edges.
- Fixed: The marker updates right after equipping instead of showing the state from before the change.
- Fixed: The compact slot picker opened to the right every time instead of only when the preferred side had no room.

## 1.3.1 — 2026-07-29

- Fixed: A custom icon no longer disappears when you update a set. Saving over a set dropped everything that was not gear data, including the icon and the creation date.
- Fixed: The compact slot picker flips to the other side when the character window sits at the edge of the screen.

## 1.3.0 — 2026-07-28

- Changed: The sidebar only shows on the Character tab and comes back when you switch to it again.

## 1.2.1 — 2026-07-28

- Improved: Classic style polish: the sidebar lines up with the visible edge of the character window, and rows, buttons, popup titles and item icons follow the wider frame. New `/gearset tune left <n>` and `tune show`.
- Improved: Sidebar buttons stretch to the available width in both styles, and the selection bar on a set is inset and less intense in Classic.
- Improved: Hovering an equipment slot reacts faster: 0.10 s instead of 0.25 s.

## 1.2.0 — 2026-07-28

- New: Window style option. Modern keeps the dark look with the purple accent; Classic switches every window to Blizzard's dialog frame. Buttons follow the style. It can be changed at any time without a reload.
- Changed: Dropdowns use an arrow icon instead of a typed letter, and it follows the style.

## 1.1.0 — 2026-07-28

- New: Discord button in the settings window. It opens a dialog with the invite link preselected, ready to copy with Ctrl+C.
- New: The settings window has a footer showing the addon version.

## 1.0.1 — 2026-07-28

- Fixed: Interface version raised to 20506 (game version 2.5.6). The addon was flagged as out of date on current Anniversary clients.

## 1.0.0 — 2026-07-28

First release. Split out of the equipment set module of VuloClassicUI and rebuilt as a standalone addon.

- Gear sets: save, equip, overwrite and delete sets, your full equipment or just trinkets, weapons, rings or armor.
- Gear sets: Sidebar on the character frame with a custom icon per set, per-slot replacement and a context menu; freely movable via `/gearset unlock`.
- Gear sets: Minimap button with the set switcher on left-click and the settings on right-click.
- Gear sets: Automatic switching on stance and form as well as on dual spec.
- Gear sets: Swapping is refused during combat and carried out once the fight ends.
- Slot picker: Hovering an equipment slot shows the matching items from your bags next to it; a click equips one. Nothing appears when there is nothing to swap.
- Slot picker: The configured click opens the full window with all items, a counter and a movable title bar.
- Vs. VuloClassicUI: Runs on its own, no other addons required, with its own settings window.
- Vs. VuloClassicUI: Sets are stored per character; the account-wide pool of older versions is gone. Existing sets are imported automatically on first login per character.
- Vs. VuloClassicUI: Neither addon disables the other; running both just prints a notice.
- Vs. VuloClassicUI: `/gearset unlock` replaces the UnlockMode module, `/gearset config` opens the settings.
- Known issues: The Anniversary client does not load font files from addon folders, so the bundled Expressway is unused for now and Arial Narrow from the client is used instead. Details via `/vgsfont`.
