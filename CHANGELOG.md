# Crossroads: Player Memory — 0.2.1-alpha

Initial public Alpha for World of Warcraft: Forever (Interface 16001).

**This release has not been tested in the real game client.** Validation is limited to source review and offline Lua 5.1 simulations. Features may be incomplete or behave differently in game.

## Included

- Player profiles, searchable timelines, private notes, ratings and personal tags.
- Group time, your grouped quest activity, instance visits and boss observations.
- Experimental PvP, game-exposed loot history, trade attempts and whisper counts.
- Round, draggable minimap launcher and tracking options.

## Pre-publication fixes

- Corrected the loot-history field to `lootListID` and verified duplicate protection.
- Guarded unavailable event registration and inaccessible API values.
- Suppressed duplicate death events until revival; zero overkill alone no longer proves a killing blow.
- Removed trade attribution based solely on the current target.
- Improved group-setting transitions and instance-exit checks.
- Isolated the folder, SavedVariables, UI globals and primary commands as `CrossroadsPlayerMemory` / `/crmemory` to avoid overwriting the unrelated Crossroads addon.

## Limitations

Real-client compatibility, UI layout and persistence remain unverified. Loot/PvP coverage depends on readable game data. Grouped quests do not prove teammates completed them; instance visits do not prove clears; trade records do not prove successful transfers. Earlier private prototype data is not automatically imported into the new storage namespace. See README and QA for details.
