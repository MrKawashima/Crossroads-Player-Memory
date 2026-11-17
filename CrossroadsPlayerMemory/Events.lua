local addonName, CR = ...
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

local function allMembers()
    local members = {}
    if not IsInGroup or not IsInGroup() then return members end
    local raid = IsInRaid and IsInRaid()
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, count do
        local token = raid and ("raid" .. i) or ("party" .. i)
        -- The local player occupies a party slot in raids but not in normal parties.
        local name = CR:PlayerName(token)
        if name then members[name:lower()] = name; CR:FromUnit(token, false) end
    end
    return members
end

function CR:GroupMembers()
    return allMembers()
end

function CR:TrackGroup()
    if not self.db then return end
    local current = allMembers()
    local now = self:Now()
    for key, name in pairs(current) do
        if self.db.options.groups and not self.group[key] then
            local p = self:Person(name)
            if p then
                if (p.lastGrouped or 0) < now - 180 then
                    self:Stat(name, "groupSessions", 1)
                    self:Record(name, "group", "Grouped together", "Started in " .. self:Zone(), "observed", true)
                end
                p.lastGrouped = now
            end
        end
    end
    self.group = current
    if self.run then
        for key, name in pairs(current) do self.run.members[key] = name end
    end
    self:UIRefresh()
end

function CR:GroupTick()
    if not self.db then return end
    local now = self:Now()
    local delta = math.min(90, math.max(0, now - (self.lastGroupTick or now)))
    self.lastGroupTick = now
    if self.db.options.groups then
        for _, name in pairs(self.group) do
            local p = self:Stat(name, "timeTogether", delta)
            if p then p.lastGrouped = now end
        end
    end
end

local function instanceState()
    if not GetInstanceInfo then return nil end
    local title, kind, difficulty, _, _, _, _, instanceID = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return nil end
    return title or "Unknown instance", kind, difficulty, instanceID
end

function CR:CheckInstance()
    if not self.db or not self.db.options.instances then return end
    local title, kind, difficulty, instanceID = instanceState()
    if not title then
        if self.run then self:FinishRun(false) end
        return
    end
    if self.run and self.run.instanceID == instanceID and self.run.kind == kind then return end
    if self.run then self:FinishRun(false) end
    local run = {
        id=(self:Now() .. ":" .. tostring(instanceID or 0)), name=title,
        kind=kind, difficulty=difficulty, instanceID=instanceID, started=self:Now(),
        members=allMembers(), bosses={}, lootChat={}, status="ongoing", character=self.me,
    }
    self.run = run
    table.insert(self.db.runs, 1, run)
    while #self.db.runs > 150 do table.remove(self.db.runs) end
    for _, name in pairs(run.members) do
        self:Record(name, "dungeon", "Entered " .. title, "Run started", "observed", true)
    end
    self:UIRefresh()
end

function CR:FinishRun(interrupted)
    local run = self.run
    if not run then return end
    self.run = nil
    run.ended = self:Now()
    run.duration = math.max(0, run.ended - run.started)
    run.status = interrupted and "interrupted" or "left instance"
    local kills = 0
    for _, b in ipairs(run.bosses) do if b.success then kills = kills + 1 end end
    for _, name in pairs(run.members) do
        self:Stat(name, "dungeonRuns", 1)
        self:Record(name, "dungeon", "Visited " .. run.name,
            kills .. " bosses recorded, " .. math.floor(run.duration / 60) .. " min. Clear not independently verified.",
            "observed", true)
    end
    self:UIRefresh()
end

function CR:Boss(encounterID, name, difficultyID, size, success)
    if not self.db.options.instances then return end
    if not self.run then self:CheckInstance() end
    if not self.run then return end
    local won = self:SafeNumber(success) == 1
    local label = self:SafeString(name) or "Unknown boss"
    table.insert(self.run.bosses, {id=encounterID, name=label, success=won, when=self:Now()})
    for _, player in pairs(allMembers()) do
        self.run.members[player:lower()] = player
        if won then self:Stat(player, "bossKills", 1) end
        self:Record(player, "dungeon", (won and "Boss defeated: " or "Boss attempt: ") .. label,
            self.run.name, "observed", true)
    end
    self:UIRefresh()
end

function CR:QuestTurnedIn(questID)
    if not self.db.options.quests or type(questID) ~= "number" then return end
    local members = allMembers()
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    title = self:SafeString(title) or ("Quest #" .. questID)
    for _, name in pairs(members) do
        self:Stat(name, "groupQuests", 1)
        self:Record(name, "quest", "Quest turned in: " .. title,
            "Completed by you while grouped; other players' completion is not verified. ID " .. questID,
            "observed", true)
    end
    self:UIRefresh()
end

function CR:QuestAccepted(questID)
    if not self.db.options.quests or type(questID) ~= "number" then return end
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    title = self:SafeString(title) or ("Quest #" .. questID)
    for _, name in pairs(allMembers()) do
        self:Record(name, "quest", "Quest accepted: " .. title,
            "Accepted by you while grouped; this does not prove the other player accepted it.",
            "observed", true)
    end
    self:UIRefresh()
end

local rollStates = {
    [0]="Need (main)", [1]="Need (off)", [2]="Transmog",
    [3]="Greed", [4]="No roll", [5]="Pass", [6]="Disenchant",
}

function CR:LootUpdate(encounterID, lootListID)
    if not self.db or not self.db.options.loot or not C_LootHistory or not C_LootHistory.GetSortedInfoForDrop then return end
    if type(encounterID) ~= "number" or type(lootListID) ~= "number" then return end
    local ok, drop = pcall(C_LootHistory.GetSortedInfoForDrop, encounterID, lootListID)
    if not ok then return end
    drop = self:CleanTable(drop)
    if type(drop) ~= "table" then return end
    if not drop.winner and not drop.allPassed then return end
    local link = self:SafeString(drop.itemHyperlink) or "Unknown item"
    local started = self:SafeNumber(drop.startTime) or 0
    local fingerprint = tostring(encounterID) .. ":" .. lootListID .. ":" .. started .. ":" .. link
    self.db.lootSeen = self.db.lootSeen or {}
    self.db.lootOrder = self.db.lootOrder or {}
    if self.lootDedupe[fingerprint] or self.db.lootSeen[fingerprint] then return end
    self.lootDedupe[fingerprint] = true
    self.db.lootSeen[fingerprint] = true
    table.insert(self.db.lootOrder, fingerprint)
    while #self.db.lootOrder > 600 do
        self.db.lootSeen[table.remove(self.db.lootOrder, 1)] = nil
    end
    local winnerName = type(drop.winner) == "table" and self:SafeString(drop.winner.playerName)
    if winnerName then
        self:Stat(winnerName, "lootWins", 1)
        self:Record(winnerName, "loot", "Loot won: " .. link,
            "Winner confirmed by game loot history", "observed", true)
    end
    if type(drop.rollInfos) == "table" then
        for _, info in ipairs(drop.rollInfos) do
            local name = self:SafeString(info.playerName)
            if name then
                local state = self:SafeNumber(info.state)
                local choice = rollStates[state] or "Other roll"
                local number = self:SafeNumber(info.roll)
                self:Stat(name, "lootRolls", 1)
                self:Record(name, "loot", choice .. ": " .. link,
                    (number and ("Roll " .. number .. ". ") or "") .. (winnerName and ("Winner: " .. winnerName) or "All passed"),
                    "observed", true)
            end
        end
    end
    self:UIRefresh()
end

-- Keep snapshots while the trade window is open; it may be destroyed at TRADE_CLOSED.
-- Mutual acceptance is not a server-side proof of completion.
local function snapshotTrade(t)
    if not t then return end
    local offered, received = {}, {}
    for i = 1, 6 do
        local out = CR:SafeString(GetTradePlayerItemLink and GetTradePlayerItemLink(i))
        local incoming = CR:SafeString(GetTradeTargetItemLink and GetTradeTargetItemLink(i))
        if out then table.insert(offered, out) end
        if incoming then table.insert(received, incoming) end
    end
    t.offered, t.received = offered, received
    t.offeredCopper = CR:SafeNumber(GetPlayerTradeMoney and GetPlayerTradeMoney()) or 0
    t.receivedCopper = CR:SafeNumber(GetTargetTradeMoney and GetTargetTradeMoney()) or 0
end

function CR:TradeEvent(event, a, b)
    if not self.db.options.trades then return end
    if event == "TRADE_REQUEST" then
        self.tradePendingName = self:SafeString(a)
    elseif event == "TRADE_SHOW" then
        self.trade = {name=self:PlayerName("NPC") or self.tradePendingName,
            started=self:Now(), bothAccepted=false, offered={}, received={}}
        self.tradePendingName = nil
        snapshotTrade(self.trade)
    elseif self.trade and (event == "TRADE_PLAYER_ITEM_CHANGED" or
        event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" or
        event == "TRADE_UPDATE" or event == "PLAYER_TRADE_MONEY" or event == "TRADE_ACCEPT_UPDATE") then
        snapshotTrade(self.trade)
        if event == "TRADE_ACCEPT_UPDATE" then
            -- Acceptance can be withdrawn after this event, so take the latest state.
            self.trade.bothAccepted = a == 1 and b == 1
        end
    elseif event == "TRADE_CLOSED" and self.trade then
        local t = self.trade
        self.trade = nil
        if t.name then
            self:Stat(t.name, "tradeWindows", 1)
            local details = "Offered: " .. (#t.offered > 0 and table.concat(t.offered, ", ") or "none")
              .. "; received: " .. (#t.received > 0 and table.concat(t.received, ", ") or "none")
              .. "; gold offered (copper): " .. (t.offeredCopper or 0)
              .. "; gold received (copper): " .. (t.receivedCopper or 0)
            -- Store a longer structured record privately and a short human summary.
            local person = self:Person(t.name)
            if person then
                person.trades = person.trades or {}
                table.insert(person.trades, 1, {
                    when=self:Now(), accepted=t.bothAccepted, offered=t.offered,
                    received=t.received, offeredCopper=t.offeredCopper,
                    receivedCopper=t.receivedCopper, outcome="unverified",
                })
                while #person.trades > 30 do table.remove(person.trades) end
            end
            self:Record(t.name, "trade", "Trade window closed",
                t.bothAccepted and "Both accepted before closing; final success unverified"
                    or "Trade attempted; not confirmed completed", "observed")
        end
    end
end

function CR:SocialEvent(event, name)
    if not self.db.options.social then return end
    name = self:SafeString(name)
    if not name then return end
    local p = self:Person(name)
    if not p then return end
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        local incoming = event == "CHAT_MSG_WHISPER"
        self:Stat(name, incoming and "whispersReceived" or "whispersSent", 1)
        local field = incoming and "lastWhisperIn" or "lastWhisperOut"
        if self:Now() - (p[field] or 0) > 900 then
            self:Record(name, "social", incoming and "Received whisper" or "Sent whisper",
                "Message contents are never saved", "observed", true)
        end
        p[field] = self:Now()
    elseif self.db.options.chatCounts and event == "CHAT_MSG_PARTY" then
        self:Stat(name, "groupChatMessages", 1)
    elseif event == "CHAT_MSG_TEXT_EMOTE" or event == "CHAT_MSG_EMOTE" then
        if self:Now() - (p.lastEmote or 0) > 600 then
            self:Record(name, "social", "Emote encounter",
                "Emote happened; message content not retained", "observed", true)
        end
        p.lastEmote = self:Now()
    end
end

function CR:MarkDeath()
    if not self.db.options.pvp or self.deathActive then return end
    self.deathActive = true
    self.deathNumber = (self.deathNumber or 0) + 1
    local serial = self.deathNumber
    self.lastDeathProcessed = nil
    local function retry()
        if CR.deathNumber ~= serial or CR.lastDeathProcessed == serial then return end
        CR:ReadDeathRecap(serial)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.35, retry)
        C_Timer.After(1.15, retry)
        C_Timer.After(2.5, retry)
    else
        retry()
    end
end

function CR:ReadDeathRecap(serial)
    if not C_DeathRecap or not C_DeathRecap.GetRecapEvents then return end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents)
    if not ok then return end
    events = self:CleanTable(events)
    if type(events) ~= "table" or #events == 0 then return end
    local attackers = {}
    local killer
    for _, e in ipairs(events) do
        if type(e) == "table" then
            local source = self:SafeString(e.sourceName)
            local guid = self:SafeString(e.sourceGUID)
            local flags = self:SafeNumber(e.sourceFlags)
            local isPlayer = (guid and guid:sub(1, 7) == "Player-") or
                (flags and bit and bit.band and bit.band(flags, 0x00000400) ~= 0)
            if source and isPlayer then
                local k = self:Normalize(source)
                if k then
                    attackers[k] = source
                    local overkill = self:SafeNumber(e.overkill)
                    if (self:Plain(e.isKillingBlow) and e.isKillingBlow == true) or (overkill and overkill > 0) then killer = source end
                end
            end
        end
    end
    local hasAttacker = next(attackers) ~= nil
    if not hasAttacker then
        self.lastDeathProcessed = serial
        return
    end
    self.lastDeathProcessed = serial
    local killerKey = killer and self:Normalize(killer)
    if not killer and next(attackers) then
        -- The recap confirms the attacker, but not necessarily who struck the fatal blow.
        for _, name in pairs(attackers) do
            self:Stat(name, "pvpAttacks", 1)
            self:Record(name, "pvp", "Attacked you before death",
                "PvP death recap; killing blow not identified", "observed", true)
        end
    else
        for key, name in pairs(attackers) do
            if key == killerKey then
                self:Stat(name, "deathsTo", 1)
                self:Record(name, "pvp", "Killed you",
                    "Fatal hit in the game's death recap", "confirmed", true)
                local p = self:Person(name)
                if p then p.tags.Rival = true end
                if self.db.options.alerts then self:Say("PvP death: killed by " .. name .. " (saved as Rival)") end
            else
                self:Stat(name, "pvpAttacks", 1)
                self:Record(name, "pvp", "Participated in your death",
                    "Dealt damage according to death recap", "observed", true)
            end
        end
    end
    self:UIRefresh()
end

function CR:PartyKill(attacker, victim)
    if not self.db.options.pvp then return end
    local a, v = self:SafeString(attacker), self:SafeString(victim)
    local myGuid = self:SafeString(UnitGUID("player"))
    if not a or not v or not myGuid or a ~= myGuid then return end
    local key = self.guidCache[v]
    if not key then return end
    local p = self.db.people[key]
    if not p then return end
    self:Stat(p.name, "killsOf", 1)
    self:Record(p.name, "pvp", "You killed this player",
        "Own PARTY_KILL credit matched a known character GUID", "confirmed")
end

function CR:SeenHostile(unit)
    if not self.db or not self.db.options.sight then return end
    local name = self:PlayerName(unit)
    if not name then return end
    local p = self:Find(name)
    if not p then return end
    if not (p.tags["Kill on Sight"] or p.tags.Rival or p.tags.Avoid) then return end
    local hostile = UnitCanAttack("player", unit)
    if not self:Plain(hostile) or hostile ~= true then return end
    local now = self:Now()
    if (self.lastPvPAlert[p.key] or 0) > now - 90 then return end
    self.lastPvPAlert[p.key] = now
    if self.db.options.alerts then
        self:Say("Nearby: |cffff625e" .. p.name .. "|r (" .. (p.tags["Kill on Sight"] and "Kill on Sight" or "Rival / Avoid") .. ")")
        if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
    end
end

function CR:InstallTooltip()
    if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall or not Enum or not Enum.TooltipDataType then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        if not CR.db or not CR.db.options.tooltips or not tooltip.GetUnit then return end
        local _, unit = tooltip:GetUnit()
        if not unit then return end
        local p = CR:Find(CR:PlayerName(unit))
        if not p then return end
        local s = p.stats
        tooltip:AddLine("Crossroads: " .. (p.rating or 0) .. "/5 | " .. (s.groupSessions or 0) .. " groups", 0.85, 0.7, 0.4)
        if p.tags["Kill on Sight"] or p.tags["Ninja Looter"] or p.tags.Avoid then
            tooltip:AddLine("Personal warning / label", 1, 0.35, 0.35)
        elseif p.tags.Friend or p.tags.Helpful then
            tooltip:AddLine("Marked as friend / helpful", 0.4, 1, 0.5)
        end
    end)
end

function CR:StartEvents()
    local events = {
        "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "GROUP_ROSTER_UPDATE", "QUEST_TURNED_IN",
        "QUEST_ACCEPTED", "ENCOUNTER_END", "PLAYER_DEAD", "PARTY_KILL",
        "PLAYER_ALIVE", "PLAYER_UNGHOST", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
        "TRADE_REQUEST", "TRADE_SHOW", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED",
        "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_MONEY_CHANGED",
        "TRADE_UPDATE", "PLAYER_TRADE_MONEY",
        "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_PARTY",
        "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_EMOTE", "DUEL_REQUESTED", "DUEL_FINISHED",
        "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER",
    }
    self.unavailableEvents = {}
    for _, event in ipairs(events) do
        local ok = pcall(f.RegisterEvent, f, event)
        if not ok then
            table.insert(self.unavailableEvents, event)
            self:Say("Unavailable event: " .. event .. "; related tracking is disabled.")
        end
    end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(30, function() if CR.db then CR:GroupTick() end end)
    end
    self:TrackGroup()
    self:CheckInstance()
end

local function onEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName then CR.loaded = true end
        return
    end
    if event == "PLAYER_LOGIN" then
        CR:Init()
        return
    end
    if not CR.db then return end
    if event == "PLAYER_ENTERING_WORLD" then
        CR:GroupTick()
        CR:TrackGroup()
        CR:CheckInstance()
    elseif event == "PLAYER_LOGOUT" then
        CR:GroupTick()
        if CR.run then CR:FinishRun(true) end
    elseif event == "GROUP_ROSTER_UPDATE" then
        CR:GroupTick()
        CR:TrackGroup()
    elseif event == "QUEST_TURNED_IN" then CR:QuestTurnedIn(...)
    elseif event == "QUEST_ACCEPTED" then
        local index, qid = ...
        CR:QuestAccepted(type(qid) == "number" and qid or index)
    elseif event == "ENCOUNTER_END" then CR:Boss(...)
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
        if CR:Plain(dead) and dead == false then
            CR.deathActive = false
            CR.deathNumber = (CR.deathNumber or 0) + 1
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then CR:CheckInstance()
    elseif event == "PLAYER_DEAD" then CR:MarkDeath()
    elseif event == "PARTY_KILL" then CR:PartyKill(...)
    elseif event == "PLAYER_TARGET_CHANGED" then
        if CR.db.options.sight then CR:FromUnit("target", true) end
        CR:SeenHostile("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then CR:SeenHostile("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then CR:SeenHostile(...)
    elseif event == "TRADE_REQUEST" or event == "TRADE_SHOW" or event == "TRADE_ACCEPT_UPDATE"
      or event == "TRADE_CLOSED" or event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED"
      or event == "TRADE_MONEY_CHANGED" or event == "TRADE_UPDATE" or event == "PLAYER_TRADE_MONEY" then
        CR:TradeEvent(event, ...)
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_PARTY"
        or event == "CHAT_MSG_TEXT_EMOTE" or event == "CHAT_MSG_EMOTE" then
        local _, sender = ...
        CR:SocialEvent(event, sender)
    elseif event == "DUEL_REQUESTED" then
        local opponent = CR:SafeString(...)
        if opponent and CR.db.options.social then
            CR.duelOpponent = opponent
            CR:Record(opponent, "social", "Duel requested", "Duel request received", "observed")
        end
    elseif event == "DUEL_FINISHED" then
        if CR.duelOpponent and CR.db.options.social then
            CR:Record(CR.duelOpponent, "social", "Duel ended", "Result not independently verified", "observed")
        end
        CR.duelOpponent = nil
    elseif event == "LOOT_HISTORY_UPDATE_DROP" then CR:LootUpdate(...)
    elseif event == "LOOT_HISTORY_UPDATE_ENCOUNTER" then
        local encounterID = ...
        if type(encounterID) == "number" and C_LootHistory and C_LootHistory.GetSortedDropsForEncounter then
            local ok, drops = pcall(C_LootHistory.GetSortedDropsForEncounter, encounterID)
            if ok then drops = CR:CleanTable(drops) end
            if ok and type(drops) == "table" then
                for _, drop in ipairs(drops) do
                    local key = type(drop) == "table" and drop.lootListID
                    if type(key) == "number" then CR:LootUpdate(encounterID, key) end
                end
            end
        end
    end
end
f:SetScript("OnEvent", function(frame, event, ...)
    local args = {}
    local count = select("#", ...)
    for i = 1, count do args[i] = CR:CleanTable((select(i, ...))) end
    onEvent(frame, event, unpack(args, 1, count))
end)
