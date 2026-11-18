# Alpha quality assurance

## Evidence and scope — 17 November 2026

The four supplied Lua modules in the addon archive match their copies in the publishing kit byte-for-byte. The existing implementation was retained and patched; it was not rebuilt from scratch. The original archives and extracted originals remain unchanged.

`tests/test_crossroads.py` loads all four modules with Lua 5.1 and exercises mocked WoW API boundaries. Passing scenarios: login despite an unavailable event; isolated global/storage names; secret scalar/table rejection; finite-number checks; two-part player names; self exclusion; group time; quest events; instance entry, boss and exit; correct `lootListID`; persistent loot deduplication; trade acceptance withdrawal and avoidance of target-based attribution; notes/ratings/tags; whisper counts; duplicate death events; zero-overkill ambiguity; readable final-hit attribution; GUID-matched kills; history bounds; main/options UI construction; minimap click, drag, hide and reset.

These mocks cannot reproduce WoW taint, protected actions, actual secret-value semantics, native event delivery, texture rendering or SavedVariables persistence. No real-client pass is claimed. Source fields and API availability must still be verified in Forever.

## API references checked

- Captured Forever API findings and Interface 16001: https://github.com/Thunderz96/forever-addon-kit
- Author-observed surname changes, event registration failures and duplicate death events: https://github.com/realworldbuilder/wowwrapped/blob/main/docs/addon-api.md
- Blizzard generated loot documentation (Mainline source mirror): https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/LootHistoryDocumentation.lua
- Blizzard generated death-recap documentation (Mainline source mirror): https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/DeathRecapDocumentation.lua

Mainline documents support the API review but are not proof of identical behavior in Forever. DeathRecapEventInfo fields are not described by the generated structure, so runtime attribution remains explicitly experimental.

## Required real-client checks

1. Load on Interface 16001 with Lua errors enabled; verify startup, icon and both windows.
2. Move the minimap launcher, reload and restart; verify settings and journal persistence.
3. Check full names, ambiguous names, local-player exclusion and multiple characters/rulesets.
4. Join/leave groups; toggle tracking; compare observed group time and your quest activity.
5. Enter/leave an instance, record boss attempts, and reload during a visit.
6. Check Need/Greed/Pass, a winner, all-pass results and reload deduplication.
7. Initiate/receive/cancel a trade with a different selected target; verify correct partner and unverified outcome.
8. Check whisper counts without content retention.
9. Test PvP attacker evidence, pets, duplicate deaths, revival, restricted data and kill credit.
10. Verify the unrelated Crossroads addon is not overwritten and `/crmemory` remains available.

## Open design limitations

Account-wide name-keyed records can conflate characters sharing a full name across rulesets. Profiles have no total count cap. First-name identity recovery and trade partner availability remain conservative. The Alpha does not migrate private prototype storage automatically.

## 0.2.2 UI and deletion

User evidence: an in-game screenshot of 0.2.1 shows the journal opening, player profiles and manual rating/tag entries. It does not validate all trackers. The redesigned 0.2.2 UI has only been exercised with mocks, not rendered in the game.

Additional Lua 5.1 tests cover readable durations; unchanged rating/tag deduplication; category and text filters; default hiding of profile edits; cancel and confirm; stable deletion after rows reorder or the selected player changes; independent totals; expand/collapse; unsaved drafts; empty filtered selections; one-to-one legacy entry-ID migration; complete profile deletion and cleanup of run/GUID/trade references; suppression of automatic recreation during the session; and explicit re-adding.

In-game checks still required: low-resolution layout/scaling; scroll and long-text behavior; modal interaction and cancellation; delete one filtered entry while new events arrive; delete a grouped player and confirm they remain absent until reload; preserve existing notes/history across upgrade; verify hourly duration formatting with real play time. Deleting a row or history intentionally does not reconstruct totals from the capped history.

## 0.2.3 simplified journal

offline Lua 5.1 tests pass, including navigation, menus, event details, deletion and cancellation, changes arriving during confirmation, legacy entry IDs and saved-note drafts. A layout preview was rendered from mocked frame geometry. **This new interface has not been verified in the real game client.** User screenshots show the previous interface running, but do not verify all trackers or persistence. Experimental Alpha targeting WoW Forever 1.60.1 / Interface 16001.

Additional assertions cover three-tab visibility, mutually exclusive menus, rating selection, event details without row expansion, and destructive actions hidden from History. In-game font wrapping, scrolling, dropdown interaction and low-resolution scaling still require client validation.

## 0.2.4 group trips

Offline Lua 5.1 regressions pass, including session aggregation, whisper counts, roster changes, per-player duration, search, deletion during an active trip, reload separation and saved preference preservation. Trip details retain the latest 50 non-whisper activities, with counts retained when older details are omitted. History retains up to 100 entries per player.

**This Alpha has not been verified in the real WoW Forever client.** User screenshots confirm that earlier UI builds opened in game; they do not validate every tracker or persistence. Targets Forever 1.60.1 / Interface 16001. Quest entries describe your actions, dungeon events do not prove a clear, and trade attempts do not prove completion.

## 0.2.5 sorting

All five sort fields and both directions, ties, missing statistics, search/filter combinations, selection retention and saved options pass offline tests. In-client dropdown layout and interaction remain unverified.
