"""Offline Lua 5.1 regression tests. These do not emulate the real WoW client."""
from pathlib import Path
import sys
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'WhatsNext' / '.test-deps'))
    from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
CR = {}; frames = {}; SlashCmdList = {}; UISpecialFrames = {}; clock = 2000
local noop = function() end
function CreateFrame(kind, name, parent)
 local f = {scripts={}, shown=true, text='', width=140, height=140, checked=false, kind=kind, parent=parent, points={}}
 setmetatable(f,{__index=function(_, k)
  if k=='SetScript' or k=='HookScript' then return function(self, ev, fn) self.scripts[ev]=fn end end
  if k=='RegisterEvent' then return function(self,ev) if ev=='PARTY_KILL' then error('unsupported mock event') end end end
  if k=='CreateTexture' or k=='CreateFontString' then return function(self,_,layer,font) local child=CreateFrame(k=='CreateTexture' and 'Texture' or 'FontString',nil,self); child.font=font; return child end end
  if k=='GetHighlightTexture' then return function() return {SetVertexColor=function() end} end end
  if k=='SetText' then return function(self,s) self.text=s end end
  if k=='GetText' then return function(self) return self.text end end
  if k=='SetSize' then return function(self,w,h) self.width=w; self.height=h end end
  if k=='SetWidth' then return function(self,w) self.width=w end end
  if k=='SetHeight' then return function(self,h) self.height=h end end
  if k=='SetPoint' then return function(self,...) self.points[#self.points+1]={...} end end
  if k=='ClearAllPoints' then return function(self) self.points={} end end
  if k=='SetAllPoints' then return function(self,p) self.allPoints=p end end
  if k=='SetBackdrop' then return function(self,v) self.backdrop=v end end
  if k=='SetBackdropColor' then return function(self,...) self.color={...} end end
  if k=='SetBackdropBorderColor' then return function(self,...) self.borderColor={...} end end
  if k=='SetNormalFontObject' then return function(self,font) self.font=font end end
  if k=='GetWidth' then return function(self) return self.width end end
  if k=='GetHeight' then return function(self) return self.height end end
  if k=='GetStringHeight' then return function(self) return 16 * math.max(1,math.ceil(#self.text/70)) end end
  if k=='GetVerticalScroll' then return function(self) return self.scroll or 0 end end
  if k=='SetVerticalScroll' then return function(self,v) self.scroll=v end end
  if k=='SetShown' then return function(self,v) self.shown=v end end
  if k=='SetEnabled' then return function(self,v) self.enabled=v end end
  if k=='Enable' then return function(self) self.enabled=true end end
  if k=='Disable' then return function(self) self.enabled=false end end
  if k=='GetFrameLevel' then return function() return 1 end end
  if k=='GetEffectiveScale' then return function() return 1 end end
  if k=='GetCenter' then return function() return 100,100 end end
  if k=='Show' then return function(self) self.shown=true end end
  if k=='Hide' then return function(self) self.shown=false end end
  if k=='IsShown' then return function(self) return self.shown end end
  if k=='GetChecked' then return function(self) return self.checked end end
  if k=='SetChecked' then return function(self,v) self.checked=v end end
  if k:match('^%u') then return noop end
  return nil
 end})
 frames[#frames+1]=f; if name then _G[name]=f end; return f
end
UIParent=CreateFrame(); Minimap=CreateFrame(); GameTooltip=CreateFrame()
DEFAULT_CHAT_FRAME={AddMessage=function() end}
SECRET={}; SECRETTABLE={}
function issecretvalue(v) return rawequal(v,SECRET) end
function issecrettable(v) return rawequal(v,SECRETTABLE) end
function GetServerTime() return clock end
function GetZoneText() return 'Test Valley' end
function GetRealmName() return 'Test Ruleset' end
function date() return 'test date' end
units={player={'Local','Hero','Player-1'},party1={'Alice','Oak','Player-2'}, target={'Rival','Ash','Player-3'}}
function UnitExists(u) if u=='secret' then return SECRET end; return units[u]~=nil end
function UnitIsPlayer(u) return units[u]~=nil end
function UnitFullName(u) return unpack(units[u] or {}) end
function GetUnitName(u) local n=units[u]; return n and n[1]..' '..n[2] end
function UnitGUID(u) return units[u] and units[u][3] end
function UnitClass() return 'Warrior','WARRIOR' end
function UnitRace() return 'Human' end
function UnitLevel() return 20 end
function UnitCanAttack() return true end
function UnitIsDeadOrGhost() return false end
function IsInGroup() return true end
function IsInRaid() return false end
function GetNumGroupMembers() return 2 end
function GetCursorPosition() return 200,100 end
C_Timer={NewTicker=function(_,fn) ticker=fn end,After=function(_,fn) fn() end}
C_QuestLog={GetTitleForQuestID=function() return 'A Test Quest' end}
C_AddOns={DoesAddOnExist=function() return true end}
instance=false
function GetInstanceInfo() if instance then return 'Test Dungeon','party',1,'Normal',5,0,0,123 end; return 'World','none' end
function GetTradePlayerItemLink() return nil end
function GetTradeTargetItemLink() return nil end
function GetPlayerTradeMoney() return 10 end
function GetTargetTradeMoney() return 20 end
''')
for name in ['Core.lua','Events.lua','UI.lua','Minimap.lua']:
    src=(root/'CrossroadsPlayerMemory'/name).read_text(encoding='utf-8')
    lua.execute('assert(loadstring(...))("CrossroadsPlayerMemory", CR)', src)
lua.execute(r'''
eventFrame=frames[4]
assert(eventFrame.scripts.OnEvent)
function event(ev,...) eventFrame.scripts.OnEvent(eventFrame,ev,...) end
event('PLAYER_LOGIN')
assert(CR.db==CrossroadsPlayerMemoryDB and CrossroadsDB==nil)
assert(SLASH_CROSSROADSPLAYERMEMORY1=='/crmemory' and SLASH_CROSSROADSPLAYERMEMORY3==nil)
assert(#CR.unavailableEvents==1 and CR.unavailableEvents[1]=='PARTY_KILL')
assert(CR.minimapButton and CR.minimapButton:IsShown())
assert(CR:PlayerName('secret')==nil)
assert(CR:SafeNumber(0/0)==nil and CR:SafeNumber(math.huge)==nil)
assert(CR:CleanTable({name=SECRET,nested=SECRETTABLE,ok=1}).ok==1)
assert(CR:CleanTable({name=SECRET}).name==nil)
assert(CR:PlayerName('party1')=='Alice Oak')
assert(CR:Find('Alice-Oak').name=='Alice Oak')
assert(CR:Person('Local Hero')==nil)
clock=2030; ticker(); assert(CR:Find('Alice Oak').stats.timeTogether==30)
event('QUEST_TURNED_IN',42); assert(CR:Find('Alice Oak').stats.groupQuests==1)
event('QUEST_TURNED_IN',SECRET)
instance=true; event('PLAYER_ENTERING_WORLD'); assert(CR.run)
event('ENCOUNTER_END',9,'Test Boss',1,5,1); assert(CR:Find('Alice Oak').stats.bossKills==1)
instance=false; event('ZONE_CHANGED_NEW_AREA'); assert(not CR.run and CR:Find('Alice Oak').stats.dungeonRuns==1)
drop={lootListID=7,itemHyperlink='[Test Item]',startTime=2010,winner={playerName='Alice Oak'},rollInfos={{playerName='Alice Oak',state=0,roll=99}}}
C_LootHistory={GetSortedInfoForDrop=function(_,id) assert(id==7); return drop end,GetSortedDropsForEncounter=function() return {drop} end}
event('LOOT_HISTORY_UPDATE_ENCOUNTER',123)
event('LOOT_HISTORY_UPDATE_DROP',123,7)
assert(CR:Find('Alice Oak').stats.lootWins==1 and CR:Find('Alice Oak').stats.lootRolls==1)
CR.lootDedupe={}; event('LOOT_HISTORY_UPDATE_DROP',123,7); assert(CR:Find('Alice Oak').stats.lootWins==1)
C_LootHistory.GetSortedInfoForDrop=function() return SECRETTABLE end
event('LOOT_HISTORY_UPDATE_DROP',123,8)
event('TRADE_SHOW'); assert(CR.trade.name==nil); event('TRADE_CLOSED')
event('TRADE_REQUEST','Alice Oak'); event('TRADE_SHOW'); event('TRADE_ACCEPT_UPDATE',1,1); event('TRADE_ACCEPT_UPDATE',0,1); event('TRADE_CLOSED')
assert(CR:Find('Alice Oak').trades[1].accepted==false and CR:Find('Alice Oak').trades[1].outcome=='unverified')
CR:Note('Alice Oak','Helpful'); CR:Rate('Alice Oak',5); CR:Tag('Alice Oak','Friend',true)
event('CHAT_MSG_WHISPER','private text never saved','Alice-Oak')
assert(CR:Find('Alice Oak').stats.whispersReceived==1)
CR:FromUnit('target',true)
C_DeathRecap={GetRecapEvents=function() return {{sourceName='Rival Ash',sourceGUID='Player-3',overkill=0}} end}
event('PLAYER_DEAD'); event('PLAYER_DEAD')
assert(CR:Find('Rival Ash').stats.pvpAttacks==1 and CR:Find('Rival Ash').stats.deathsTo==nil)
event('PLAYER_ALIVE')
C_DeathRecap.GetRecapEvents=function() return {{sourceName='Rival Ash',sourceGUID='Player-3',isKillingBlow=true}} end
event('PLAYER_DEAD'); event('PLAYER_DEAD'); assert(CR:Find('Rival Ash').stats.deathsTo==1)
CR:PartyKill('Player-1','Player-3'); assert(CR:Find('Rival Ash').stats.killsOf==1)
for i=1,110 do CR:Record('Alice Oak','note','test','test') end
assert(#CR:Find('Alice Oak').history==100)
CR:OpenUI('alice oak'); CR:ShowOptions()
CR.minimapButton.scripts.OnClick(nil,'LeftButton')
CR.minimapButton.scripts.OnDragStart(CR.minimapButton); CR.minimapButton.scripts.OnUpdate()
CR.minimapButton.scripts.OnDragStop(CR.minimapButton)
assert(CR.db.options.minimapAngle==0)
CR:Slash('minimap hide'); assert(not CR.minimapButton:IsShown())
CR:Slash('minimap reset'); assert(CR.minimapButton:IsShown() and CR.db.options.minimapAngle==225)
''')
print('PASS: Lua 5.1 parse/load; login with unsupported event; namespaces; secret guards; names; groups; quests; instances; loot ID and dedupe; trade attribution; social privacy; death dedupe and conservative attribution; kills; limits; UI and minimap simulation.')

lua.execute(r'''
CR:FinishGroupSession('test boundary')
assert(CR:FormatDuration(0)=='0 min')
assert(CR:FormatDuration(30)=='< 1 min')
assert(CR:FormatDuration(9300)=='2 h 35 min')
assert(CR:FormatDuration(90000)=='25 h 0 min')
local person=CR:Find('Alice Oak')
local before=#person.history
CR:Rate(person.name,person.rating); CR:Tag(person.name,'Friend',true)
assert(#person.history==before)
CR:ClearHistory(person.key)
assert(#person.history==0 and person.stats.timeTogether==30 and person.notes=='Helpful')
CR:Record(person.name,'note','Marked: Friend','Personal edit','manual')
CR:Record(person.name,'group','Grouped together','Test Valley','observed')
CR:Record(person.name,'loot','Loot won: sword','A rare sword','observed')
assert(#CR:HistoryItems(person,'all','',false)==2)
assert(#CR:HistoryItems(person,'note','',false)==1)
assert(#CR:HistoryItems(person,'all','sword',true)==1)
assert(#CR:HistoryItems(person,'group','sword',false)==0)
assert(#CR:HistoryItems(person,'all','',true)==3)

-- Filtered deletion uses entry identity, not the current row index or selected profile.
CR:OpenUI(person.key)
local w=CR.window
w.historyFilter='loot'; CR:UIRefresh()
local target=w.historyRows[1].entry
w.historyRows[1].scripts.OnMouseUp(nil,'LeftButton'); w.eventDialog.remove.scripts.OnClick()
assert(#person.history==3)
w.confirm.cancel.scripts.OnClick(); assert(#person.history==3)
w.historyRows[1].scripts.OnMouseUp(nil,'LeftButton'); w.eventDialog.remove.scripts.OnClick()
CR:Record(person.name,'loot','Another drop','Different record','observed')
CR:SelectPerson('rival ash')
w.confirm.accept.scripts.OnClick()
assert(#person.history==3)
for _,e in ipairs(person.history) do assert(e~=target) end
for _,e in ipairs(CR.db.activity) do assert(e.id~=target.id) end
assert(person.stats.timeTogether==30)

-- Read details without changing row geometry, draft retention and empty search state.
CR:SelectPerson(person.key); w.historyFilter='all'; CR:UIRefresh()
local row=w.historyRows[1]
local rowHeight=row.height
row.scripts.OnMouseUp(nil,'LeftButton'); assert(w.eventDialog.entry==row.entry and w.eventDialog:IsShown())
w.eventDialog.close.scripts.OnClick(); assert(not w.eventDialog:IsShown() and row.height==rowHeight)
w.notes:SetText('Unsaved draft'); w.notes.scripts.OnTextChanged(w.notes,true)
CR:SelectPerson('rival ash'); CR:SelectPerson(person.key)
assert(w.notes:GetText()=='Unsaved draft' and person.notes=='Helpful')
w.saveNote.scripts.OnClick(); assert(person.notes=='Unsaved draft' and w.drafts[person.key]==nil)
w.search:SetText('not a matching player'); CR:UIRefresh()
assert(w.selected==nil and w.deletePlayer.enabled==false and w.saveNote.enabled==false)
w.search:SetText(''); CR:OpenUI(person.key)

-- Migration links identical legacy events one-to-one and is idempotent.
local legacy=CR:Person('Legacy Person')
legacy.history={{when=123,kind='note',title='Same'},{when=123,kind='note',title='Same'}}
CR.db.activity={{key=legacy.key,when=123,kind='note',title='Same'},{key=legacy.key,when=123,kind='note',title='Same'}}
CR:UpgradeHistoryIDs()
local id1,id2=legacy.history[1].id,legacy.history[2].id
assert(id1~=id2 and CR.db.activity[1].id==id1 and CR.db.activity[2].id==id2)
CR:UpgradeHistoryIDs(); assert(legacy.history[1].id==id1)
assert(CR:DeleteHistoryEntry(legacy.key,legacy.history[2]))
assert(#legacy.history==1 and #CR.db.activity==1 and CR.db.activity[1].id==id1)

-- Delete player removes references but does not delete other players or shared runs.
local key=person.key
CR.db.runs={{members={[key]=person.name,['rival ash']='Rival Ash'}}}
CR.run={members={[key]=person.name}}
CR.guidCache['Player-2']=key
CR.group[key]=person.name
CR.trade={name=person.name}; CR.tradePendingName=person.name; CR.duelOpponent=person.name
CR:OpenUI(key); w.deletePlayer.scripts.OnClick()
w.confirm.cancel.scripts.OnClick(); assert(CR.db.people[key])
w.deletePlayer.scripts.OnClick(); w.confirm.accept.scripts.OnClick()
assert(CR.db.people[key]==nil and CR:Find('Rival Ash')~=nil)
assert(CR.guidCache['Player-2']==nil and CR.group[key]==nil)
assert(CR.db.runs[1].members[key]==nil and CR.db.runs[1].members['rival ash']=='Rival Ash')
assert(CR.run.members[key]==nil and CR.trade==nil and CR.tradePendingName==nil and CR.duelOpponent==nil)
assert(CR:Person('Alice Oak')==nil)
clock=2100; CR:TrackGroup(); CR:GroupTick(); assert(CR.db.people[key]==nil)
CR:Slash('add Alice Oak'); assert(CR.db.people[key] and next(CR.db.people[key].stats)==nil)
CR:ClearHistory(key); assert(#CR.db.people[key].history==0)
''')
print('PASS: duration formatting, edit noise reduction, filters, deletion/cancellation, stale selection safety, independent totals, event details, drafts, legacy migration and profile cleanup.')

lua.execute(r'''
local w=CR.window
CR:OpenUI('alice oak')
w.tabs.history.scripts.OnClick()
assert(w.historyPane.shown and not w.notesPane.shown and not w.statsPane.shown)
assert(not w.deletePlayer.shown and not w.clearHistory.shown)
for _,menu in ipairs(w.menus) do assert(not menu.shown) end
w.historyFilterButton.scripts.OnClick(); assert(w.historyMenu.shown)
w.historyFilters.social.scripts.OnClick(); assert(not w.historyMenu.shown and w.historyFilter=='social')
w.tabs.notes.scripts.OnClick()
assert(w.notesPane.shown and w.deletePlayer.shown and w.clearHistory.shown and not w.historyPane.shown)
w.editTags.scripts.OnClick(); assert(w.tagMenu.shown)
w.ratingButton.scripts.OnClick(); assert(w.ratingMenu.shown and not w.tagMenu.shown)
w.stars[4].scripts.OnClick(); assert(CR:Find('Alice Oak').rating==4 and not w.ratingMenu.shown)
w.tabs.stats.scripts.OnClick(); assert(w.statsPane.shown and not w.notesPane.shown and not w.deletePlayer.shown)
w.tabs.history.scripts.OnClick()
''')
print('PASS: simplified navigation, mutually exclusive menus, rating selection and hiding destructive actions from history.')


lua.execute(r'''
-- Fresh persisted options match the requested screenshot; saved choices survive upgrades.
CrossroadsPlayerMemoryDB={}; CR.run=nil; CR:Init()
assert(CR.db.options.sight==false and CR.db.options.chatCounts==false)
for _,k in ipairs({'groups','quests','instances','pvp','loot','trades','social','alerts','tooltips','minimapIcon'}) do assert(CR.db.options[k]==true) end
local alice=CR:Find('Alice Oak'); local trip=alice.history[1]
assert(trip.sessionID and #alice.history==1)
clock=clock+30; CR:GroupTick()
for i=1,20 do CR:SocialEvent('CHAT_MSG_WHISPER','Alice Oak') end
CR:SocialEvent('CHAT_MSG_WHISPER_INFORM','Alice Oak')
CR:QuestTurnedIn(42)
assert(#alice.history==1 and trip.whispersIn==20 and trip.whispersOut==1 and trip.counts.quest==1)
assert(trip.duration==30 and #trip.events==1)
assert(#CR:HistoryItems(alice,'social','',false)==1)
assert(#CR:HistoryItems(alice,'quest','A Test Quest',false)==1)
local outsider=CR:Person('Other Person'); CR:SocialEvent('CHAT_MSG_WHISPER',outsider.name)
assert(not outsider.history[1].sessionID and trip.whispersIn==20)
units.party2={'Bob','Pine','Player-4'}; CR:TrackGroup()
local bob=CR:Find('Bob Pine'); local bobTrip=bob.history[1]
assert(bobTrip.sessionID==trip.sessionID and trip.members['bob pine']=='Bob Pine')
clock=clock+60; CR:GroupTick(); assert(trip.duration==90 and bobTrip.duration==60)
units.party1=nil; CR:TrackGroup(); clock=clock+30; CR:GroupTick()
assert(trip.duration==90 and bobTrip.duration==90 and trip.status=='left group')
units.party1={'Alice','Oak','Player-2'}; CR:TrackGroup()
clock=clock+30; CR:GroupTick(); assert(trip.duration==120 and bobTrip.duration==120 and #alice.history==1)
CR:OpenUI(alice.key); CR:ShowHistoryEntry(alice.key,trip)
assert(CR.window.eventDialog.detail.text:find('20 received / 1 sent',1,true))
assert(CR.window.eventDialog.detail.text:find('A Test Quest',1,true))
for i=1,60 do CR:QuestAccepted(i) end
assert(#trip.events==50 and trip.omitted==11 and trip.counts.quest==61)
assert(CR:DeleteHistoryEntry(alice.key,trip)); CR:QuestTurnedIn(42); CR:SocialEvent('CHAT_MSG_WHISPER',alice.name)
assert(#alice.history==0) -- No replacement or stray rows after deleting an active trip.
CR:DeletePerson(bob.key); assert(trip.members['bob pine']==nil or CR.db.people['alice oak'].history[1]==nil)
units.party1=nil; units.party2=nil; CR:TrackGroup(); assert(CR.groupSession==nil)
units.party1={'Alice','Oak','Player-2'}; CR:TrackGroup()
local nextTrip=alice.history[1]; assert(nextTrip.sessionID~=trip.sessionID)
CR.db.options.sight=true; CR.db.options.loot=false
CR:Init(); assert(CR.db.options.sight==true and CR.db.options.loot==false)
assert(nextTrip.status=='interrupted by reload/logout')
assert(CR:Find('Alice Oak').history[1].sessionID~=nextTrip.sessionID)
CR.db.options.groups=false; CR:TrackGroup(); assert(CR.groupSession==nil)
local count=#CR:Find('Alice Oak').history; CR:QuestTurnedIn(42)
assert(#CR:Find('Alice Oak').history==count+1)
''')
print('PASS: trip aggregation, whisper privacy/counts, roster changes, per-player duration, search/categories, bounded details, active-trip deletion, reload separation and default/preserved settings.')
