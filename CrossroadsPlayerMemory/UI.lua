local addonName, CR = ...
local W, optionsWindow
local PAGE_COLOR = {0.1, 0.13, 0.17}

local function panel(parent, width, height, name)
    local obj = CreateFrame("Frame", name, parent, "BackdropTemplate")
    obj:SetSize(width, height)
    obj:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=18,
        insets={left=4,right=4,top=4,bottom=4}})
    obj:SetBackdropColor(0.065,0.09,0.13,0.98)
    return obj
end
local function label(parent, size, content, x, y, width, height)
    local s = parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetSize(width or 100, height or 18)
    s:SetJustifyH("LEFT")
    s:SetJustifyV("TOP")
    s:SetText(content or "")
    return s
end
local function button(parent, caption, x, y, width, height, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 90, height or 24)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(caption)
    b:SetScript("OnClick", callback)
    return b
end
local function entry(parent, x,y, w,h)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w,h or 24)
    e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    e:SetAutoFocus(false)
    return e
end

function CR:BuildUI()
    if W then return end
    W = panel(UIParent, 880, 615, "CrossroadsPlayerMemoryMainWindow")
    W:SetPoint("CENTER")
    W:SetFrameStrata("DIALOG")
    W:EnableMouse(true)
    W:SetMovable(true)
    W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", W.StartMoving)
    W:SetScript("OnDragStop", W.StopMovingOrSizing)
    W:Hide()
    table.insert(UISpecialFrames, "CrossroadsPlayerMemoryMainWindow") -- close via Escape, if named below

    label(W, "GameFontNormalHuge", "C R O S S R O A D S", 20,-13,490,31)
    label(W, "GameFontDisableSmall", "Every player has a story.", 25,-46,420,19)
    button(W,"Options",730,-15,73,27,function() CR:ShowOptions() end)
    button(W,"X",818,-15,40,27,function() W:Hide() end)
    W.countLabel = label(W,"GameFontHighlightSmall","",20,-82,285,20)

    local search = entry(W, 20,-105,269,25)
    search:SetScript("OnTextChanged",function(self, byUser)
        if byUser then CR:UIRefresh() end
    end)
    W.search = search
    W.filters = {}
    for i, fName in ipairs({"All","Friends","Rivals","Avoid"}) do
        W.filters[fName] = button(W,fName, 20+(i-1)*70,-139,67,23,function()
            W.filter=fName
            CR:UIRefresh()
        end)
    end
    W.filter="All"

    local left = panel(W,299,416)
    left:SetPoint("TOPLEFT",W,"TOPLEFT",12,-171)
    local sc = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
    sc:SetPoint("TOPLEFT",left,"TOPLEFT",8,-8)
    sc:SetPoint("BOTTOMRIGHT",left,"BOTTOMRIGHT",-28,8)
    local child = CreateFrame("Frame", nil, sc)
    child:SetSize(257,390)
    sc:SetScrollChild(child)
    W.listChild=child
    W.listScroll=sc
    W.rows={}

    local detail = panel(W,550,511)
    detail:SetPoint("TOPRIGHT",W,"TOPRIGHT",-12,-76)
    W.detail=detail
    W.playerTitle=label(detail,"GameFontNormalLarge","Select a player",17,-13,500,25)
    W.playerInfo=label(detail,"GameFontHighlightSmall","",17,-42,508,28)
    W.playerStats=label(detail,"GameFontHighlight","",17,-72,514,57)
    label(detail,"GameFontNormalSmall","Rating",17,-140,50,20)
    W.stars={}
    for i=0,5 do
        W.stars[i] = button(detail,tostring(i),75+i*40,-136,38,23,function()
            if W.selected then CR:Rate(W.selected,i) end
        end)
    end
    label(detail,"GameFontNormalSmall","Personal tags",17,-171,220,18)
    W.tagButtons={}
    for i,tag in ipairs(CR.tags) do
        local col=(i-1)%3
        local row=math.floor((i-1)/3)
        W.tagButtons[tag] = button(detail,tag,17+col*173,-188-row*27,164,24,function()
            if W.selected then CR:Tag(W.selected,tag) end
        end)
    end
    label(detail,"GameFontNormalSmall","Private notes (never shared)",17,-281,410,20)
    local noteBg = CreateFrame("Frame",nil,detail,"BackdropTemplate")
    noteBg:SetPoint("TOPLEFT",detail,"TOPLEFT",16,-303)
    noteBg:SetSize(510,62)
    noteBg:SetBackdrop({bgFile="Interface\\ChatFrame\\ChatFrameBackground"})
    noteBg:SetBackdropColor(0.02,0.03,0.06,0.95)
    W.notes = CreateFrame("EditBox",nil,noteBg)
    W.notes:SetPoint("TOPLEFT",noteBg,"TOPLEFT",6,-6)
    W.notes:SetSize(499,52)
    W.notes:SetMultiLine(true)
    W.notes:SetMaxLetters(2000)
    W.notes:SetAutoFocus(false)
    W.notes:SetFontObject("ChatFontNormal")
    W.notes:SetTextInsets(0,0,0,0)
    W.notes:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    button(detail,"Save note",413,-373,112,23,function()
        if W.selected then CR:Note(W.selected,W.notes:GetText()); W.notes:ClearFocus() end
    end)

    label(detail,"GameFontNormalSmall","Your history / timeline",17,-376,342,20)
    local history = panel(detail,512,105)
    history:SetPoint("TOPLEFT",detail,"TOPLEFT",16,-401)
    local hs = CreateFrame("ScrollFrame",nil,history,"UIPanelScrollFrameTemplate")
    hs:SetPoint("TOPLEFT",history,"TOPLEFT",8,-8)
    hs:SetPoint("BOTTOMRIGHT",history,"BOTTOMRIGHT",-28,7)
    local hc = CreateFrame("Frame",nil,hs)
    hc:SetSize(468,85)
    hs:SetScrollChild(hc)
    W.historyChild=hc
    W.historyScroll=hs
    W.historyRows={}
    W:SetScript("OnShow",function() CR:UIRefresh() end)
end

function CR:UIRefresh()
    if not W or not W:IsShown() or not self.db then return end
    local list = self:List(W.search:GetText(), W.filter)
    local visibleCount = math.min(#list, 300)
    W.countLabel:SetText(visibleCount .. " of " .. #list .. " matching players" .. (#list > 300 and " (search to narrow)" or ""))
    for name, b in pairs(W.filters) do
        if W.filter == name then b:LockHighlight() else b:UnlockHighlight() end
    end
    for i=1,visibleCount do
        local p=list[i]
        local row = W.rows[i]
        if not row then
            row=CreateFrame("Button",nil,W.listChild)
            row:SetSize(255,27)
            row:SetPoint("TOPLEFT",W.listChild,"TOPLEFT",1,-2-(i-1)*29)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.text=label(row,"GameFontHighlightSmall","",5,-5,242,23)
            row:SetScript("OnClick",function(self)
                W.selected=self.playerKey
                CR:UIRefresh()
            end)
            W.rows[i]=row
        end
        row.playerKey=p.key
        local marker = p.tags["Kill on Sight"] and "|cffff5555! |r"
            or p.tags["Ninja Looter"] and "|cffff9966! |r"
            or (p.tags.Friend or p.tags.Helpful) and "|cff66dd88+ |r" or ""
        row.text:SetText(marker .. p.name)
        if p.key == W.selected then row:LockHighlight() else row:UnlockHighlight() end
        row:Show()
    end
    for i=visibleCount+1,#W.rows do W.rows[i]:Hide() end
    W.listChild:SetHeight(math.max(390,visibleCount*29+6))
    if not W.selected and #list > 0 then W.selected=list[1].key end
    local p=W.selected and self.db.people[W.selected]
    if not p then
        W.playerTitle:SetText("Select a player")
        W.playerInfo:SetText("Your personal history begins here.")
        W.playerStats:SetText("")
        for _,b in pairs(W.tagButtons) do b:Disable() end
        W.notes:SetText("")
        for _,s in ipairs(W.historyRows) do s:Hide() end
        return
    end
    for _,b in pairs(W.tagButtons) do b:Enable() end
    W.playerTitle:SetText(p.name .. (p.partial and " (partial name)" or ""))
    W.playerInfo:SetText((p.level and ("Lv " .. p.level .. "  ") or "") .. (p.race or "") .. " " .. (p.class or "")
        .. (p.guild and ("  <" .. p.guild .. ">") or "")
        .. "\nFirst encounter: " .. self:Date(p.firstSeen) .. " in " .. (p.firstZone or "Unknown"))
    local s=p.stats or {}
    W.playerStats:SetText(string.format(
        "Groups: %d  •  Together: %d min  •  Group quests: %d  •  Dungeons: %d\nPvP: killed you %d / you killed them %d  •  Loot wins: %d\nWhispers: %d in / %d out  •  Trades opened: %d",
        s.groupSessions or 0, math.floor((s.timeTogether or 0)/60), s.groupQuests or 0,
        s.dungeonRuns or 0, s.deathsTo or 0, s.killsOf or 0, s.lootWins or 0,
        s.whispersReceived or 0, s.whispersSent or 0, s.tradeWindows or 0))
    for i,b in pairs(W.stars) do
        if p.rating == i then b:LockHighlight() else b:UnlockHighlight() end
    end
    for name,b in pairs(W.tagButtons) do
        if p.tags and p.tags[name] then b:LockHighlight() else b:UnlockHighlight() end
    end
    if W.notesFor ~= p.key then
        W.notesFor=p.key
        W.notes:SetText(p.notes or "")
    end
    local items=p.history or {}
    for i,ev in ipairs(items) do
        local r=W.historyRows[i]
        if not r then
            r=W.historyChild:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            r:SetWidth(454)
            r:SetHeight(40)
            r:SetJustifyH("LEFT")
            r:SetJustifyV("TOP")
            r:SetPoint("TOPLEFT",W.historyChild,"TOPLEFT",3,-(i-1)*43)
            W.historyRows[i]=r
        end
        local readable = (ev.confidence == "manual") and " |cffffb36b(manual)|r"
            or (ev.confidence == "confirmed") and " |cff8be8a2(confirmed)|r" or ""
        r:SetText("|cffcba96a" .. self:Date(ev.when) .. "|r " .. (ev.title or ev.kind) .. readable
            .. "\n|cffaaaaaa" .. (ev.zone or "") .. " | " .. (ev.detail or "") .. "|r")
        r:Show()
    end
    for i=#items+1,#W.historyRows do W.historyRows[i]:Hide() end
    W.historyChild:SetHeight(math.max(85,#items*43+6))
end

function CR:OpenUI(key)
    self:BuildUI()
    if key and self.db.people[key] then W.selected=key; W.notesFor=nil end
    W:Show()
    self:UIRefresh()
end

function CR:ToggleUI()
    self:BuildUI()
    if W:IsShown() then W:Hide() else self:OpenUI() end
end

function CR:ShowOptions()
    self:BuildUI()
    if optionsWindow then
        if optionsWindow:IsShown() then optionsWindow:Hide() else optionsWindow:Show() end
        return
    end
    local frame=panel(UIParent,465,465)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart",frame.StartMoving)
    frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
    optionsWindow=frame
    label(frame,"GameFontNormalLarge","CROSSROADSPLAYERMEMORY SETTINGS",18,-15,390,29)
    button(frame,"X",415,-12,32,25,function() frame:Hide() end)
    local names = {
        {"groups","Group sessions and time together"},
        {"quests","Accepted/completed quests in groups"},
        {"instances","Dungeon and raid history"},
        {"pvp","PvP deaths and verified kills"},
        {"loot","Group loot roll history"},
        {"trades","Trade attempts"},
        {"social","Whispers (counts only, no text)"},
        {"sight","Record when you target players"},
        {"alerts","Warn about recognized rivals"},
        {"tooltips","Show profile info in tooltips"},
        {"chatCounts","Count party chat messages"},
        {"minimapIcon","Show minimap button"},
    }
    for i, spec in ipairs(names) do
        local cb=CreateFrame("CheckButton",nil,frame,"UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT",frame,"TOPLEFT",20,-52-(i-1)*32)
        cb:SetChecked(self.db.options[spec[1]])
        label(frame,"GameFontHighlightSmall",spec[2],56,-60-(i-1)*32,385,21)
        cb:SetScript("OnClick",function(self)
            if spec[1] == "groups" then CR:GroupTick() end
            CR.db.options[spec[1]] = self:GetChecked() and true or false
            if spec[1] == "groups" then CR.group = {}; CR:TrackGroup() end
            if spec[1] == "minimapIcon" then CR:UpdateMinimapButton() end
            CR:UIRefresh()
        end)
    end
    frame:Show()
end
