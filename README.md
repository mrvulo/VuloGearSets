# VuloGearSets

Equipment set manager for WoW TBC Classic Anniversary (Interface 20506).

Save your current equipment as named gear sets and switch between them with a single
click. Runs on its own, no other addons required.

## Features

- **Save and equip sets** — the whole outfit or just parts of it: trinkets, weapons,
  rings, armour
- **Sidebar on the character frame** with a custom icon per set, per-slot replacement
  and a context menu
- **Minimap button** — left-click for the set switcher, right-click for the settings,
  drag to reposition
- **Slot picker** — hover an equipment slot and the matching items from your bags
  appear right next to it; click one to equip. A configurable click opens the full
  window with all of them.
- **Automatic switching** on stance and form (warrior stances, druid forms) and on
  dual spec
- **Combat lock** — nothing is swapped during combat; a switch triggered mid-fight is
  carried out as soon as combat ends
- English and German

## Slash commands

| Command | Effect |
|---|---|
| `/gearset save <name>` | save your current equipment as a set |
| `/gearset equip <name>` | equip a set |
| `/gearset delete <name>` | delete a set |
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
| `VuloGearSetsCharDB` | per character: sets, spec and form bindings, sidebar position |

Sets are stored per character because they reference that character's equipment.

## Known limitation: font

The addon ships Expressway, the same font VuloClassicUI uses. The Anniversary client,
however, does not load font files from addon folders — this affects not just this
addon but equally the same file shipped by Details or VuloClassicUI (measured text
width of 0 in every case). Arial Narrow from the client is used instead, which has a
similarly narrow cut. If a client does accept Expressway, it is picked up
automatically.

`/vgsfont` shows which font is active and what the measurement returns.

## Contributing

Project layout, tooling, translations and the release process are documented in
[CONTRIBUTING.md](CONTRIBUTING.md) (in German).

## License

MIT — see [LICENSE](LICENSE).
