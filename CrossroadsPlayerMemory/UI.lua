local addonName, CR = ...
local W, optionsWindow

local function panel(parent, width, height, name)
    local obj = CreateFrame("Frame", name, parent, "BackdropTemplate")
    obj:SetSize(width, height)
    obj:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1,
        insets={left=1,right=1,top=1,bottom=1}})
    obj:SetBackdropColor(0.035,0.05,0.065,0.98)
    obj:SetBackdropBorderColor(0.18,0.22,0.25,1)
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
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 90, height or 24); b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    b:SetBackdropColor(0.07,0.09,0.11,1)
    b:SetNormalFontObject("GameFontHighlightSmall")
    b:SetHighlightFontObject("GameFontNormalSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    b:SetText(caption); b:SetScript("OnClick", callback)
    b.LockHighlight=function(self) self.active=true; self:SetBackdropColor(0.18,0.21,0.22,1) end
    b.UnlockHighlight=function(self) self.active=false; self:SetBackdropColor(0.07,0.09,0.11,1) end
    b:SetScript("OnEnter",function(self) if not self.active then self:SetBackdropColor(0.12,0.15,0.17,1) end end)
    b:SetScript("OnLeave",function(self) if not self.active then self:UnlockHighlight() end end)
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

local function closeMenus()
    if W then for _,menu in ipairs(W.menus or {}) do menu:Hide() end end
end
local function menu(parent, width, height, x, y)
    local m=panel(parent,width,height)
    m:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    m:SetFrameLevel(parent:GetFrameLevel()+30); m:EnableMouse(true); m:Hide()
    W.menus[#W.menus+1]=m
    return m
end
local function toggleMenu(m)
    local wasShown=m:IsShown(); closeMenus()
    if not wasShown then m:Show() end
end

function CR:ConfirmDelete(text, callback)
    if not W then return end
    closeMenus()
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
    closeMenus()
    if W.eventDialog then W.eventDialog:Hide() end
    if W.selected ~= key then
        W.selected=key; W.notesFor=nil
        W.historyScroll:SetVerticalScroll(0)
    end
    self:UIRefresh()
end

function CR:ShowHistoryEntry(key, item)
    local person=self.db.people[key]
    if not person then return end
    closeMenus()
    if not W.eventDialog then
        local overlay=CreateFrame("Frame",nil,W,"BackdropTemplate")
        overlay:SetAllPoints(W); overlay:EnableMouse(true); overlay:SetFrameStrata("FULLSCREEN_DIALOG")
        overlay:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"}); overlay:SetBackdropColor(0,0,0,0.8)
        local box=panel(overlay,540,440); box:SetPoint("CENTER")
        overlay.title=label(box,"GameFontNormalLarge","",20,-20,450,52)
        overlay.meta=label(box,"GameFontDisableSmall","",20,-82,450,48)
        overlay.scroll,overlay.child=scrollArea(box,20,-134,500,248)
        overlay.detail=label(overlay.child,"GameFontHighlight","",0,0,455,220)
        overlay.close=button(box,"Close",400,-398,120,28,function() overlay:Hide() end)
        overlay.remove=button(box,"Delete entry",20,-398,120,28,function()
            local owner,entry,playerKey=overlay.person,overlay.entry,overlay.playerKey
            overlay:Hide()
            CR:ConfirmDelete("Delete this entry for " .. owner.name .. "?\n\n" .. (entry.title or entry.kind) .. "\n\nTotals, notes and tags are unchanged. Cannot be undone.",function()
                if CR.db.people[playerKey]==owner then CR:DeleteHistoryEntry(playerKey,entry) end
            end)
        end)
        W.eventDialog=overlay
    end
    local dialog=W.eventDialog
    dialog.person=person; dialog.entry=item; dialog.playerKey=key
    dialog.title:SetText(self:HistoryTitle(item))
    dialog.meta:SetText(person.name .. "\n" .. self:Date(item.when) .. "  ·  " .. (item.zone or "Unknown"))
    dialog.detail:SetText(self:TripText(item) .. "\n\n" .. (self.types[item.kind] or item.kind) .. " · " .. (item.confidence or "observed"))
    dialog.detail:SetHeight(0)
    local height=math.max(220,dialog.detail:GetStringHeight()+12)
    dialog.detail:SetHeight(height); dialog.child:SetHeight(height); dialog.scroll:SetVerticalScroll(0)
    dialog:Show()
end

function CR:BuildUI()
    if W then return end
    W=panel(UIParent,900,660,"CrossroadsPlayerMemoryMainWindow")
    self.window=W
    W.menus={}
    W:SetPoint("CENTER"); W:SetFrameStrata("DIALOG"); W:EnableMouse(true)
    local function fitScreen()
        W:SetScale(math.min(1, math.max(0.1,(UIParent:GetWidth()-24)/900), math.max(0.1,(UIParent:GetHeight()-24)/660)))
    end
    fitScreen(); UIParent:HookScript("OnSizeChanged",fitScreen)
    W:SetMovable(true); W:SetClampedToScreen(true); W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart",W.StartMoving); W:SetScript("OnDragStop",W.StopMovingOrSizing)
    W:Hide(); table.insert(UISpecialFrames,"CrossroadsPlayerMemoryMainWindow")
    W:SetScript("OnHide",function()
        closeMenus()
        if W.eventDialog then W.eventDialog:Hide() end
        if W.confirm then W.confirm.action=nil; W.confirm:Hide() end
    end)
    label(W,"GameFontNormalLarge","Crossroads",20,-20,600,25)
    label(W,"GameFontDisableSmall","Player Memory",23,-47,500,18)
    button(W,"Options",744,-17,85,27,function() CR:ShowOptions() end)
    button(W,"X",843,-17,35,27,function() W:Hide() end)

    W.countLabel=label(W,"GameFontHighlightSmall","",20,-85,237,18)
    label(W,"GameFontDisableSmall","Search players",20,-111,235,16)
    W.search=entry(W,24,-133,225,24)
    W.search:SetScript("OnTextChanged",function(_,byUser)
        if byUser then W.listScroll:SetVerticalScroll(0); CR:UIRefresh() end
    end)
    W.filters={}; W.filter="All"; W.drafts={}
    W.playerFilterButton=button(W,"All players  v",18,-169,230,25,function() toggleMenu(W.playerMenu) end)
    W.playerMenu=menu(W,230,120,18,-198)
    for i,name in ipairs({"All","Friends","Rivals","Avoid"}) do
        W.filters[name]=button(W.playerMenu,name=="All" and "All players" or name,5,-5-(i-1)*27,220,25,function()
            W.filter=name; closeMenus(); W.listScroll:SetVerticalScroll(0); CR:UIRefresh()
        end)
    end
    W.sortLabels={recent="Last seen",name="Name",time="Time together",groups="Group sessions",rating="Rating"}
    W.sortButton=button(W,"",18,-201,170,25,function() toggleMenu(W.sortMenu) end)
    W.sortDirection=button(W,"",194,-201,54,25,function()
        CR.db.options.playerSortAscending=not CR.db.options.playerSortAscending
        closeMenus(); W.listScroll:SetVerticalScroll(0); CR:UIRefresh()
    end)
    W.sortMenu=menu(W,230,145,18,-229); W.sortChoices={}
    for i,mode in ipairs({"recent","name","time","groups","rating"}) do
        W.sortChoices[mode]=button(W.sortMenu,W.sortLabels[mode],5,-5-(i-1)*27,220,25,function()
            CR.db.options.playerSort=mode
            CR.db.options.playerSortAscending=mode=="name"
            closeMenus(); W.listScroll:SetVerticalScroll(0); CR:UIRefresh()
        end)
    end
    W.listScroll,W.listChild=scrollArea(W,12,-236,248,406)
    W.rows={}

    local detail=panel(W,615,566); detail:SetPoint("TOPRIGHT",W,"TOPRIGHT",-12,-76)
    W.detail=detail
    W.playerTitle=label(detail,"GameFontNormalLarge","Select a player",16,-14,455,26)
    W.deletePlayer=button(detail,"Delete player",465,-523,130,25,function()
        local key=W.selected; local person=key and CR.db.people[key]
        if not person then return end
        CR:ConfirmDelete("Delete " .. person.name .. "?\n\nRemoves their profile, notes, tags, totals and saved history. Cannot be undone.\n\nAutomatic recording pauses for this player until your next login or /reload. /crmemory add can add them again.",function()
            if CR.db.people[key] ~= person then return end
            W.drafts[key]=nil; CR:DeletePerson(key)
        end)
    end)
    W.playerInfo=label(detail,"GameFontHighlightSmall","",16,-45,580,31)
    W.timeTogether=label(detail,"GameFontHighlightLarge","",16,-84,580,27)
    W.tabs={}; W.tab="history"
    for i,spec in ipairs({{"history","History"},{"notes","Profile"},{"stats","Statistics"}}) do
        W.tabs[spec[1]]=button(detail,spec[2],16+(i-1)*124,-124,116,28,function()
            closeMenus(); if W.eventDialog then W.eventDialog:Hide() end
            W.tab=spec[1]; CR:UIRefresh()
        end)
    end
    W.statsPane=CreateFrame("Frame",nil,detail); W.statsPane:SetSize(583,395)
    W.statsPane:SetPoint("TOPLEFT",detail,"TOPLEFT",16,-166)
    W.statValues={}
    local statsList={{"groupSessions","Group sessions"},{"dungeonRuns","Dungeon / raid visits"},{"bossKills","Boss kills"},
        {"groupQuests","Quests while grouped"},{"lootWins","Loot won"},{"tradeWindows","Trade attempts"},
        {"killsOf","PvP kills"},{"deathsTo","PvP deaths"},{"whispersReceived","Whispers received"},{"whispersSent","Whispers sent"}}
    for i,spec in ipairs(statsList) do
        label(W.statsPane,"GameFontHighlight",spec[2],4,-10-(i-1)*32,400,24)
        W.statValues[spec[1]]=label(W.statsPane,"GameFontNormal","",440,-10-(i-1)*32,100,24)
    end
    W.firstMet=label(W.statsPane,"GameFontDisableSmall","",4,-350,565,36)
    W.historyPane=CreateFrame("Frame",nil,detail); W.historyPane:SetSize(599,395)
    W.historyPane:SetPoint("TOPLEFT",detail,"TOPLEFT",8,-166)
    W.historyFilter="all"; W.historyFilters={}
    local filters={{"all","All"},{"group","Groups"},{"quest","Quests"},{"dungeon","Dungeons"},{"pvp","PvP"},
        {"loot","Loot"},{"trade","Trades"},{"social","Social"},{"sight","Encounters"},{"note","Personal"}}
    W.historyFilterButton=button(W.historyPane,"All events  v",8,0,174,25,function() toggleMenu(W.historyMenu) end)
    W.historyMenu=menu(W.historyPane,210,312,8,-29)
    for i,spec in ipairs(filters) do
        W.historyFilters[spec[1]]=button(W.historyMenu,spec[2],5,-5-(i-1)*26,200,24,function()
            W.historyFilter=spec[1]; closeMenus(); W.historyScroll:SetVerticalScroll(0); CR:UIRefresh()
        end)
    end
    W.historySearch=entry(W.historyPane,205,-1,373,24)
    W.historySearchHint=label(W.historyPane,"GameFontDisableSmall","Search history",211,-6,320,18)
    W.historySearch:SetScript("OnTextChanged",function(_,byUser)
        W.historySearchHint:SetShown(W.historySearch:GetText()=="")
        if byUser then W.historyScroll:SetVerticalScroll(0); CR:UIRefresh() end
    end)
    W.showEdits=CreateFrame("CheckButton",nil,W.historyMenu,"UICheckButtonTemplate")
    W.showEdits:SetPoint("TOPLEFT",W.historyMenu,"TOPLEFT",5,-273); W.showEdits:SetChecked(false)
    label(W.historyMenu,"GameFontHighlightSmall","Include profile edits",36,-282,165,18)
    W.showEdits:SetScript("OnClick",function() W.historyScroll:SetVerticalScroll(0); CR:UIRefresh() end)
    W.clearHistory=button(detail,"Clear history",324,-523,130,25,function()
        local key=W.selected; local person=key and CR.db.people[key]
        if not person then return end
        CR:ConfirmDelete("Clear ALL history for " .. person.name .. "?\n\nThis includes entries hidden by filters. Notes, tags, ratings, totals and trade snapshots are kept.\n\nCannot be undone.",function()
            if CR.db.people[key] == person then CR:ClearHistory(key) end
        end)
    end)
    W.historyCount=label(W.historyPane,"GameFontDisableSmall","",12,-35,565,16)
    W.historyScroll,W.historyChild=scrollArea(W.historyPane,0,-57,592,332)
    W.historyRows={}
    W.historyEmpty=label(W.historyChild,"GameFontHighlight","",12,-16,510,75)

    W.notesPane=CreateFrame("Frame",nil,detail); W.notesPane:SetSize(583,345)
    W.notesPane:SetPoint("TOPLEFT",detail,"TOPLEFT",16,-166)
    W.ratingButton=button(W.notesPane,"Unrated  v",0,0,146,26,function() toggleMenu(W.ratingMenu) end)
    W.ratingMenu=menu(W.notesPane,278,38,0,-30)
    W.stars={}
    for i=0,5 do W.stars[i]=button(W.ratingMenu,tostring(i),5+i*45,-5,42,27,function()
        closeMenus(); if W.selected then CR:Rate(W.selected,i) end
    end) end
    W.editTags=button(W.notesPane,"Edit tags  v",433,0,146,26,function() toggleMenu(W.tagMenu) end)
    W.tagsSummary=label(W.notesPane,"GameFontHighlight","",0,-45,570,44)
    W.tagMenu=menu(W.notesPane,225,253,354,-30)
    W.tagButtons={}
    for i,tag in ipairs(CR.tags) do
        W.tagButtons[tag]=button(W.tagMenu,tag,5,-5-(i-1)*27,215,25,function()
            if W.selected then CR:Tag(W.selected,tag) end
        end)
    end
    label(W.notesPane,"GameFontNormalSmall","Notes",0,-103,420,18)
    local noteScroll,noteChild=scrollArea(W.notesPane,0,-130,583,160)
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
    W.noteStatus=label(W.notesPane,"GameFontDisableSmall","",0,-309,420,18)
    W.saveNote=button(W.notesPane,"Save note",458,-301,125,26,function()
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
    W.countLabel:SetText(#list .. " players" .. (#list>300 and " (showing 300)" or ""))
    local sortMode=self.db.options.playerSort or "recent"
    W.sortButton:SetText("Sort: "..(W.sortLabels[sortMode] or "Last seen").."  v")
    W.sortDirection:SetText(self.db.options.playerSortAscending and "Asc" or "Desc")
    for mode,b in pairs(W.sortChoices) do if mode==sortMode then b:LockHighlight() else b:UnlockHighlight() end end
    W.playerFilterButton:SetText((W.filter=="All" and "All players" or W.filter) .. "  v")
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
            row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            row:GetHighlightTexture():SetVertexColor(0.55,0.62,0.63,0.16)
            row.name=label(row,"GameFontHighlightSmall","",6,-5,197,18)
            row.meta=label(row,"GameFontDisableSmall","",6,-25,197,15)
            row:SetScript("OnClick",function(self) CR:SelectPerson(self.playerKey) end)
            W.rows[i]=row
        end
        row.playerKey=person.key
        local marker=person.tags.Avoid and "|cffff7766! |r" or person.tags.Rival and "|cffffb36b! |r" or person.tags.Friend and "|cff66dd88+ |r" or ""
        row.name:SetText(marker .. person.name)
        local meta=self:FormatDuration(person.stats.timeTogether).." together"
        if sortMode=="groups" then meta=(person.stats.groupSessions or 0).." group sessions"
        elseif sortMode=="rating" then meta="Rating: "..(person.rating or 0).."/5"
        elseif sortMode=="recent" then meta="Seen: "..self:Date(person.lastSeen) end
        row.meta:SetText(meta)
        if person.key==W.selected then row:LockHighlight() else row:UnlockHighlight() end
        row:Show()
    end
    for i=count+1,#W.rows do W.rows[i]:Hide() end
    W.listChild:SetHeight(math.max(390,count*47))
    local person=W.selected and self.db.people[W.selected]
    W.deletePlayer:SetEnabled(person~=nil); W.saveNote:SetEnabled(person~=nil)
    for _,b in pairs(W.stars) do b:SetEnabled(person~=nil) end
    for _,b in pairs(W.tagButtons) do b:SetEnabled(person~=nil) end
    for key,b in pairs(W.tabs) do if key==W.tab then b:LockHighlight() else b:UnlockHighlight() end end
    W.historyPane:SetShown(W.tab=="history"); W.notesPane:SetShown(W.tab=="notes")
    W.statsPane:SetShown(W.tab=="stats")
    W.deletePlayer:SetShown(W.tab=="notes"); W.clearHistory:SetShown(W.tab=="notes")
    W.ratingButton:SetEnabled(person~=nil); W.editTags:SetEnabled(person~=nil)
    W.historyFilterButton:SetText((self.types[W.historyFilter] or "All events") .. "  v")
    if not person then
        W.playerTitle:SetText("No player selected"); W.playerInfo:SetText("Select a player, or adjust your search and filters.")
        W.timeTogether:SetText(""); W.firstMet:SetText(""); W.tagsSummary:SetText(""); W.ratingButton:SetText("Unrated  v")
        for _,value in pairs(W.statValues) do value:SetText("—") end
        W.notesFor=nil; W.notes:SetText(""); W.noteStatus:SetText("")
        W.historyCount:SetText("No entries"); W.clearHistory:Disable()
        for _,row in ipairs(W.historyRows) do row:Hide() end
        W.historyChild:SetHeight(316); W.historyEmpty:SetText("Your history will appear here."); W.historyEmpty:Show()
        return
    end
    W.playerTitle:SetText(person.name .. (person.partial and " (partial name)" or ""))
    W.playerInfo:SetText((person.level and ("Level "..person.level.."  ") or "") .. (person.race or "") .. " " .. (person.class or "") .. (person.guild and ("  <"..person.guild..">") or "")
)
    local stats=person.stats or {}
    W.timeTogether:SetText(self:FormatDuration(stats.timeTogether) .. " together")
    W.firstMet:SetText("First met " .. self:Date(person.firstSeen) .. " in " .. (person.firstZone or "Unknown") .. "\nTime together is approximate grouped time.")
    for field,value in pairs(W.statValues) do value:SetText(tostring(stats[field] or 0)) end
    W.ratingButton:SetText((person.rating==0 and "Unrated" or ("Rating: " .. person.rating .. " / 5")) .. "  v")
    local selectedTags={}
    for _,tag in ipairs(self.tags) do if person.tags[tag] then selectedTags[#selectedTags+1]=tag end end
    W.tagsSummary:SetText(#selectedTags>0 and table.concat(selectedTags,"  ·  ") or "No tags")
    for i,b in pairs(W.stars) do if person.rating==i then b:LockHighlight() else b:UnlockHighlight() end end
    for tag,b in pairs(W.tagButtons) do if person.tags[tag] then b:LockHighlight() else b:UnlockHighlight() end end
    if W.notesFor~=person.key then
        W.notesFor=person.key; W.notes:SetText(W.drafts[person.key] or person.notes or "")
        W.noteStatus:SetText(W.drafts[person.key] and "Unsaved changes" or "")
    end
    for kind,b in pairs(W.historyFilters) do if kind==W.historyFilter then b:LockHighlight() else b:UnlockHighlight() end end
    local items=self:HistoryItems(person,W.historyFilter,W.historySearch:GetText(),W.showEdits:GetChecked())
    W.historyCount:SetText(#items .. " entries  ·  newest first")
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
                    CR:ShowHistoryEntry(row.playerKey,row.entry)
                end
            end)
            row.day=label(row,"GameFontNormalSmall","",4,0,530,18)
            row.title=label(row,"GameFontHighlight","",60,0,330,20)
            row.summary=label(row,"GameFontDisableSmall","",60,0,480,36)
            row.time=label(row,"GameFontDisableSmall","",4,0,50,20)
            row.place=label(row,"GameFontDisableSmall","",400,0,145,20)
            row.line=row:CreateTexture(nil,"BACKGROUND")
            row.line:SetColorTexture(0.16,0.19,0.21,0.55); row.line:SetSize(540,1)
            row:SetScript("OnEnter",function() row.title:SetTextColor(1,0.82,0.45) end)
            row:SetScript("OnLeave",function() row.title:SetTextColor(1,1,1) end)
            W.historyRows[i]=row
        end
        row.playerKey=person.key; row.person=person; row.entry=item
        local day=date("%d %b %Y",item.when); local newDay=day~=lastDay
        local top=newDay and 30 or 8; lastDay=day
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",W.historyChild,"TOPLEFT",0,-offset)
        row.day:SetShown(newDay); row.day:SetText(day)
        row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT",row,"TOPLEFT",60,-top)
        row.title:SetText(self:HistoryTitle(item))
        row.time:ClearAllPoints(); row.time:SetPoint("TOPLEFT",row,"TOPLEFT",4,-top)
        row.time:SetText(date("%H:%M",item.when))
        row.place:ClearAllPoints(); row.place:SetPoint("TOPLEFT",row,"TOPLEFT",400,-top)
        row.place:SetText(item.zone or "Unknown")
        local extra=item.sessionID and 42 or 0
        row.summary:SetShown(item.sessionID~=nil)
        if item.sessionID then
            local names,activities={},{}
            for _,name in pairs(item.members) do names[#names+1]=name end
            table.sort(names)
            for _,kind in ipairs({"quest","dungeon","loot","trade","pvp","social"}) do
                if (item.counts[kind] or 0)>0 then activities[#activities+1]=(self.types[kind] or kind)..": "..item.counts[kind] end
            end
            local whispers=(item.whispersIn or 0)+(item.whispersOut or 0)
            if whispers>0 then activities[#activities+1]="Whispers: "..whispers end
            row.summary:ClearAllPoints(); row.summary:SetPoint("TOPLEFT",row,"TOPLEFT",60,-top-21)
            local roster=table.concat(names,", ")
            if #names>3 then roster=table.concat({names[1],names[2],names[3]},", ").." +"..(#names-3) end
            row.summary:SetText(roster.."\n"..(#activities>0 and table.concat(activities," · ") or "No other activities recorded"))
        end
        row.line:ClearAllPoints(); row.line:SetPoint("TOPLEFT",row,"TOPLEFT",4,-top-25-extra)
        local height=top+28+extra; row:SetHeight(height); offset=offset+height; row:Show()
    end
    for i=#items+1,#W.historyRows do W.historyRows[i]:Hide() end
    W.historyChild:SetHeight(math.max(316,offset))
    W.historyScroll:SetVerticalScroll(math.min(W.historyScroll:GetVerticalScroll(),math.max(0,offset-316)))
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
