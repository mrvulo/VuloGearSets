# Changelog

## 1.15.0

- **New: back to your previous gear.** Every set switch remembers what the
  affected slots held before. "Back to previous gear" puts it back on — from
  the minimap menu, from its own key in Blizzard's key bindings (under
  VuloGearSets) or with `/gearset back`. Press it again to switch forward.
- **New: put a set in the bank.** With the bank open, right-click a set and
  choose "Put in bank": the set's pieces in your bags move into free bank
  slots. What you are wearing stays on. Also as `/gearset bank <name>`.
- **New: place a set on your action bar.** Right-click a set and choose
  "Place on action bar". On Forever you get Blizzard's copy of the set,
  otherwise a macro with the set's icon. Renaming, deleting or changing the
  icon keeps the macro in step; a macro you rewrote yourself is left alone.
- **New on Forever: sets are also kept in Blizzard's equipment manager** as
  soon as you save or fully wear them, so they are stored on the server and
  other addons and bag windows see which items belong to them. Renaming,
  deleting and icon changes follow along; Blizzard sets that are not ours
  stay untouched. Switch: "Also keep sets in Blizzard's equipment manager",
  on by default. Item tooltips no longer list a set twice when Blizzard's own
  line already names it.
- The addon's own texts — menus, buttons, the settings window — now use the
  Expressway font. It was bundled all along but never picked up.
- The automatic set icon is now always the one of the first item in slot
  order instead of a random one, and set names are trimmed at the edges when
  saving, like when renaming.
- **Fixed:** Blizzard's icon picker for a new set in the equipment manager
  opened underneath the gear sets sidebar.
- After updating, restart the game once: this version brings new files,
  which a `/reload` does not load.

## 1.14.0

- **New: World of Warcraft: Forever support.** The addon now loads on the
  Forever client and does everything it does on Anniversary: saving and
  equipping sets, binding sets to your two talent groups, stance and form
  switching, equipping from the bank's tabs while the bank is open, the slot
  picker, the socket bar and the set line in item tooltips. The sidebar sits
  next to the character window's side tabs.
- **New: "Forever" window style**, the default on Forever. It takes the look
  of VuloForeverUI — its colors and, with its Blizzard themes, the client's
  metal frame. The sidebar then wears the background and border of Blizzard's
  own equipment manager, with Blizzard's "New Set" button.
- The "New Set" button has a new look on every client: a dark card with a thin
  gold border, a green plus and green text.
- **Fixed: stance and form names on Anniversary and Classic Era.** The form
  list only showed "Form 1/2/3", and flight form was never recognized, so
  druids never got the Charm of Swift Flight equipped in flight form. Forms
  now show their real names.

## 1.13.0

- **New: slots that were empty when a set was saved are now emptied when you
  equip it.** A set saved wearing only a few pieces — say, nothing but
  no-durability jewelry for a graveyard run — used to answer "already
  equipped" and leave your armor on. Equipping now takes off whatever sits in
  those slots and puts it in your bags, with its own chat line ("%d items
  taken off") and a warning when your bags have no room (those pieces stay
  on). Even a set with no items at all works now.
- The status dot counts those extra worn pieces too: a set only turns green
  once its empty slots really are empty.
- This reads a set the way it was saved: removing an item from a set in the
  editor now means "this slot should be empty" rather than "leave this slot
  alone". Old sets from before masks existed only know their occupied slots
  and behave as before.

## 1.12.2

- **Fixed: two copies of the same item with different gems or enchants now
  actually swap.** Two pieces sharing one item ID — say, the same shoulders
  socketed once for damage and once for resistance — counted as the same
  item, so switching sets left the worn copy in place. Sets now tell the
  exact copy apart by its gems, enchant and random suffix, and equipping
  swaps in the one the set was saved with.
- The sidebar status dot uses the same logic, so it agrees with the equip
  button — including a hint when the right copy is sitting in the closed
  bank.
- If a saved copy can no longer be found anywhere — for example after
  re-gemming it — the set falls back to matching by item ID as before, so
  nothing is wrongly reported as missing.

## 1.12.1

- **A set can now show or hide your helmet and cloak.** Right-click a set in
  the sidebar: the Helmet and Cloak entries cycle between leave as is, show
  and hide. When the set is equipped — by double-click, key, spec or form
  switch, or the quick-switcher — it applies that choice, even if no item had
  to move.
- The default is leave as is, so existing sets behave exactly as before. The
  set tooltip only mentions the setting when the set actually changes
  something.

## 1.12.0

- **New: gear sets can be put in your own order.** Right-click a set in the
  sidebar for Move up and Move down, or simply drag it: a shadow of the row
  follows the pointer, a coloured line marks where it will land, and the list
  scrolls on its own when you reach the top or bottom edge. Letting go saves
  the order.
- The order is kept per character and applies everywhere sets are listed —
  the sidebar, the quick-switcher menu, the settings page and the Sets line in
  item tooltips.
- Until you move something, the list stays alphabetical as before. Once you
  have, new sets join at the bottom.

## 1.11.1

- **Fixed: a set that is already on stops repeating itself in chat.** Clicking an
  equipped set again, or pressing its key a second time, said the same sentence
  every single time. The outcome of an attempt that moved nothing is now
  remembered and reported once.
- What is remembered is the whole outcome, not just the name — so if a missing
  piece turns up in your bags in the meantime, the line is news again and comes
  back. The refusal during combat works the same way, which a key makes very easy
  to trigger three times in a row. Anything reporting a real swap always comes
  through.

## 1.11.0

- **New: a gear set can sit on a key.** Right-click a set, pick Set key, and the
  next key you press belongs to it. Pressing it equips the set exactly like a
  double-click on the row, wherever you are — the character window does not have
  to be open. Modifiers count, so Shift-1 and Alt-F are separate keys, and the
  middle mouse button along with mouse 4 and 5 can be used as well.
- The row tooltip names the key, and the right-click menu grows an entry to take
  it away again. A key belongs to exactly one set: hand it to another one and the
  previous owner loses it and is told so. Renaming a set carries its key along,
  deleting the set drops it, and the whole assignment lives per character, just
  like the sets themselves.
- Blizzard's own key bindings are never rewritten and nothing is left behind when
  the addon is off. The other side of that: while the addon runs, the key takes
  precedence over whatever else uses it, and it does not show up in Blizzard's
  key binding list. Keys cannot be changed during combat — a change made there is
  applied the moment combat ends.
- **Changed: the item list for the weapon slots opens downward.** The three
  weapon slots sit as a row under the character model, so a list opening sideways
  had nothing to cover but the neighbouring weapons. It now unfolds below the
  slot and only flips up when there is genuinely no room.

## 1.10.0

- **New: item tooltips name the gear sets an item belongs to.** Hover anything in
  your bags, at the bank, on your character or a link in chat, and a line at the
  bottom lists the sets it is part of. It can be turned off under Gear Sets.
- Items are matched by their item ID plus random suffix, so an enchant or a gem
  never hides the line, while a Ring of the Bear and a Ring of the Owl stay
  apart — in Classic those two share one ID.
- **New: gear sets equip from the bank.** With the bank window open, the parts of
  a set sitting in your bank go on together with the rest. Your bags are still
  searched first, so a copy there keeps priority. The piece you were wearing goes
  into the bank slot the new one came from, exactly as if you had dragged it
  across yourself.
- With the bank closed, items waiting there are no longer counted as missing.
  They get their own line telling you to open the bank window, and a set that is
  only short of bank items no longer claims it is already equipped.

## 1.9.1

- **Fixed: the speed trinket is taken off again.** Putting it away only ever
  tried your backpack. If that was full, nothing said so and the trinket slid
  quietly back into the slot — the Riding Crop went on when you mounted and then
  stayed on for good. A free bag slot is now picked deliberately, with
  profession bags skipped.
- What made a single hiccup permanent: the remembered state was cleared before
  anything had actually happened, so once it was gone nothing ever touched the
  trinket again. It is cleared only after the trinket has really left the slot,
  and a failed attempt is retried instead of dropped.
- The trinket also comes back off after logging out mounted and logging in on
  foot, and when the gear set module itself is switched off. Both cases used to
  leave it sitting in your trinket slot.
- **New: a socket that already holds a gem asks before it is overwritten.** The
  old gem is destroyed when a new one goes in, so a misclick in the gem picker
  costs you a gem. Empty sockets never ask, and the question can be turned off
  in the Socket Bar section.
- Answering yes only sockets if the same gem is still sitting there — swap your
  gear while the question is open and nothing happens.
- The tooltip on a socketed gem now says that clicking replaces it. That this
  was possible at all was invisible before.

## 1.9.0

- **New: a socket bar under the sidebar.** It shows every socket on your
  equipped gear in one strip. Clicking an empty socket opens a picker with the
  gems from your bags, and clicking a gem sets it — no hunting through the bags
  and no socketing window to operate. Empty sockets are framed in red so they
  are easy to spot, which can be turned off separately. The bar only appears
  when your gear actually has sockets, and it steps back while VuloClassicUI
  shows the same strip, so you never get two of them.
- **The sidebar buttons follow the window style again.** Equip, Save and New Set
  were built straight from Blizzard's template and kept its artwork even in the
  Modern style. They go through the addon's own button now.
- Every other button kept Blizzard's artwork in Modern as well: hiding it only
  asked for the normal texture and its siblings, but on this client the
  three-part artwork hangs off the button as child textures. A button's own
  textures are now collected when it is built, whichever way they hang.
- In the Modern style the label carries the disabled state that Blizzard's
  artwork used to show, so a greyed-out Equip no longer looks clickable.
- The window style list starts with Classic, which is the default.
- **Less work during a fight.** `UNIT_AURA` is only subscribed while the speed
  trinket option is on. It fires for every unit nearby and used to run in every
  fight for a feature that is off by default.

## 1.8.0

- **New switch: equip a speed trinket when mounting.** The Riding Crop (or
  Carrot on a Stick) moves from your bags into a trinket slot when you mount up
  and goes back when you dismount, together with the trinket it displaced.
  Druids in flight form get the Charm of Swift Flight instead — the riding crop
  only affects mount speed and does nothing in flight form. A free trinket slot
  is preferred; otherwise the lower one is used. Off by default, out of combat
  only, and a swap that falls into combat is deferred until combat ends.
- Switching between mount and flight form swaps only the trinket itself — the
  slot and the displaced item stay put. If nothing suitable is in your bags, the
  previous one is put back instead of sitting there uselessly.
- The remembered state survives a reload, so a speed trinket never gets stuck in
  your trinket slot.
- **The sidebar makes room for a stats column.** If another addon attaches its
  own stats column to the right of the character window, the sidebar now sits
  outside it instead of on top of it, and follows that column being collapsed or
  expanded straight away. Without such an addon nothing changes. The gap can be
  adjusted with `/gearset tune stats <n>`.
- **The sidebar is wide enough for a full row of item icons.** Its width now
  follows the icon grid of an expanded set. In the Classic style the frame is
  wider, and the last icon of every row used to wrap onto the next line.

## 1.7.1

- **Classic is now the default window style.** Fresh installs start with
  Blizzard's dialog frame look; a style you already picked is left untouched.
- The icon picker window got a close button. Long set names in its title are
  truncated instead of running underneath it.

## 1.7.0

- **Over 200 new set icons.** The icon picker (right-click a set → Change icon)
  now offers a large hand-drawn icon collection on top of the set's own item
  icons and the role symbols. The picker got a scroll area for it: eight columns,
  mouse wheel, and a thin bar on the right.
- **Equipping can now swap worn items between slots.** If a set's ring or
  trinket is already on your character but sitting in the other slot, Equip
  moves it over instead of reporting it missing — crossed pairs are sorted out
  in one go. Works for weapons too; an item displaced from its slot goes back
  to the other slot or into your bags.
- **Status dots count copies, not item IDs.** A set holding two identical rings
  or trinkets used to show "equipped" as soon as one copy was worn; now each
  piece needs its own copy, so "ready" and "missing" are reported correctly.
- The green dot now means every piece sits in its intended slot. Crossed pairs
  show as ready instead — matching what the Equip button will actually do.
- The bank detection is more precise: bag copies no longer count as bank copies.
- Sidebar and minimap button reappear right away when the module is re-enabled,
  instead of staying hidden until a reload.
- The settings window reuses its widgets instead of rebuilding everything on
  each change — repeated saving, deleting, or style switching no longer piles
  up discarded frames.
- The sidebar status refresh is batched: equipping a full set updates the list
  once instead of once per swapped item.
- Renaming an expanded set keeps it expanded.
- Event handlers are cleanly unregistered when the module is disabled, and
  translations are cached after the first lookup.

## 1.6.2

- Gear sets can be **renamed**: right-click a set in the sidebar and pick
  Rename. The dialog comes pre-filled with the current name, and the set keeps
  everything — gear, custom icon, and its spec and stance/form bindings.

## 1.6.1

- Classic style: the expanded item grid no longer loses its last column. The new
  scroll area clips at the frame edge, and with Blizzard's wider dialog border the
  sidebar list is narrower than six fixed columns — the grid now fits its column
  count to the actual row width.

## 1.6.0

- The sidebar set list **scrolls**. Rows used to run past the frame and under the
  New Set button once you had about nine sets. The list now scrolls with the mouse
  wheel; a thin bar on the right appears only when there is something to scroll.
- New quick-save groups: **rings** and **armor**, next to trinkets and weapons in
  the minimap menu and the settings.
- Equipping compares **item IDs** instead of item links. An enchanted or gemmed
  piece changes its link but stays the same item — it used to be reported as
  "missing from bags" even while you were wearing it.
- Logging in no longer auto-equips the spec-bound set. The comparison baseline was
  set two seconds too late, so the login itself looked like a spec change.
- The expanded item view under a set closes reliably again. Whether collapsing
  worked depended on which set you had expanded first.
- The popup menu closes when you click somewhere else.
- Settings window fixes: the Slot Picker section can actually collapse, the gear
  set list updates right after deleting or saving a set, the third quick-save
  button is no longer cut off at the edge, and sliders show the value they are
  actually set to.
- Disabling a module now hides its open windows instead of leaving them behind.
- The slot picker window is titled with the proper slot name ("Off Hand" instead
  of the internal frame name) and translated.

- Support for **Classic Era and Season of Discovery** (interface 11509). The addon
  now ships a second TOC for that client; everything else is shared.
- Dual spec settings only appear where dual spec exists. On Classic Era they are
  hidden, and the two-second poll that watched for spec changes no longer runs
  there at all.

## 1.4.1

- Fixed an ADDON_ACTION_BLOCKED error on login. The sidebar mover enabled keyboard
  input permanently and called the protected `SetPropagateKeyboardInput`, which
  Blizzard blocks while in combat. Keyboard input is now only enabled in edit mode,
  edit mode refuses to start in combat, and it ends by itself when combat begins.

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
