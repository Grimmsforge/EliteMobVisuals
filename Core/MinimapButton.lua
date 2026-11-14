-- =============================================================================
-- Elite Mob Visuals: minimap button
-- The launcher on the minimap's edge: click, tooltip, drag to move around the
-- rim. Built in instead of LibDataBroker-1.1 + LibDBIcon-1.0 (no libraries),
-- ported from Epithet's Core/MinimapButton.lua.
--
-- It deliberately looks like a LibDBIcon button to other addons: the frame is
-- named LibDBIcon10_EliteMobVisuals and parented to Minimap, keeps .icon and
-- .dataObject, and uses the same stock textures, so button bags and skinners
-- (EllesmereUI, SexyMap, ...) that collect LibDBIcon buttons still find it.
--
-- Saved state lives in the table passed to Init (profile.minimap):
--   hide        true while the button is hidden (the caller owns this flag)
--   minimapPos  angle around the minimap in degrees, 0 = east, counter-clockwise
-- =============================================================================
local _, ns = ...

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local CreateFrame, GetCursorPosition = CreateFrame, GetCursorPosition
local rad, deg, cos, sin, sqrt = math.rad, math.deg, math.cos, math.sin, math.sqrt
local max, min = math.max, math.min
local atan2 = math.atan2 or math.atan

local FRAME_NAME    = "LibDBIcon10_EliteMobVisuals"
local DEFAULT_ANGLE = 225   -- bottom-left of the minimap
local RIM_OFFSET    = 5     -- how far outside the minimap's edge the centre sits
local ICON_INSET    = 0.05  -- texcoord crop when not pressed; full icon when pressed

-- Stock client textures, by file ID (present on every flavour).
local TEX_HIGHLIGHT  = 136477 -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
local TEX_BORDER     = 136430 -- Interface\Minimap\MiniMap-TrackingBorder
local TEX_BACKGROUND = 136467 -- Interface\Minimap\UI-Minimap-Background

-- ---------------------------------------------------------------------------
-- Placement
-- Minimap-shape addons (square maps and the like) report their shape through
-- the global GetMinimapShape(). Each shape is round in some corners and square
-- in the others: in a round corner the button follows the circle, in a square
-- one it is pushed out to the square's edge.
-- ---------------------------------------------------------------------------
local ROUND_CORNERS = {}
do
    local shapes = {
        ["ROUND"]                 = "TL TR BL BR",
        ["SQUARE"]                = "",
        ["CORNER-TOPLEFT"]        = "TL",
        ["CORNER-TOPRIGHT"]       = "TR",
        ["CORNER-BOTTOMLEFT"]     = "BL",
        ["CORNER-BOTTOMRIGHT"]    = "BR",
        ["SIDE-LEFT"]             = "TL BL",
        ["SIDE-RIGHT"]            = "TR BR",
        ["SIDE-TOP"]              = "TL TR",
        ["SIDE-BOTTOM"]           = "BL BR",
        ["TRICORNER-TOPLEFT"]     = "TL TR BL",
        ["TRICORNER-TOPRIGHT"]    = "TL TR BR",
        ["TRICORNER-BOTTOMLEFT"]  = "TL BL BR",
        ["TRICORNER-BOTTOMRIGHT"] = "TR BL BR",
    }
    for shape, corners in pairs(shapes) do
        local set = {}
        for corner in corners:gmatch("%a+") do set[corner] = true end
        ROUND_CORNERS[shape] = set
    end
end

-- Offset of the button's centre from the minimap's centre, for an angle in
-- degrees, the minimap's half width and half height, and its shape.
function MinimapButton.Offset(angle, halfWidth, halfHeight, shape)
    local a = rad(angle or DEFAULT_ANGLE)
    local x, y = cos(a), sin(a)
    local w, h = halfWidth + RIM_OFFSET, halfHeight + RIM_OFFSET
    local corner = (y > 0 and "T" or "B") .. (x < 0 and "L" or "R")
    local round = ROUND_CORNERS[shape] or ROUND_CORNERS.ROUND
    if round[corner] then
        return x * w, y * h
    end
    -- Square corner: run out along the angle past the circle, then clamp to
    -- the square, so the button hugs the edge and settles in the corner.
    local reachW, reachH = sqrt(2 * w * w) - 10, sqrt(2 * h * h) - 10
    return max(-w, min(x * reachW, w)), max(-h, min(y * reachH, h))
end

local function Place(button, db)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local x, y = MinimapButton.Offset(db.minimapPos, Minimap:GetWidth() / 2, Minimap:GetHeight() / 2, shape)
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- ---------------------------------------------------------------------------
-- Interaction
-- ---------------------------------------------------------------------------
local dragging = false

local function SetPressed(button, pressed)
    button.isMouseDown = pressed
    local inset = pressed and 0 or ICON_INSET
    button.icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
end

-- Tooltip on the side of the button away from the nearest screen edge.
local function TooltipAnchor(button)
    local x, y = button:GetCenter()
    if not x or not y then return "CENTER" end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local side = (x > width * 2 / 3) and "RIGHT" or (x < width / 3) and "LEFT" or ""
    local top = y > height / 2
    return (top and "TOP" or "BOTTOM") .. side, button, (top and "BOTTOM" or "TOP") .. side
end

local function OnEnter(button)
    if dragging then return end
    local launcher = button.dataObject
    if launcher.OnTooltipShow then
        GameTooltip:SetOwner(button, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint(TooltipAnchor(button))
        launcher.OnTooltipShow(GameTooltip)
        GameTooltip:Show()
    end
end

local function OnLeave(button)
    if not GameTooltip.IsOwned or GameTooltip:IsOwned(button) then
        GameTooltip:Hide()
    end
end

local function OnClick(button, mouseButton)
    local launcher = button.dataObject
    if launcher.OnClick then
        launcher.OnClick(button, mouseButton)
    end
end

local function OnDragUpdate(button)
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    button.db.minimapPos = deg(atan2(py - my, px - mx)) % 360
    Place(button, button.db)
end

local function OnDragStart(button)
    dragging = true
    button:LockHighlight()
    SetPressed(button, true)
    OnLeave(button)
    button:SetScript("OnUpdate", OnDragUpdate)
end

local function OnDragStop(button)
    button:SetScript("OnUpdate", nil)
    SetPressed(button, false)
    button:UnlockHighlight()
    dragging = false
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
local function Build(launcher, db)
    local button = CreateFrame("Button", FRAME_NAME, Minimap)
    button.dataObject = launcher
    button.db = db
    button:Hide() -- placed and shown at login (see Init)
    button:SetFrameStrata("MEDIUM")
    if button.SetFixedFrameStrata then button:SetFixedFrameStrata(true) end
    button:SetFrameLevel(8)
    if button.SetFixedFrameLevel then button:SetFixedFrameLevel(true) end
    button:SetSize(31, 31)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(TEX_HIGHLIGHT)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture(TEX_BORDER)
    border:SetPoint("TOPLEFT")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture(TEX_BACKGROUND)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture(launcher.icon)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon
    SetPressed(button, false)

    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", OnLeave)
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop", OnDragStop)
    button:SetScript("OnMouseDown", function(self) SetPressed(self, true) end)
    button:SetScript("OnMouseUp", function(self) SetPressed(self, false) end)
    return button
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

-- launcher: { icon, OnClick(button, mouseButton), OnTooltipShow(tooltip) }
-- db:       the saved table described at the top of this file.
-- The frame is made now unless hidden (made on the first Show instead), but is
-- only placed and shown at PLAYER_LOGIN, once any minimap-shape addon is ready.
-- loggedIn: the caller is already in (or past) PLAYER_LOGIN, as Elite Mob
-- Visuals is, so there is no login left to wait for.
function MinimapButton:Init(launcher, db, loggedIn)
    self.launcher, self.db = launcher, db
    if not db.hide then
        self.button = Build(launcher, db)
    end
    if loggedIn or (IsLoggedIn and IsLoggedIn()) then
        self.ready = true
        if not db.hide then self:Show() end
        return
    end
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_LOGIN")
    waiter:SetScript("OnEvent", function(frame)
        frame:UnregisterEvent("PLAYER_LOGIN")
        frame:SetScript("OnEvent", nil)
        MinimapButton.ready = true
        if not MinimapButton.db.hide then MinimapButton:Show() end
    end)
end

function MinimapButton:Show()
    if not self.launcher then return end
    self.button = self.button or Build(self.launcher, self.db)
    if not self.ready then return end -- the login handler shows it
    Place(self.button, self.db)
    self.button:Show()
end

function MinimapButton:Hide()
    if self.button then self.button:Hide() end
end

function MinimapButton:GetButton()
    return self.button
end
