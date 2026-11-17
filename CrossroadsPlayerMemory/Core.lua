local addonName, CR = ...
_G.CrossroadsPlayerMemoryLocal = CR
CR.version = "0.2.1-alpha"
CR.settingsDefaults = {
    groups = true, quests = true, instances = true, pvp = true,
    loot = true, trades = true, social = true, sight = true,
    alerts = true, tooltips = true, chatCounts = false, minimapIcon = true,
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
    if not key then return nil end
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
    local entry = {
        when=self:Now(), kind=kind, title=title or kind,
        detail=(self:SafeString(detail) or ""):sub(1, 240),
        zone=self:Zone(), confidence=confidence or "observed", by=self.me or "Unknown",
    }
    table.insert(p.history, 1, entry)
    while #p.history > 100 do table.remove(p.history) end
    p.lastSeen, p.lastZone = entry.when, entry.zone
    table.insert(self.db.activity, 1, {key=p.key, name=p.name, when=entry.when, kind=kind, title=title})
    while #self.db.activity > 1500 do table.remove(self.db.activity) end
    if not silent and self.UIRefresh then self:UIRefresh() end
    return p
end

function CR:Stat(name, field, delta)
    local p = self:Person(name)
    if p then p.stats[field] = (p.stats[field] or 0) + (delta or 1) end
    return p
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
    p.tags[tag] = enabled or nil
    self:Record(name, "note", (enabled and "Marked: " or "Unmarked: ") .. tag, "Personal assessment", "manual")
end

function CR:Rate(name, rating)
    local p = self:Person(name)
    rating = tonumber(rating)
    if not p or not rating or rating < 0 or rating > 5 then return end
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
    table.sort(list, function(a,b)
        if a.lastSeen == b.lastSeen then return a.name < b.name end
        return a.lastSeen > b.lastSeen
    end)
    return list
end

function CR:Init()
    CrossroadsPlayerMemoryDB = type(CrossroadsPlayerMemoryDB) == "table" and CrossroadsPlayerMemoryDB or {}
    self.db = CrossroadsPlayerMemoryDB
    self.db.schema = 2
    self.db.people = type(self.db.people) == "table" and self.db.people or {}
    self.db.runs = type(self.db.runs) == "table" and self.db.runs or {}
    self.db.activity = type(self.db.activity) == "table" and self.db.activity or {}
    self.db.options = type(self.db.options) == "table" and self.db.options or {}
    self.db.summary = type(self.db.summary) == "table" and self.db.summary or {}
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
