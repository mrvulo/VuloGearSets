# VuloGearSets

Equipment set manager for WoW TBC Classic Anniversary (interface 20506),
Classic Era / Season of Discovery (interface 11509) and now also
**World of Warcraft: Forever** (interface 16001).

Save your current equipment as named gear sets and switch between them with a single
click. Runs on its own, no other addons required.

## Features

- **Save and equip sets** — the whole outfit or just parts of it: trinkets, weapons,
  rings, armor
- **Sidebar on the character frame** with a custom icon per set, per-slot replacement
  and a context menu
- **Minimap button** — left-click for the set switcher, right-click for the settings,
  drag to reposition
- **Slot picker** — hover an equipment slot and the matching items from your bags
  appear right next to it; click one to equip. A configurable click opens the full
  window with all of them.
- **Action bar buttons** — right-click a set and choose "Place on action bar"; the set
  lands on your cursor as a macro (on Forever as Blizzard's own equipment set)
- **Back to previous gear** — one click, key or `/gearset back` puts back whatever
  the last set switch replaced; press it again to switch forward
- **Put a set in the bank** — with the bank open, right-click a set and choose "Put in
  bank" to move its pieces from your bags into free bank slots
- **Automatic switching** on stance and form (warrior stances, druid forms) and on
  dual spec
- **World of Warcraft: Forever** — everything above works on the Forever client too.
  The sidebar there takes the look of Blizzard's own equipment manager, and your sets
  are also kept in the character window's equipment manager as soon as you save or
  fully wear them, so they are stored on the server and other addons and bag windows
  see which items belong to them
- **Combat lock** — nothing is swapped during combat; a switch triggered mid-fight is
  carried out as soon as combat ends
- English, German, French, Spanish, Russian and Simplified Chinese

## Slash commands

| Command | Effect |
|---|---|
| `/gearset save <name>` | save your current equipment as a set |
| `/gearset equip <name>` | equip a set |
| `/gearset delete <name>` | delete a set |
| `/gearset back` | switch back to the gear you wore before the last set switch |
| `/gearset bank <name>` | put the set's pieces from your bags into the bank (bank must be open) |
| `/gearset list` | list your saved sets |
| `/gearset spec` | view and set spec bindings |
| `/gearset config` | open the settings |
| `/gearset unlock` | make the sidebar movable |
| `/gearset tune top\|bottom\|left <n>` | fine-tune the sidebar edges (`show`, `reset`) |
| `/vgs` | short form of `/gearset` |
| `/rl` | reload the interface (not in combat) |
| `/vgsfont` | font diagnostics |

Typing `/gearset <name>` equips that set directly.

## Coming from VuloClassicUI?

VuloGearSets started out as the equipment set module of VuloClassicUI and now runs
completely independently of it.

If VuloClassicUI is installed, VuloGearSets imports its saved sets — including spec
and form bindings — the **first time you log in on a character**. VuloClassicUI's data
is only read and stays untouched.

Neither addon disables the other. If you run both with their set modules active you
will inevitably get two minimap buttons and two sidebars; VuloGearSets points this out
once per session in chat. If it bothers you, disable one of them.

> **Mind the order:** if you remove VuloClassicUI **before** starting VuloGearSets for
> the first time, there is no saved data left to read — the import finds nothing. So
> start VuloGearSets once, then remove VuloClassicUI.

## Saved variables

| SavedVariable | Contents |
|---|---|
| `VuloGearSetsDB` | account-wide: display options, minimap button, slot picker |
| `VuloGearSetsCharDB` | per character: sets, spec and form bindings, keybinds, sidebar position, which sets are mirrored into Blizzard's equipment manager |

Sets are stored per character because they reference that character's equipment.

## Font

The addon ships Expressway, the same font VuloClassicUI and VuloForeverUI use, and sets
it directly on all its own texts. `/vgsfont` shows the path in use and measures whether
the client renders it.

## Contributing

Project layout, tooling, translations and the release process are documented in
[CONTRIBUTING.md](CONTRIBUTING.md) (in German).

## License

MIT — see [LICENSE](LICENSE).
