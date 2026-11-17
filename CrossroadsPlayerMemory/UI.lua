local addonName, CR = ...
local W, optionsWindow

local function panel(parent, width, height, name)
    local obj = CreateFrame("Frame", name, parent, "BackdropTemplate")
    obj:SetSize(width, height)
    obj:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=18,
        insets={left=4,right=4,top=4,bottom=4}})
    obj:SetBackdropColor(0.035,0.05,0.065,0.98)
    return obj
end
local function label(parent, font, text, x, y, width, height)
    local s = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetSize(width or 100, height or 18)
    s:SetJustifyH("LEFT"); s:SetJustifyV("TOP"); s:SetText(text or "")
    return s
end
local function button(parent, caption, x, y, width, height, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 90, height or 24); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(caption); b:SetScript("OnClick", callback)
    return b
end
local function entry(parent, x, y, width, height)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width,height or 24); e:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    return e
end
local function scrollArea(parent, x, y, width, height)
    local box = panel(parent,width,height)
    box:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    local scroll = CreateFrame("ScrollFrame",nil,box,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",box,"TOPLEFT",8,-8)
    scroll:SetPoint("BOTTOMRIGHT",box,"BOTTOMRIGHT",-28,8)
    local child = CreateFrame("Frame",nil,scroll)
    child:SetSize(width-40,height-16); scroll:SetScrollChild(child)
    return scroll, child
end

function CR:ConfirmDelete(text, callback)
    if not W then return end
    if not W.confirm then
        local overlay = CreateFrame("Frame",nil,W,"BackdropTemplate")
        overlay:SetAllPoints(W); overlay:EnableMouse(true)
        overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
        overlay:SetBackdropColor(0,0,0,0.8)
        local dialog = panel(overlay,490,230); dialog:SetPoint("CENTER")
        label(dialog,"GameFontNormalLarge","Confirm deletion",20,-18,450,25)
        overlay.message=label(dialog,"GameFontHighlight","",20,-56,450,114)
        overlay.accept=button(dialog,"Delete",248,-184,105,27,function()
            local action=overlay.action; overlay.action=nil; overlay:Hide()
            if action then action() end
        end)
        overlay.cancel=button(dialog,"Cancel",363,-184,105,27,function() overlay.action=nil; overlay:Hide() end)
        W.confirm=overlay
    end
    W.confirm.message:SetText(text); W.confirm.action=callback; W.confirm:Show()
end

function CR:SelectPerson(key)
    if W.selected ~= key then
        W.selected=key; W.notesFor=nil
        W.historyScroll:SetVerticalScroll(0)
    end
    self:UIRefresh()
end

function CR:BuildUI()
    if W then return end
    W=panel(UIParent,900,660,"CrossroadsPlayerMemoryMainWindow")
    self.window=W
    W:SetPoint("CENTER"); W:SetFrameStrata("DIALOG"); W:EnableMouse(true)
    local function fitScreen()
        W:SetScale(math.min(1, math.max(0.1,(UIParent:GetWidth()-24)/900), math.max(0.1,(UIParent:GetHeight()-24)/660)))
    end
    fitScreen(); UIParent:HookScript("OnSizeChanged",fitScreen)
    W:SetMovable(true); W:SetClampedToScreen(true); W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart",W.StartMoving); W:SetScript("OnDragStop",W.StopMovingOrSizing)
    W:Hide(); table.insert(UISpecialFrames,"CrossroadsPlayerMemoryMainWindow")
    W:SetScript("OnHide",function() if W.confirm then W.confirm.action=nil; W.confirm:Hide() end end)
    label(W,"GameFontNormalHuge","C R O S S R O A D S",20,-16,600,30)
    label(W,"GameFontDisableSmall","Player Memory  |  " .. self.version,23,-47,500,18)
    button(W,"Options",744,-17,85,27,function() CR:ShowOptions() end)
    button(W,"X",843,-17,35,27,function() W:Hide() end)

    W.countLabel=label(W,"GameFontHighlightSmall","",20,-85,237,18)
    label(W,"GameFontDisableSmall","Search players, guilds or notes",20,-111,235,16)
    W.search=entry(W,24,-133,225,24)
    W.search:SetScript("OnTextChanged",function(_,byUser)
        if byUser then W.listScroll:SetVerticalScroll(0); CR:UIRefresh() end
    end)
    W.filters={}; W.filter="All"; W.drafts={}
    for i,name in ipairs({"All","Friends","Rivals","Avoid"}) do
        W.filters[name]=button(W,name,18+(i-1)*60,-169,58,24,function()
            W.filter=name; W.listScroll:SetVerticalScroll(0); CR:UIRefresh()
        end)
    end
    W.listScroll,W.listChild=scrollArea(W,12,-204,248,438)
    W.rows={}

    local detail=panel(W,615,566); detail:SetPoint("TOPRIGHT",W,"TOPRIGHT",-12,-76)
    W.detail=detail
    W.playerTitle=label(detail,"GameFontNormalLarge","Select a player",16,-14,455,26)
    W.deletePlayer=button(detail,"Delete player",480,-12,119,25,function()
        local key=W.selected; local person=key and CR.db.people[key]
        if not person then return end
        CR:ConfirmDelete("Delete " .. person.name .. "?\n\nRemoves their profile, notes, tags, totals and saved history. Cannot be undone.\n\nAutomatic recording pauses for this player until your next login or /reload. /crmemory add can add them again.",function()
            if CR.db.people[key] ~= person then return end
            W.drafts[key]=nil; CR:DeletePerson(key)
        end)
    end)
    W.playerInfo=label(detail,"GameFontHighlightSmall","",16,-45,580,31)
    W.cards={}
    local captions={"TIME TOGETHER","GROUP SESSIONS","DUNGEON / RAID VISITS"}
    for i,caption in ipairs(captions) do
        local card=panel(detail,188,70); card:SetPoint("TOPLEFT",detail,"TOPLEFT",16+(i-1)*197,-83)
        card.caption=label(card,"GameFontNormalSmall",caption,10,-9,170,16)
        card.value=label(card,"GameFontHighlightLarge","",10,-28,170,23)
        card.hint=label(card,"GameFontDisableSmall","",10,-52,170,14)
        W.cards[i]=card
    end
    W.playerStats=label(detail,"GameFontHighlightSmall","",18,-163,578,32)
    W.tabs={}; W.tab="history"
    for i,spec in ipairs({{"history","History"},{"notes","Notes & tags"}}) do
        W.tabs[spec[1]]=button(detail,spec[2],16+(i-1)*143,-203,136,26,function()
            W.tab=spec[1]; CR:UIRefresh()
        end)
    end
    W.tabHint=label(detail,"GameFontDisableSmall","Newest first",332,-210,262,18)
    W.historyPane=CreateFrame("Frame",nil,detail); W.historyPane:SetSize(599,324)
    W.historyPane:SetPoint("TOPLEFT",detail,"TOPLEFT",8,-234)
    W.historyFilter="all"; W.historyFilters={}
    local filters={{"all","All"},{"group","Groups"},{"quest","Quests"},{"dungeon","Dungeons"},{"pvp","PvP"},
        {"loot","Loot"},{"trade","Trades"},{"social","Social"},{"sight","Encounters"},{"note","Personal"}}
    for i,spec in ipairs(filters) do
        W.historyFilters[spec[1]]=button(W.historyPane,spec[2],8+((i-1)%5)*116,-math.floor((i-1)/5)*26,110,23,function()
            W.historyFilter=spec[1]; W.historyScroll:SetVerticalScroll(0); CR:UIRefresh()
        end)
    end
    W.historySearch=entry(W.historyPane,12,-60,234,23)
    W.historySearch:SetScript("OnTextChanged",function(_,byUser)
        if byUser then W.historyScroll:SetVerticalScroll(0); CR:UIRefresh() end
    end)
    W.showEdits=CreateFrame("CheckButton",nil,W.historyPane,"UICheckButtonTemplate")
    W.showEdits:SetPoint("TOPLEFT",W.historyPane,"TOPLEFT",260,-55)
    W.showEdits:SetChecked(false)
    label(W.historyPane,"GameFontHighlightSmall","Show profile edits",293,-63,160,18)
    W.showEdits:SetScript("OnClick",function() W.historyScroll:SetVerticalScroll(0); CR:UIRefresh() end)
    W.clearHistory=button(W.historyPane,"Clear history",466,-58,118,24,function()
        local key=W.selected; local person=key and CR.db.people[key]
        if not person then return end
        CR:ConfirmDelete("Clear ALL history for " .. person.name .. "?\n\nThis includes entries hidden by filters. Notes, tags, ratings, totals and trade snapshots are kept.\n\nCannot be undone.",function()
            if CR.db.people[key] == person then CR:ClearHistory(key) end
        end)
    end)
    W.historyCount=label(W.historyPane,"GameFontDisableSmall","",12,-89,565,16)
    W.historyScroll,W.historyChild=scrollArea(W.historyPane,0,-111,592,209)
    W.historyRows={}
    W.historyEmpty=label(W.historyChild,"GameFontHighlight","",12,-16,510,75)

    W.notesPane=CreateFrame("Frame",nil,detail); W.notesPane:SetSize(583,324)
    W.notesPane:SetPoint("TOPLEFT",detail,"TOPLEFT",16,-234)
    label(W.notesPane,"GameFontNormalSmall","Rating",0,-4,65,20)
    W.stars={}
    for i=0,5 do W.stars[i]=button(W.notesPane,tostring(i),75+i*43,0,39,24,function()
        if W.selected then CR:Rate(W.selected,i) end
    end) end
    label(W.notesPane,"GameFontNormalSmall","Personal tags",0,-37,400,18)
    W.tagButtons={}
    for i,tag in ipairs(CR.tags) do
        W.tagButtons[tag]=button(W.notesPane,tag,((i-1)%3)*195,-60-math.floor((i-1)/3)*28,187,25,function()
            if W.selected then CR:Tag(W.selected,tag) end
        end)
    end
    label(W.notesPane,"GameFontNormalSmall","Private notes",0,-151,420,18)
    local noteScroll,noteChild=scrollArea(W.notesPane,0,-175,583,101)
    W.notes=CreateFrame("EditBox",nil,noteChild)
    W.notes:SetPoint("TOPLEFT",noteChild,"TOPLEFT",4,-4); W.notes:SetWidth(531)
    W.notes:SetHeight(85)
    W.notes:SetMultiLine(true); W.notes:SetMaxLetters(2000); W.notes:SetAutoFocus(false)
    W.notes:SetFontObject("ChatFontNormal"); W.notes:SetTextInsets(0,0,0,0)
    W.notes:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    W.notes:SetScript("OnTextChanged",function(self,byUser)
        if byUser and W.notesFor then W.drafts[W.notesFor]=self:GetText(); W.noteStatus:SetText("Unsaved changes") end
        noteChild:SetHeight(math.max(85,self:GetHeight()+8))
    end)
    W.noteStatus=label(W.notesPane,"GameFontDisableSmall","Only visible to you",0,-291,430,18)
    W.saveNote=button(W.notesPane,"Save note",458,-286,125,26,function()
        if W.selected then
            CR:Note(W.selected,W.notes:GetText()); W.drafts[W.selected]=nil
            W.noteStatus:SetText("Note saved"); W.notes:ClearFocus()
        end
    end)
    W:SetScript("OnShow",function() CR:UIRefresh() end)
end

function CR:UIRefresh()
    if not W or not W:IsShown() or not self.db then return end
    local list=self:List(W.search:GetText(),W.filter)
    local count=math.min(#list,300)
    W.countLabel:SetText(count .. " of " .. #list .. " players")
    local selectedVisible=false
    for _,person in ipairs(list) do if person.key==W.selected then selectedVisible=true; break end end
    if not selectedVisible then
        W.selected=list[1] and list[1].key or nil; W.notesFor=nil
        W.historyScroll:SetVerticalScroll(0)
    end
    for name,b in pairs(W.filters) do if name==W.filter then b:LockHighlight() else b:UnlockHighlight() end end
    for i=1,count do
        local person=list[i]; local row=W.rows[i]
        if not row then
            row=CreateFrame("Button",nil,W.listChild); row:SetSize(208,45)
            row:SetPoint("TOPLEFT",W.listChild,"TOPLEFT",0,-(i-1)*47)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.name=label(row,"GameFontHighlightSmall","",6,-5,197,18)
            row.meta=label(row,"GameFontDisableSmall","",6,-25,197,15)
            row:SetScript("OnClick",function(self) CR:SelectPerson(self.playerKey) end)
            W.rows[i]=row
        end
        row.playerKey=person.key
        local marker=person.tags.Avoid and "|cffff7766! |r" or person.tags.Rival and "|cffffb36b! |r" or person.tags.Friend and "|cff66dd88+ |r" or ""
        row.name:SetText(marker .. person.name)
        row.meta:SetText(self:FormatDuration(person.stats.timeTogether) .. " together  |  " .. (person.rating or 0) .. "/5")
        if person.key==W.selected then row:LockHighlight() else row:UnlockHighlight() end
        row:Show()
    end
    for i=count+1,#W.rows do W.rows[i]:Hide() end
    W.listChild:SetHeight(math.max(422,count*47))
    local person=W.selected and self.db.people[W.selected]
    W.deletePlayer:SetEnabled(person~=nil); W.saveNote:SetEnabled(person~=nil)
    for _,b in pairs(W.stars) do b:SetEnabled(person~=nil) end
    for _,b in pairs(W.tagButtons) do b:SetEnabled(person~=nil) end
    for key,b in pairs(W.tabs) do if key==W.tab then b:LockHighlight() else b:UnlockHighlight() end end
    W.historyPane:SetShown(W.tab=="history"); W.notesPane:SetShown(W.tab=="notes")
    W.tabHint:SetText(W.tab=="history" and "Newest first  |  click entry for details" or "Private notes and personal assessments")
    if not person then
        W.playerTitle:SetText("No player selected"); W.playerInfo:SetText("Select a player, or adjust your search and filters.")
        W.playerStats:SetText("")
        for _,card in ipairs(W.cards) do card.value:SetText("—"); card.hint:SetText("") end
        W.notesFor=nil; W.notes:SetText(""); W.noteStatus:SetText("Only visible to you")
        W.historyCount:SetText("No entries"); W.clearHistory:Disable()
        for _,row in ipairs(W.historyRows) do row:Hide() end
        W.historyChild:SetHeight(193); W.historyEmpty:SetText("Your history will appear here."); W.historyEmpty:Show()
        return
    end
    W.playerTitle:SetText(person.name .. (person.partial and " (partial name)" or ""))
    W.playerInfo:SetText((person.level and ("Level "..person.level.."  ") or "") .. (person.race or "") .. " " .. (person.class or "") .. (person.guild and ("  <"..person.guild..">") or "")
        .. "\nFirst met " .. self:Date(person.firstSeen) .. "  |  " .. (person.firstZone or "Unknown"))
    local stats=person.stats or {}
    W.cards[1].value:SetText(self:FormatDuration(stats.timeTogether)); W.cards[1].hint:SetText("Approximate grouped time")
    W.cards[2].value:SetText(tostring(stats.groupSessions or 0)); W.cards[2].hint:SetText("Recorded party / raid sessions")
    W.cards[3].value:SetText(tostring(stats.dungeonRuns or 0)); W.cards[3].hint:SetText((stats.bossKills or 0) .. " boss kills recorded")
    W.playerStats:SetText("Quests: " .. (stats.groupQuests or 0) .. "   |   Loot wins: " .. (stats.lootWins or 0) .. "   |   Trades: " .. (stats.tradeWindows or 0)
        .. "\nPvP: " .. (stats.killsOf or 0) .. " kills / " .. (stats.deathsTo or 0) .. " deaths   |   Whispers: " .. (stats.whispersReceived or 0) .. " in / " .. (stats.whispersSent or 0) .. " out")
    for i,b in pairs(W.stars) do if person.rating==i then b:LockHighlight() else b:UnlockHighlight() end end
    for tag,b in pairs(W.tagButtons) do if person.tags[tag] then b:LockHighlight() else b:UnlockHighlight() end end
    if W.notesFor~=person.key then
        W.notesFor=person.key; W.notes:SetText(W.drafts[person.key] or person.notes or "")
        W.noteStatus:SetText(W.drafts[person.key] and "Unsaved changes" or "Only visible to you")
    end
    for kind,b in pairs(W.historyFilters) do if kind==W.historyFilter then b:LockHighlight() else b:UnlockHighlight() end end
    local items=self:HistoryItems(person,W.historyFilter,W.historySearch:GetText(),W.showEdits:GetChecked())
    W.historyCount:SetText(#items .. " shown / " .. #person.history .. " saved  |  Search titles, places and details")
    W.clearHistory:SetEnabled(#person.history>0)
    W.historyEmpty:SetShown(#items==0)
    W.historyEmpty:SetText(#person.history==0 and "No saved history for this player yet." or "No matching entries. Try All, clear the search, or select Personal to see profile edits.")
    local offset=0; local lastDay
    for i,item in ipairs(items) do
        local row=W.historyRows[i]
        if not row then
            row=CreateFrame("Frame",nil,W.historyChild); row:SetWidth(552); row:EnableMouse(true)
            row:SetScript("OnMouseUp",function(_,mouseButton)
                if mouseButton == "LeftButton" then
                    if W.expandedEntry==row.entry then W.expandedEntry=nil else W.expandedEntry=row.entry end
                    CR:UIRefresh()
                end
            end)
            row.day=label(row,"GameFontNormalSmall","",4,0,530,18)
            row.title=label(row,"GameFontHighlight","",4,0,469,34)
            row.meta=label(row,"GameFontDisableSmall","",4,0,469,17)
            row.detail=label(row,"GameFontHighlightSmall","",4,0,469,34)
            row.remove=button(row,"Delete",480,0,65,23,function()
                local key,entry,owner=row.playerKey,row.entry,row.person
                CR:ConfirmDelete("Delete this entry for " .. owner.name .. "?\n\n" .. (entry.title or entry.kind) .. "\n\nOnly this timeline entry is removed. Totals, notes, labels and trade snapshots are unchanged. Cannot be undone.",function()
                    if CR.db.people[key]==owner then CR:DeleteHistoryEntry(key,entry) end
                end)
            end)
            W.historyRows[i]=row
        end
        row.playerKey=person.key; row.person=person; row.entry=item
        local day=date("%d %b %Y",item.when); local newDay=day~=lastDay
        local top=newDay and 24 or 4; lastDay=day
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",W.historyChild,"TOPLEFT",0,-offset)
        row.day:SetShown(newDay); row.day:SetText(day)
        row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT",row,"TOPLEFT",4,-top)
        row.title:SetText((W.expandedEntry==item and "- " or "+ ") .. (CR.types[item.kind] or item.kind) .. "  ·  " .. (item.title or item.kind))
        local titleHeight=math.max(16,math.min(34,row.title:GetStringHeight()))
        row.meta:ClearAllPoints(); row.meta:SetPoint("TOPLEFT",row,"TOPLEFT",4,-top-titleHeight-2)
        row.meta:SetText(date("%H:%M",item.when) .. "  |  " .. (item.zone or "Unknown") .. "  |  " .. (item.confidence or "observed"))
        row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT",row,"TOPLEFT",4,-top-titleHeight-22)
        row.detail:SetText(item.detail or "")
        local expanded=W.expandedEntry==item
        row.detail:SetShown(expanded)
        local detailHeight=expanded and math.max(34,row.detail:GetStringHeight()) or 0
        row.detail:SetHeight(math.max(34,detailHeight))
        row.remove:ClearAllPoints(); row.remove:SetPoint("TOPLEFT",row,"TOPLEFT",480,-top)
        local height=top+titleHeight+26+detailHeight; row:SetHeight(height); offset=offset+height+5; row:Show()
    end
    for i=#items+1,#W.historyRows do W.historyRows[i]:Hide() end
    W.historyChild:SetHeight(math.max(193,offset))
    W.historyScroll:SetVerticalScroll(math.min(W.historyScroll:GetVerticalScroll(),math.max(0,offset-193)))
end

function CR:OpenUI(key)
    self:BuildUI()
    if key and self.db.people[key] then W.selected=key; W.notesFor=nil; W.historyScroll:SetVerticalScroll(0) end
    W:Show(); self:UIRefresh()
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
    label(frame,"GameFontNormalLarge","CROSSROADS SETTINGS",18,-15,390,29)
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
