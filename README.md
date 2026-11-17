# Crossroads: Player Memory

<img src="assets/project-icon.png" alt="Crossroads journal and signpost emblem" width="240" />

**Remember the people. Relive the adventures.**

A local player-history journal for **World of Warcraft: Forever**, by **MrKawashima**. Version **0.2.3-alpha**, targeting **Interface 16001 / Forever 1.60.1**.

> **Experimental Alpha — this new build has not been tested in the real WoW Forever client.** Source review and offline Lua 5.1 simulations passed. These checks do not prove client compatibility, event availability, UI layout, or persistence. Treat records as incomplete observations, not authoritative evidence about other players.

## Features

- Player profiles with first and latest encounters, observed character details and a searchable timeline.
- Party history, approximate time together, and your quest acceptances and turn-ins while grouped.
- Dungeon and raid visits, roster snapshots and boss events when available.
- Experimental PvP attacker history from accessible death recap data and GUID-matched kill credit.
- Need/Greed/Pass and loot winners when exposed by the game's loot history.
- Trade-window offers and acceptance snapshots, with an explicitly unverified outcome.
- Whisper interaction counts without saving message contents; optional party chat counts.
- Private notes, 0–5 ratings, personal labels and recognized-rival alerts.
- A round, movable minimap button: left-click to open, right-click for settings, left-drag to move.

## Installation

1. Download **Crossroads-Player-Memory-Forever-0.2.3-alpha.zip** from Releases.
2. Extract the **CrossroadsPlayerMemory** folder into your Forever client's **Interface/AddOns** directory, usually `World of Warcraft/_forever_/Interface/AddOns`.
3. Check that `Interface/AddOns/CrossroadsPlayerMemory/CrossroadsPlayerMemory.toc` exists.
4. Enable **Crossroads: Player Memory (alpha)** in the AddOns list.
5. Click the book icon on the minimap or enter **/crmemory**.

This is independent of the unrelated CurseForge addon named **Crossroads**. Its files, repository and project are not used or modified. This release uses a distinct installation folder, SavedVariables name and global UI names. `/cr` and `/crossroads` are convenience aliases only when an addon named `Crossroads` is not installed; `/crmemory` always identifies this addon.

### Earlier private prototypes

The public release uses `CrossroadsPlayerMemoryDB` in `CrossroadsPlayerMemory.lua`. It does not automatically import `CrossroadsDB`, because that name may belong to the unrelated addon. Existing prototype data is left untouched. No migration has been tested; back up any prototype SavedVariables before changing installations. Do not remove an unrelated `Crossroads` installation.

## Journal layout and deletion

The header shows time together in hours and minutes. **History**, **Profile** and **Statistics** have separate tabs.

**History** shows date headings and single-line rows with time, event and location. Click an event for details and the **Delete entry** action. A category menu and text search narrow the list. Profile edits are hidden by default; select **Personal** or enable **Show profile edits** in the category menu to include them.

**Profile** contains rating and tag menus, private notes, **Clear history** and **Delete player**. Unsaved note drafts survive switching players during the UI session; click **Save note** to persist them. **Statistics** contains the remaining counters.

- **Delete entry** in the event details removes that entry after confirmation.
- **Clear history** removes all timeline entries for the selected player, including filtered-out entries.
- Both actions leave aggregate statistics, current notes/labels and trade snapshots unchanged: the bounded timeline cannot reconstruct lifetime totals.
- **Delete player** removes the full profile, notes, labels, totals, trade snapshots, activity references and references in saved instance rosters. Other players and shared runs are retained.
- These actions cannot be undone. A deleted player is not automatically recreated until the next login/reload. `/crmemory add First Surname` adds them again sooner. This is not a permanent ignore list.

Upgrade from the public 0.2.1 build by replacing the **CrossroadsPlayerMemory** addon folder. Keep its SavedVariables file; existing profiles are upgraded automatically.

## Commands

| Command | Action |
| --- | --- |
| `/crmemory` | Open or close the journal |
| `/crmemory options` | Tracking and privacy settings |
| `/crmemory minimap show`, `hide`, `reset` | Control the minimap launcher |
| `/crmemory target` | Open a profile for the selected player |
| `/crmemory add First Surname` | Add a player |
| `/crmemory find First Surname` | Find an existing player |
| `/crmemory note First Surname ; text` | Save a private note |
| `/crmemory rate First Surname ; 5` | Set a rating from 0 to 5 |
| `/crmemory tag First Surname ; Friend` | Add a personal label; `untag` removes it |
| `/crmemory kill First Surname` | Record an explicitly manual kill report |
| `/crmemory death First Surname` | Record an explicitly manual death report |
| `/crmemory ninja First Surname` | Apply a subjective personal label |
| `/crmemory stats`, `help` | Show totals or command help |

Use `target` instead of a name for notes, ratings, tags and manual PvP reports.

## Privacy and interpretation

The addon stores its records locally in WoW SavedVariables. It contains no outbound addon messaging, telemetry or external upload. Whisper and party-chat bodies are not retained. Labels are personal assessments, not verified accusations. Need rolls never automatically assign a negative label. The addon does not attack, target, whisper, trade, report or retaliate automatically.

Quest records describe **your** actions while grouped; they do not prove a teammate completed the quest. A dungeon visit is not a verified clear. Both players accepting a trade does not prove a completed transfer. A PvP `confirmed` label describes the readable event evidence used by the algorithm, not independent validation of this Alpha's behavior.

## Known limitations

- This new interface has not been tested in the real client. API payloads, restricted/secret data, and missing events may cause incomplete records. Unavailable event registrations are reported in chat rather than aborting startup.
- Death recap fields and kill credit remain experimental. Pets, hidden identities and unavailable recap data can prevent attribution. Duplicate death events are suppressed until revival.
- Names are account-wide keys. Ambiguous first names are not merged; identical full names across rulesets and renamed characters are not fully reconciled.
- Group time is approximate. A reload or logout interrupts an instance visit.
- Storage retains 100 timeline entries per player, 1,500 activity references, 150 visits and 30 trade snapshots per player. The total profile count is not capped.
- The UI shows at most 300 matching profiles. Search to narrow the list. Visual layout is not yet verified in game.
- Persistence depends on the client correctly loading/writing SavedVariables. Earlier Forever beta builds had reported persistence failures; current behavior is unverified here. Crashes can lose recent data.

## Validation and feedback

See [QA.md](QA.md) for the exact test scope, remaining in-game checks and API references. Report reproducible problems through [GitHub Issues](https://github.com/MrKawashima/Crossroads-Player-Memory/issues), including the client build and Lua error, but exclude private notes, whisper contents and account details.

Offline tests require Python and `lupa` (Lua 5.1): `python tests/test_crossroads.py` from the repository root. They are not required to install the addon.

## License

Copyright 2026 MrKawashima. All rights reserved. No open-source redistribution license is granted by this Alpha release. WoW textures referenced by the addon are supplied by the game and are not included in this package.
