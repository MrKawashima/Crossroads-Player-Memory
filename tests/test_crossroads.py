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
function CreateFrame(kind, name)
 local f = {scripts={}, shown=false, text='', width=140, height=140, checked=false}
 setmetatable(f,{__index=function(_, k)
  if k=='SetScript' or k=='HookScript' then return function(self, ev, fn) self.scripts[ev]=fn end end
  if k=='RegisterEvent' then return function(self,ev) if ev=='PARTY_KILL' then error('unsupported mock event') end end end
  if k=='CreateTexture' or k=='CreateFontString' then return function() return CreateFrame() end end
  if k=='SetText' then return function(self,s) self.text=s end end
  if k=='GetText' then return function(self) return self.text end end
  if k=='SetSize' then return function(self,w,h) self.width=w; self.height=h end end
  if k=='GetWidth' then return function(self) return self.width end end
  if k=='GetHeight' then return function(self) return self.height end end
  if k=='GetFrameLevel' then return function() return 1 end end
  if k=='GetEffectiveScale' then return function() return 1 end end
  if k=='GetCenter' then return function() return 100,100 end end
  if k=='Show' then return function(self) self.shown=true end end
  if k=='Hide' then return function(self) self.shown=false end end
  if k=='IsShown' then return function(self) return self.shown end end
  if k=='GetChecked' then return function(self) return self.checked end end
  if k=='SetChecked' then return function(self,v) self.checked=v end end
  return noop
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
