# Crossroads: Player Memory 0.2.6 Alpha

## Notes editor input fix

- Explicitly enable mouse and keyboard input for the private notes editor.
- Clicking the editor or blank space in its scroll area focuses the text field.
- Keep a usable empty editing area and scroll to follow the cursor in longer notes.
- Release keyboard focus when switching profiles, hiding the editor, pressing Escape or saving.
- Existing notes, drafts and other player data are preserved.

Offline Lua 5.1 tests pass for input configuration, click-to-focus, simulated typing, save, draft retention, multiline text, cursor scrolling and focus release, alongside all existing regressions.

**The reported client issue has not yet been reproduced or verified fixed in the real WoW Forever client.** This addresses the missing mouse/input setup found during source review. Experimental Alpha targeting Forever 1.60.1 / Interface 16001.

---

# Crossroads: Player Memory 0.2.5 Alpha

## Player list sorting

- Sort players by Last seen, Name, Time together, Group sessions or Rating.
- Choose ascending or descending order using the adjacent Asc / Desc button.
- Name defaults to A–Z; other fields default to highest/newest first when selected.
- Sorting works with search and player filters. Equal values use alphabetical names for a stable order.
- The secondary line shows the relevant value for last seen, group sessions or rating.
- Your chosen field and direction are saved between sessions. Existing player data and tracking preferences are preserved.

Offline Lua 5.1 regression tests pass for all five fields, both directions, ties, missing values, combined search/filters, selection retention and persisted preferences, alongside the existing tracker, trip and deletion tests.

**This update has not been verified in the real WoW Forever client.** Experimental Alpha targeting Forever 1.60.1 / Interface 16001.

---

# Crossroads: Player Memory 0.2.4 Alpha

## Group trips in your timeline

- New group activity is collected into a single trip per player, with time together, party participants, locations and activity counts.
- Open a trip for the recorded quest, dungeon, loot, trade and other activity details.
- Whispers with a current party member are counted in the trip instead of creating separate rows. Message contents are never saved.
- Joining, leaving and rejoining the same ongoing party updates each player's own accumulated time. A trip ends when no tracked companions remain. Reload/login starts a separate trip; offline time is not counted.
- Search and category filters also find activities inside trips. Removing a trip removes its stored activity details for that player, while lifetime statistics remain unchanged.
- Older history stays intact; the addon does not guess missing historical party boundaries.

## Defaults

New installations enable group time, quests, instances, PvP, loot, trade attempts, whisper counts, rival alerts, tooltips and the minimap button. Target-based encounter recording and party-chat counts are disabled. Existing saved preferences are preserved.

## Validation and limits

Offline Lua 5.1 regressions pass, including session aggregation, whisper counts, roster changes, per-player duration, search, deletion during an active trip, reload separation and saved preference preservation. Trip details retain the latest 50 non-whisper activities, with counts retained when older details are omitted. History retains up to 100 entries per player.

**This Alpha has not been verified in the real WoW Forever client.** User screenshots confirm that earlier UI builds opened in game; they do not validate every tracker or persistence. Targets Forever 1.60.1 / Interface 16001. Quest entries describe your actions, dungeon events do not prove a clear, and trade attempts do not prove completion.

---

# Crossroads: Player Memory 0.2.3 Alpha

A simpler journal with more room for the people and events you want to remember.

- A calmer interface with compact navigation and fewer visible controls.
- Time together is prominent beneath the player name, formatted in hours and minutes.
- History, Profile and Statistics have separate tabs.
- Timeline entries use consistent rows: time, event and location, grouped by date.
- Click an event to read its details or delete it with confirmation.
- One category menu replaces the grid of history filters; text search remains available.
- Rating and tag menus keep profile editing compact; selected tags remain visible.
- Clear history and Delete player are available on the Profile tab, with confirmation.

Existing profiles, notes and statistics are preserved. Removing history does not recalculate lifetime totals. Deleted players are not automatically recreated until the next login/reload, unless explicitly added again.

Validation: offline Lua 5.1 tests pass, including navigation, menus, event details, deletion and cancellation, changes arriving during confirmation, legacy entry IDs and saved-note drafts. A layout preview was rendered from mocked frame geometry. **This new interface has not been verified in the real game client.** User screenshots show the previous interface running, but do not verify all trackers or persistence. Experimental Alpha targeting WoW Forever 1.60.1 / Interface 16001.

---

# Crossroads: Player Memory 0.2.2 Alpha

## A clearer player overview

- Dedicated Time Together, Group Sessions and Dungeon / Raid Visits cards.
- Time is formatted as hours and minutes; the player list also shows time together.
- Separate History and Notes & Tags tabs, with a larger, opaque history area.
- Category filters, text search, date headings and compact expandable entries.
- Profile-edit events are hidden by default; select Personal or Show profile edits to display them.
- Repeating an unchanged rating or tag no longer creates a redundant entry.
- Unsaved note drafts survive switching between profiles during the current UI session.
- Window scales down to fit the available UI area.

## Manage your journal

- Delete individual history entries with confirmation.
- Clear all history for one player with confirmation, including entries hidden by filters.
- Delete a whole player profile with confirmation, including notes, labels, totals, trade snapshots and references in saved instance rosters.
- Deleting a timeline entry or clearing history leaves aggregate statistics, current notes, labels and trade snapshots unchanged. The dialogs explain this distinction.
- A deleted player is not automatically recreated during the current session. Automatic recording resumes after login/reload; `/crmemory add First Surname` can add them again sooner. This is deletion, not a permanent ignore list.

Existing profiles and notes are preserved on upgrade. Stable internal entry IDs are added automatically for reliable deletion, including legacy history.

## Validation

Offline Lua 5.1 regression tests pass, including cancellation, filtered-entry deletion, events arriving while confirmation is open, legacy migration, duration formatting, profile deletion, draft retention and prevention of immediate recreation.

The user supplied an in-game screenshot showing the previous 0.2.1 UI and player/edit records. **The new 0.2.2 interface and changes have not yet been tested in the real client.** This remains an Alpha for WoW Forever 1.60.1 / Interface 16001; broader tracking and persistence are not fully verified.

---

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
