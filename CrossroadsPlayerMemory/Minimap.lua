local addonName, CR = ...

-- Standalone, round minimap button: no Ace3 or LibDBIcon dependency.
local DEFAULT_ANGLE = 225
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function normalizedAngle(value)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return DEFAULT_ANGLE
    end
    return value % 360
end

local function cursorAngle(dx, dy)
    -- math.atan2 is present in WoW; the fallback supports other Lua runtimes.
    if math.atan2 then return math.atan2(dy, dx) end
    if dx == 0 then
        if dy >= 0 then return math.pi / 2 end
        return -math.pi / 2
    end
    local angle = math.atan(dy / dx)
    if dx < 0 then angle = angle + math.pi end
    return angle
end

function CR:PositionMinimapButton()
    local button = self.minimapButton
    if not button or not Minimap or not self.db then return end
    local angle = math.rad(normalizedAngle(self.db.options.minimapAngle))
    -- Follow the visible minimap edge, even when the user resizes the minimap.
    local radius = math.max(Minimap:GetWidth(), Minimap:GetHeight()) / 2 + 9
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function CR:UpdateMinimapButton()
    if not self.db then return end
    if not self.minimapButton and self.db.options.minimapIcon ~= false then
        self:CreateMinimapButton()
    end
    if not self.minimapButton then return end
    if self.db.options.minimapIcon == false then
        self.minimapButton:Hide()
    else
        self:PositionMinimapButton()
        self.minimapButton:Show()
    end
end

function CR:CreateMinimapButton()
    if self.minimapButton or not Minimap or not CreateFrame or not self.db then return end
    local button = CreateFrame("Button", "CrossroadsPlayerMemoryMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(BOOK_ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    -- Blizzard's familiar circular button frame, used by minimap launchers.
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.border = border

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            CR:ShowOptions()
        else
            CR:ToggleUI()
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Crossroads", 0.84, 0.69, 0.41)
        GameTooltip:AddLine("Left-click: Open or close", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Settings", 1, 1, 1)
        GameTooltip:AddLine("Left-drag: Move around minimap", 0.75, 0.75, 0.75)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            if not Minimap or not GetCursorPosition or not CR.db then return end
            local scale = Minimap:GetEffectiveScale()
            if type(scale) ~= "number" or scale <= 0 then return end
            local cursorX, cursorY = GetCursorPosition()
            if type(cursorX) ~= "number" or type(cursorY) ~= "number" then return end
            local mapX, mapY = Minimap:GetCenter()
            if type(mapX) ~= "number" or type(mapY) ~= "number" then return end
            local angle = math.deg(cursorAngle(cursorX / scale - mapX, cursorY / scale - mapY))
            CR.db.options.minimapAngle = normalizedAngle(angle)
            CR:PositionMinimapButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    self.minimapButton = button
    -- Keep the launcher at the minimap edge when other UI addons resize the map.
    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", function() CR:PositionMinimapButton() end)
    end
    self:UpdateMinimapButton()
end
