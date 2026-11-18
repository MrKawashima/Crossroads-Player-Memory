local addonName, CR = ...
_G.CrossroadsPlayerMemoryLocal = CR
CR.version = "0.2.5-alpha"
CR.settingsDefaults = {
    groups = true, quests = true, instances = true, pvp = true,
    loot = true, trades = true, social = true, sight = false,
    alerts = true, tooltips = true, chatCounts = false, minimapIcon = true,
    playerSort = "recent", playerSortAscending = false,
}
CR.tags = {"Friend", "Helpful", "Great Tank", "Great Healer", "Great DPS", "Rival", "Ninja Looter", "Avoid", "Kill on Sight"}
CR.types = {group="Group", quest="Quest", dungeon="Dungeon", pvp="PvP", loot="Loot", trade="Trade", social="Social", note="Personal", sight="Encounter"}

-- Combat-related data may be secret on the Forever client. Never inspect secret values.
function CR:Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

function CR:SafeString(v)
    if not self:Plain(v) or type(v) ~= "string" then return nil end
    v = v:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if v == "" or v == "Unknown" or v == "UNKNOWN" or #v > 500 then return nil end
    return v
end

function CR:SafeNumber(v)
    if not self:Plain(v) or type(v) ~= "number" then return nil end
    if v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

-- Copy only accessible values before inspecting API tables or persisting them.
function CR:CleanTable(value, depth)
    if not self:Plain(value) then return nil end
    if type(value) ~= "table" then return value end
    if issecrettable and issecrettable(value) then return nil end
    depth = depth or 0
    if depth > 8 then return nil end
    local out = {}
    for k, v in pairs(value) do
        if self:Plain(k) and (type(k) == "string" or type(k) == "number") then
            out[k] = self:CleanTable(v, depth + 1)
        end
    end
    return out
end

function CR:Say(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd3ad69Crossroads|r: " .. tostring(text)) end
end

function CR:Now()
    if GetServerTime then return GetServerTime() end
    return time()
end

function CR:Date(stamp)
    return date("%d.%m.%y %H:%M", stamp or self:Now())
end

function CR:Zone()
    return self:SafeString(GetZoneText and GetZoneText()) or self:SafeString(GetRealZoneText and GetRealZoneText()) or "Unknown area"
end

function CR:PlayerName(unit)
    local exists = UnitExists and UnitExists(unit)
    if not self:Plain(exists) or not exists then return nil end
    local player = UnitIsPlayer and UnitIsPlayer(unit)
    if not self:Plain(player) or player ~= true then return nil end
    -- In Forever the second return value of UnitFullName is a SURNAME, not a realm.
    -- GetUnitName returns "First Surname" as a single string.
    local name = self:SafeString(GetUnitName and GetUnitName(unit, true))
    if name and name:find(" ", 1, true) then return name end
    if not UnitFullName then return name end
    local first, surname = UnitFullName(unit)
    first, surname = self:SafeString(first), self:SafeString(surname)
    if first and not first:find(" ", 1, true) and surname then return first .. " " .. surname end
    if first and first:find(" ", 1, true) then return first end
    return name or first
end

function CR:Normalize(name)
    name = self:SafeString(name)
    if not name then return nil end
    -- Chat and some callbacks use First-Surname, whereas unit APIs use First Surname.
    if name:match("^[^%- %s]+%-%S+$") then name = name:gsub("%-", " ", 1) end
    name = name:gsub("%s+", " ")
    local key = name:lower()
    if key == self.meKey then return nil end
    if #name > 120 then return nil end
    return key, name
end

function CR:Resolve(name)
    local key, full = self:Normalize(name)
    if not key or not self.db then return nil end
    if not key:find(" ", 1, true) then
        -- Only match a first name to an existing full name when unambiguous.
        local found
        for k in pairs(self.db.people) do
            if k:sub(1, #key + 1) == key .. " " then
                if found then return key, full end
                found = k
            end
        end
        if found then return found, self.db.people[found].name end
    end
    return key, full
end

function CR:Find(name)
    local key = self:Resolve(name)
    return key and self.db and self.db.people[key]
end

function CR:Person(name)
    if not self.db then return nil end
    local key, display = self:Resolve(name)
    if not key or (self.forgotten and self.forgotten[key]) then return nil end
    local p = self.db.people[key]
    if not p then
        p = {
            key=key, name=display, firstSeen=self:Now(), lastSeen=self:Now(),
            firstZone=self:Zone(), lastZone=self:Zone(), notes="", rating=0,
            tags={}, stats={}, history={}, partial=not key:find(" ", 1, true),
        }
        self.db.people[key] = p
    end
    p.tags = p.tags or {}
    p.stats = p.stats or {}
    p.history = p.history or {}
    return p
end

function CR:FromUnit(unit, meaningful)
    local name = self:PlayerName(unit)
    if not name then return nil end
    local p = self:Person(name)
    if not p then return nil end
    local _, class = UnitClass(unit)
    p.class = self:SafeString(class) or p.class
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if self:SafeString(role) and role ~= "NONE" then p.role = role end
    local race = UnitRace(unit)
    p.race = self:SafeString(race) or p.race
    local level = self:SafeNumber(UnitLevel(unit))
    if level and level > 0 then p.level = level end
    local guild = GetGuildInfo and GetGuildInfo(unit)
    p.guild = self:SafeString(guild) or p.guild
    p.lastSeen, p.lastZone = self:Now(), self:Zone()
    local guid = self:SafeString(UnitGUID(unit))
    if guid then
        p.guid = guid
        self.guidCache[guid] = p.key
    end
    if meaningful then
        local now = self:Now()
        if (p.lastSight or 0) < now - 600 then
            p.lastSight = now
            p.stats.meetings = (p.stats.meetings or 0) + 1
            self:Record(p.name, "sight", "Encountered", "Seen in " .. self:Zone(), "observed", true)
        end
    end
    return p
end

function CR:Record(name, kind, title, detail, confidence, silent)
    if not self.db then return nil end
    local p = self:Person(name)
    if not p then return nil end
    local trip = self:ActiveTrip(p.key)
    if trip and kind ~= "note" and kind ~= "sight" and kind ~= "group" then
        trip.counts[kind] = (trip.counts[kind] or 0) + 1
        trip.events[#trip.events+1] = {when=self:Now(),kind=kind,title=title or kind,
            detail=(self:SafeString(detail) or ""):sub(1,240),zone=self:Zone()}
        while #trip.events > 50 do table.remove(trip.events,1); trip.omitted=(trip.omitted or 0)+1 end
        trip.zones[self:Zone()] = true
        p.lastSeen,p.lastZone=self:Now(),self:Zone()
        if not silent then self:UIRefresh() end
        return p
    end
    if not trip and self.groupSession and self.groupSession.rows[p.key] and self.group[p.key]
        and self.db.options.groups and kind ~= "note" and kind ~= "sight" and kind ~= "group" then return p end
    self.db.nextEntryID = (self.db.nextEntryID or 0) + 1
    local entry = {
        id=self.db.nextEntryID,
        when=self:Now(), kind=kind, title=title or kind,
        detail=(self:SafeString(detail) or ""):sub(1, 240),
        zone=self:Zone(), confidence=confidence or "observed", by=self.me or "Unknown",
    }
    table.insert(p.history, 1, entry)
    while #p.history > 100 do table.remove(p.history) end
    p.lastSeen, p.lastZone = entry.when, entry.zone
    table.insert(self.db.activity, 1, {id=entry.id, key=p.key, name=p.name, when=entry.when, kind=kind, title=title})
    while #self.db.activity > 1500 do table.remove(self.db.activity) end
    if not silent and self.UIRefresh then self:UIRefresh() end
    return p
end

-- Session entries are real history objects, so deletion remains identity-safe.
function CR:ActiveTrip(key)
    local session=self.groupSession
    if not session or not self.db.options.groups or not self.group[key] then return nil end
    local row=session.rows[key]
    local person=self.db.people[key]
    if not row or not person then return nil end
    for _,entry in ipairs(person.history) do if entry==row then return row end end
    return nil -- Deleted or evicted summaries are never recreated during this trip.
end

function CR:TripText(item)
    if not item.sessionID then return item.detail or "" end
    local members,zones={},{}
    for _,name in pairs(item.members or {}) do members[#members+1]=name end
    for zone in pairs(item.zones or {}) do zones[#zones+1]=zone end
    table.sort(members); table.sort(zones)
    local lines={"Time with this player: "..self:FormatDuration(item.duration),
        "Status: "..(item.status or "ongoing"),"Party participants: You, "..table.concat(members,", "),
        "Places: "..table.concat(zones,", "),
        "Whispers: "..(item.whispersIn or 0).." received / "..(item.whispersOut or 0).." sent"}
    for _,kind in ipairs({"quest","dungeon","loot","trade","pvp","social"}) do
        if (item.counts[kind] or 0)>0 then lines[#lines+1]=self.types[kind].." events: "..item.counts[kind] end
    end
    lines[#lines+1]="\nRecorded activities (your observations):"
    for _,event in ipairs(item.events) do
        lines[#lines+1]=date("%H:%M",event.when).."  "..event.title.." — "..event.zone
        if event.detail~="" then lines[#lines+1]=event.detail end
    end
    if #item.events==0 then lines[#lines+1]="No other activities recorded." end
    if item.omitted then lines[#lines+1]=item.omitted.." older activity details omitted; counts retained." end
    return table.concat(lines,"\n")
end

function CR:HistoryTitle(item)
    if not item.sessionID then return item.title or item.kind end
    return "Group trip · "..self:FormatDuration(item.duration)..(item.status=="ongoing" and " · ongoing" or "")
end

function CR:Stat(name, field, delta)
    local p = self:Person(name)
    if p then p.stats[field] = (p.stats[field] or 0) + (delta or 1) end
    return p
end

function CR:FormatDuration(seconds)
    seconds = math.max(0, self:SafeNumber(seconds) or 0)
    local minutes = math.floor(seconds / 60)
    if seconds == 0 then return "0 min" end
    if minutes == 0 then return "< 1 min" end
    local hours = math.floor(minutes / 60)
    if hours == 0 then return minutes .. " min" end
    return hours .. " h " .. (minutes % 60) .. " min"
end

-- Assign stable IDs to old entries without changing their order or statistics.
function CR:UpgradeHistoryIDs()
    local nextID = self.db.nextEntryID or 0
    for _, person in pairs(self.db.people) do
        for _, item in ipairs(person.history or {}) do nextID = math.max(nextID, item.id or 0) end
    end
    for _, item in ipairs(self.db.activity) do nextID = math.max(nextID, item.id or 0) end
    for _, person in pairs(self.db.people) do
        for _, item in ipairs(person.history or {}) do
            if not item.id then nextID = nextID + 1; item.id = nextID end
        end
    end
    local used = {}
    for _, activity in ipairs(self.db.activity) do
        if activity.id then used[activity.id] = true end
    end
    for _, activity in ipairs(self.db.activity) do
        local person = self.db.people[activity.key]
        if not activity.id and person then
            for _, item in ipairs(person.history or {}) do
                if not used[item.id] and item.when == activity.when and item.kind == activity.kind and item.title == activity.title then
                    activity.id = item.id; used[item.id] = true; break
                end
            end
        end
    end
    self.db.nextEntryID = nextID
end

function CR:DeleteHistoryEntry(key, entry)
    local person = self.db.people[key]
    if not person then return false end
    for i, item in ipairs(person.history) do
        if item == entry then
            table.remove(person.history, i)
            for j = #self.db.activity, 1, -1 do
                local activity = self.db.activity[j]
                if activity.key == key and activity.id == entry.id then table.remove(self.db.activity, j) end
            end
            self:UIRefresh()
            return true
        end
    end
    return false
end

function CR:ClearHistory(key)
    local person = self.db.people[key]
    if not person then return end
    person.history = {}
    for i = #self.db.activity, 1, -1 do
        if self.db.activity[i].key == key then table.remove(self.db.activity, i) end
    end
    self:UIRefresh()
end

function CR:DeletePerson(key)
    if not self.db.people[key] then return false end
    self:ClearHistory(key)
    self.db.people[key] = nil
    self.forgotten = self.forgotten or {}
    self.forgotten[key] = true -- Do not immediately recreate from a pending event or group timer.
    for guid, cachedKey in pairs(self.guidCache) do if cachedKey == key then self.guidCache[guid] = nil end end
    self.lastPvPAlert[key] = nil
    for memberKey, name in pairs(self.group) do
        if self:Normalize(name) == key then self.group[memberKey] = nil end
    end
    if self.groupSession then self.groupSession.rows[key]=nil; self.groupSession.members[key]=nil end
    for _,person in pairs(self.db.people) do
        for _,entry in ipairs(person.history or {}) do
            if entry.members then entry.members[key]=nil end
        end
    end
    if self.trade and self:Normalize(self.trade.name) == key then self.trade = nil end
    if self:Normalize(self.tradePendingName) == key then self.tradePendingName = nil end
    if self:Normalize(self.duelOpponent) == key then self.duelOpponent = nil end
    local function pruneRun(run)
        for memberKey, name in pairs(run.members or {}) do
            if self:Normalize(name) == key then run.members[memberKey] = nil end
        end
    end
    for _, run in ipairs(self.db.runs) do pruneRun(run) end
    if self.run then pruneRun(self.run) end
    self:UIRefresh()
    return true
end

function CR:HistoryItems(person, filter, search, showEdits)
    local out = {}
    search = (search or ""):lower()
    for _, item in ipairs(person.history or {}) do
        local kindOK = (filter == "all" or item.kind == filter or (item.sessionID and ((item.counts[filter] or 0)>0 or (filter=="social" and ((item.whispersIn or 0)+(item.whispersOut or 0)>0)))))
        local visible = showEdits or filter == "note" or item.kind ~= "note"
        local text = ((item.title or "") .. " " .. self:TripText(item) .. " " .. (item.zone or "")):lower()
        if kindOK and visible and (search == "" or text:find(search, 1, true)) then out[#out+1] = item end
    end
    return out
end

function CR:Note(name, note)
    local p = self:Person(name)
    if not p or type(note) ~= "string" then return end
    note = note:sub(1, 2000)
    if note ~= p.notes then
        p.notes = note
        self:Record(name, "note", "Personal note changed", "Only visible to you", "manual")
    end
end

function CR:Tag(name, tag, enabled)
    local p = self:Person(name)
    if not p then return end
    local valid
    for _, value in ipairs(self.tags) do if value == tag then valid = true; break end end
    if not valid then self:Say("Unknown tag: " .. tostring(tag)); return end
    if enabled == nil then enabled = not p.tags[tag] end
    if (p.tags[tag] and true or false) == (enabled and true or false) then return end
    p.tags[tag] = enabled or nil
    self:Record(name, "note", (enabled and "Marked: " or "Unmarked: ") .. tag, "Personal assessment", "manual")
end

function CR:Rate(name, rating)
    local p = self:Person(name)
    rating = tonumber(rating)
    if not p or not rating or rating < 0 or rating > 5 then return end
    if p.rating == math.floor(rating) then return end
    p.rating = math.floor(rating)
    self:Record(name, "note", "Rating " .. p.rating .. "/5", "Personal assessment", "manual")
end

function CR:List(search, filter)
    local list = {}
    search = (self:SafeString(search) or ""):lower()
    for _, p in pairs(self.db.people) do
        local matches = search == "" or p.name:lower():find(search, 1, true)
            or (p.guild or ""):lower():find(search, 1, true)
            or (p.notes or ""):lower():find(search, 1, true)
        local ok = filter == "All" or not filter
            or (filter == "Friends" and (p.tags.Friend or p.tags.Helpful))
            or (filter == "Rivals" and (p.tags.Rival or p.tags["Kill on Sight"]))
            or (filter == "Avoid" and (p.tags.Avoid or p.tags["Ninja Looter"]))
        if matches and ok then table.insert(list, p) end
    end
    local mode=self.db.options.playerSort or "recent"
    local ascending=self.db.options.playerSortAscending==true
    local function value(p)
        if mode=="name" then return (p.name or ""):lower() end
        if mode=="time" then return (p.stats or {}).timeTogether or 0 end
        if mode=="groups" then return (p.stats or {}).groupSessions or 0 end
        if mode=="rating" then return p.rating or 0 end
        return p.lastSeen or 0
    end
    table.sort(list, function(a,b)
        local av,bv=value(a),value(b)
        if av==bv then
            local an,bn=(a.name or ""):lower(),(b.name or ""):lower()
            if an==bn then return (a.key or "")<(b.key or "") end
            return an<bn
        end
        if ascending then return av<bv end
        return av>bv
    end)
    return list
end

function CR:Init()
    CrossroadsPlayerMemoryDB = type(CrossroadsPlayerMemoryDB) == "table" and CrossroadsPlayerMemoryDB or {}
    self.db = CrossroadsPlayerMemoryDB
    self.db.schema = 3
    self.db.people = type(self.db.people) == "table" and self.db.people or {}
    self.db.runs = type(self.db.runs) == "table" and self.db.runs or {}
    self.db.activity = type(self.db.activity) == "table" and self.db.activity or {}
    self.db.options = type(self.db.options) == "table" and self.db.options or {}
    self.db.summary = type(self.db.summary) == "table" and self.db.summary or {}
    self:UpgradeHistoryIDs()
    self.groupSession=nil
    for _,person in pairs(self.db.people) do
        for _,entry in ipairs(person.history or {}) do
            if entry.sessionID and entry.status=="ongoing" then entry.status="interrupted by reload/logout" end
        end
    end
    self.forgotten = {}
    for k, v in pairs(self.settingsDefaults) do
        if self.db.options[k] == nil then self.db.options[k] = v end
    end
    -- Character identity and ruleset are distinct from Forever's surname.
    self.me = self:PlayerName("player") or "Unknown"
    self.meKey = self.me:lower()
    self.ruleset = self:SafeString(GetRealmName and GetRealmName()) or "Unknown"
    self.guidCache = {}
    self.group = {}
    self.lastGroupTick = self:Now()
    self.lootDedupe = {}
    self.lastPvPAlert = {}
    self:StartEvents()
    self:InstallTooltip()
    self:UpdateMinimapButton()
    self:Say("v" .. self.version .. " ready. Type |cffffffff/cr|r or |cffffffff/crmemory help|r.")
end

local function targetName()
    return CR:PlayerName("target")
end

function CR:Slash(message)
    message = self:SafeString(message) or ""
    local command, tail = message:match("^(%S+)%s*(.*)$")
    command = command and command:lower() or ""
    if command == "" or command == "open" then self:ToggleUI(); return end
    if command == "minimap" then
        local action = tail:lower()
        if action == "reset" then
            self.db.options.minimapAngle = 225
            self.db.options.minimapIcon = true
            self:Say("Minimap icon position reset and icon shown.")
        elseif action == "show" or action == "on" then
            self.db.options.minimapIcon = true
        elseif action == "hide" or action == "off" then
            self.db.options.minimapIcon = false
        else
            self.db.options.minimapIcon = not self.db.options.minimapIcon
        end
        self:UpdateMinimapButton()
        return
    end
    if command == "help" then
        self:Say("/cr | /cr target | /cr add First Surname | /cr find text | /cr options | /cr stats")
        self:Say("/cr minimap [show|hide|reset]  (minimap launcher)")
        self:Say("/cr note First Surname ; text  |  /cr rate First Surname ; 0-5")
        self:Say("/cr tag First Surname ; Friend | /cr untag First Surname ; Friend")
        self:Say("/cr death First Surname | /cr kill First Surname | /cr ninja First Surname")
        self:Say("Use 'target' instead of a name to use your selected player.")
        return
    end
    if command == "options" then self:ShowOptions(); return end
    if command == "stats" then
        local n = 0
        for _ in pairs(self.db.people) do n = n + 1 end
        self:Say(n .. " players, " .. #self.db.runs .. " dungeon/raid visits, " .. #self.db.activity .. " activity entries.")
        return
    end
    if command == "target" then
        local name = targetName()
        if not name then self:Say("Target a player first."); return end
        local p = self:FromUnit("target", true)
        if p then self:OpenUI(p.key) end
        return
    end
    if command == "add" or command == "find" then
        local name = tail == "target" and targetName() or tail
        if command == "add" then
            local key = self:Normalize(name)
            if key and self.forgotten then self.forgotten[key] = nil end
        end
        local p = (command == "find") and self:Find(name) or self:Person(name)
        if p then self:OpenUI(p.key) else self:Say("Player not found. Use /cr add First Surname") end
        return
    end
    if command == "note" or command == "rate" or command == "tag" or command == "untag" then
        local name, value = tail:match("^(.-)%s*;%s*(.+)$")
        if name == "target" then name = targetName() end
        if not name or not value then self:Say("Syntax: /cr " .. command .. " First Surname ; value"); return end
        if command == "note" then self:Note(name, value)
        elseif command == "rate" then self:Rate(name, value)
        else self:Tag(name, value, command == "tag") end
        return
    end
    if command == "death" or command == "kill" or command == "ninja" then
        local name = tail == "target" and targetName() or tail
        if not name or name == "" then self:Say("Select a target or enter a full name."); return end
        if command == "ninja" then self:Tag(name, "Ninja Looter", true) end
        if command == "death" then self:Stat(name, "deathsTo", 1) end
        if command == "kill" then self:Stat(name, "killsOf", 1) end
        self:Record(name, command == "ninja" and "loot" or "pvp", "Manual report: " .. command, "Unverified user entry", "manual")
        return
    end
    self:Say("Unknown command. Type /cr help")
end

SLASH_CROSSROADSPLAYERMEMORY1 = "/crmemory"
SLASH_CROSSROADSPLAYERMEMORY2 = "/crossroadsmemory"
-- Keep prototype shortcuts only when the unrelated addon is not installed.
local otherInstalled = C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Crossroads")
if not otherInstalled then
    SLASH_CROSSROADSPLAYERMEMORY3 = "/cr"
    SLASH_CROSSROADSPLAYERMEMORY4 = "/crossroads"
end
SlashCmdList.CROSSROADSPLAYERMEMORY = function(message)
    if CR.db then CR:Slash(message) end
end
