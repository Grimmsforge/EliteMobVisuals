-- =============================================================================
-- Elite Mob Visuals: options window
-- A small movable window (/emv) rather than the full-screen Settings panel, so
-- the nameplates stay in view while positioning. It has a live preview, drawn
-- with the same code as the real visuals, plus four tabs. The game's Settings
-- list gets a short page with a button that opens this window.
-- =============================================================================
local _, ns = ...
local L = ns.L
local W = ns.Widgets
local C = W.C
local Media = ns.Media

local Options = {}
ns.Options = Options

local WIDTH, HEIGHT = 640, 650
local COL_W = 272
local LEFT_X, RIGHT_X = 14, 324

local win
local controls = {}
local previewClass, previewTarget = "elite", true
local previewPlate, previewBar, previewSet, previewNotice
local classButtons = {}

local function P() return ns.db.profile end
local function Changed() ns.NotifySettingsChanged() end

-- get/set pair for profile[section][key] (section nil: profile[key]).
local function Field(section, key)
    local function get()
        if section then return P()[section][key] end
        return P()[key]
    end
    local function set(v)
        if section then P()[section][key] = v else P()[key] = v end
        Changed()
    end
    return get, set
end

local function Track(w)
    if w.Refresh then controls[#controls + 1] = w end
    return w
end

function Options.RefreshControls()
    for _, w in ipairs(controls) do w:Refresh() end
end

-- ---------------------------------------------------------------------------
-- Layout: two columns per page, filled top to bottom.
-- ---------------------------------------------------------------------------

local function Column(page, x)
    local col = { y = -10 }
    function col:Add(w, height, indent)
        w:SetPoint("TOPLEFT", page, "TOPLEFT", x + (indent or 0), self.y)
        if w.SetWidth and not w.keepWidth then w:SetWidth(COL_W - (indent or 0)) end
        self.y = self.y - (height or w.height or 24)
        return Track(w)
    end
    function col:Header(text)
        local h = W.Header(page, text)
        h:SetPoint("TOPLEFT", page, "TOPLEFT", x, self.y)
        h:SetWidth(COL_W)
        self.y = self.y - 26
        return h
    end
    function col:Gap(px) self.y = self.y - px end
    return col
end

local function Check(page, label, section, key, tip)
    local get, set = Field(section, key)
    local cb = W.Check(page, label, get, set, tip)
    cb.keepWidth = true
    return cb
end

local function Slider(page, label, section, key, minV, maxV, step, fmt)
    local get, set = Field(section, key)
    return W.Slider(page, label, minV, maxV, step, get, set, fmt, COL_W)
end

local function List(order, names)
    return function()
        local opts = {}
        for i, value in ipairs(order) do opts[i] = { value = value, text = names[value] } end
        return opts
    end
end

-- Style choices, with each style's art for the given (or previewed) class.
-- extra: entries to list first, such as "same as the badge" or "text only".
local function StyleOptions(class, extra)
    return function()
        local c = class or previewClass
        local color = P().classes[c].color
        local opts = {}
        for _, e in ipairs(extra or {}) do opts[#opts + 1] = e end
        for _, key in ipairs(Media.ORDER) do
            opts[#opts + 1] = { value = key, text = Media.GetName(key), icon = Media.Resolve(key, c), tint = color }
        end
        return opts
    end
end

local function Dropdown(page, label, section, key, getOptions, tip, width)
    local get, set = Field(section, key)
    return W.Dropdown(page, label, width or COL_W, getOptions, get, set, tip)
end

-- ---------------------------------------------------------------------------
-- Preview
-- ---------------------------------------------------------------------------

function Options.RefreshPreview()
    if not previewSet then return end
    local p = P()
    local c = p.classes[previewClass]
    previewSet:HideAll()
    previewPlate:SetAlpha(previewTarget and 1 or 0.6)
    for cls, btn in pairs(classButtons) do btn:SetSelected(cls == previewClass) end

    if not p.enabled or not c.show then
        previewNotice:SetText(not p.enabled and L["The addon is turned off (General tab)."]
            or string.format(L["%s is turned off (Classifications tab)."], ns.CLASS_LABELS[previewClass]))
        previewNotice:Show()
        return
    end
    previewNotice:Hide()

    local b, o = p.badge, p.overhead
    if b.enabled and b.where == "frame" then
        previewNotice:SetText(L["The badge shows on the target frame only."])
        previewNotice:Show()
    end
    local showBadge = ns.BadgeOnNameplates(p) and (b.scope == "all" or previewTarget)
    local showOver = o.enabled and (o.scope == "all"
        or (o.scope == "target" and previewTarget)
        or (o.scope == "nontarget" and not previewTarget))
    -- The mock plate's frame includes its name, like Blizzard's own plates.
    local place = previewSet.place
    place.host = previewPlate
    place.badge = (p.anchor == "health") and previewBar or previewPlate
    place.over = previewPlate
    place.strata, place.level = nil, nil
    previewSet:Update(previewClass, place, showBadge, showOver, p)
end

local function SetPreviewClass(class)
    previewClass = class
    if ns.Classify.testClass then ns.SetTestMode(true, class, true) end
    Options.RefreshPreview()
    Options.RefreshControls()   -- style icons follow the previewed class
end

local function BuildPreview(parent)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", 14, -58)
    box:SetPoint("TOPRIGHT", -14, -58)
    box:SetHeight(150)
    W.Skin(box, { 0.03, 0.03, 0.04, 1 })
    box:SetClipsChildren(true)

    local sky = box:CreateTexture(nil, "BACKGROUND", nil, -7)
    sky:SetPoint("TOPLEFT", 1, -1)
    sky:SetPoint("BOTTOMRIGHT", -1, 1)
    sky:SetColorTexture(1, 1, 1, 1)
    if CreateColor then
        pcall(sky.SetGradient, sky, "VERTICAL", CreateColor(0.10, 0.08, 0.07, 1), CreateColor(0.04, 0.04, 0.06, 1))
    else
        sky:SetColorTexture(0.06, 0.05, 0.06, 1)
    end

    local title = W.Text(box, L["Preview"], "GameFontNormalSmall", C.gold)
    title:SetPoint("TOPLEFT", 8, -6)

    -- A mock nameplate: the faint outline is the plate frame itself, which is
    -- what "Nameplate frame" attaches to.
    local plate = CreateFrame("Frame", nil, box)
    plate:SetSize(150, 38)
    plate:SetPoint("CENTER", box, "CENTER", -80, -22)
    W.Skin(plate, { 0, 0, 0, 0 }, { 1, 1, 1, 0.12 })
    local name = W.Text(plate, L["Defias Pillager"], "GameFontNormalSmall", { 1, 0.82, 0 })
    name:SetPoint("TOP", 0, -4)
    local bar = CreateFrame("StatusBar", nil, plate)
    bar:SetSize(136, 10)
    bar:SetPoint("BOTTOM", 0, 7)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.80, 0.13, 0.10)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(72)
    local edge = bar:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 0.85)
    previewPlate, previewBar = plate, bar
    previewSet = ns.Visuals.Create(plate)

    previewNotice = W.Text(box, "", "GameFontHighlightSmall", C.dim)
    previewNotice:SetPoint("BOTTOM", plate, "TOP", 0, 26)
    previewNotice:Hide()

    for i, class in ipairs(ns.CLASSES) do
        local btn = W.Button(box, ns.CLASS_LABELS[class], 110, function() SetPreviewClass(class) end)
        btn:SetPoint("TOPRIGHT", -10, -10 - (i - 1) * 26)
        classButtons[class] = btn
    end
    local asTarget = W.Check(box, L["As your target"],
        function() return previewTarget end,
        function(v) previewTarget = v; Options.RefreshPreview() end,
        L["Preview the mob as your current target, or as another mob on screen."])
    asTarget:SetPoint("TOPRIGHT", -102, -118)
    Track(asTarget)
end

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

local function BuildGeneral(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Visibility"])
    left:Add(Check(page, L["Enable Elite Mob Visuals"], nil, "enabled"))
    left:Add(Check(page, L["Only mobs you can attack"], nil, "hostileOnly",
        L["Skip friendly elites and rares, such as town guards."]))
    left:Add(Check(page, L["Only while in combat"], nil, "combatOnly"))
    left:Add(Check(page, L["Hide on dead mobs"], nil, "hideDead"))

    left:Gap(8)
    left:Header(L["Minimap"])
    left:Add(Options.MinimapCheck(page))

    -- Which nameplate addon the visuals are fitted to.
    if ns.Plates.EllesmereLoaded() then
        left:Gap(8)
        left:Header(L["EllesmereUI Nameplates"])
        local eui = W.Note(page, L["Detected. The visuals ride EllesmereUI's own plates: they sit beside its health bar and above its name, scale and fade with its plates, and draw over its auras. If you see two elite markers, hide EllesmereUI's own Rare/Elite indicator in its Nameplates > Display Layout options."], COL_W)
        left:Add(eui, 96)
    end

    right:Header(L["Attach to"])
    right:Add(Dropdown(page, L["Visuals attach to"], nil, "anchor", List(
        { "health", "plate" },
        { health = L["Health bar and name (recommended)"], plate = L["Nameplate frame (click box)"] }),
        L["Health bar and name: the badge sits beside the health bar and the marker above the name, on Blizzard, EllesmereUI, Plater, ElvUI and KuiNameplates plates (any other falls back to the nameplate frame). Nameplate frame: Blizzard's click box, which nameplate addons size in their own ways."]))
    local note = W.Note(page, L["Every nameplate addon draws its plate differently. Pick the anchor that sits best, then fine-tune with each visual's offsets."], COL_W)
    right:Add(note, 48)

    right:Header(L["Slash commands"])
    local cmds = W.Note(page,
        "|cffe8b23a/emv|r  " .. L["open these options"] .. "\n" ..
        "|cffe8b23a/emv test|r  " .. L["mark every nameplate, to position visuals"] .. "\n" ..
        "|cffe8b23a/emv test rare|r  " .. L["the same, as a chosen classification"] .. "\n" ..
        "|cffe8b23a/emv on|r, |cffe8b23a/emv off|r  " .. L["turn the addon on or off"] .. "\n" ..
        "|cffe8b23a/emv minimap|r  " .. L["show or hide the minimap button"] .. "\n" ..
        "|cffe8b23a/emv reset|r  " .. L["back to the defaults"], COL_W)
    right:Add(cmds, 96)
end

local SCOPE_BADGE = { order = { "target", "all" }, names = { target = L["Your target only"], all = L["Every marked nameplate"] } }

-- "Show the badge on": the one choice of where the badge goes. Shared by the
-- Nameplate Badge and Target Frame tabs and the Settings page.
local WHERE_NAMES = {
    auto      = L["Nameplate, or the target frame without one"],
    nameplate = L["Nameplate only"],
    frame     = L["Target frame only"],
    both      = L["Nameplate and target frame"],
}
local WHERE_TIP = L["Nameplate: the plate above the mob's head (enemy nameplates on). Target frame: your target's unit frame at the top of the screen (EllesmereUI's or Blizzard's). The first choice uses the nameplate and moves to the target frame when there isn't one: nameplates off, or the mob out of nameplate range."]

function Options.WhereDropdown(parent, width)
    return Dropdown(parent, L["Show the badge on"], "badge", "where", List(ns.WHERE_ORDER, WHERE_NAMES), WHERE_TIP, width)
end
local SCOPE_OVER = {
    order = { "all", "target", "nontarget" },
    names = { all = L["Every marked nameplate"], target = L["Your target only"], nontarget = L["All but your target"] },
}

local function BuildBadge(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Badge"])
    left:Add(Check(page, L["Show the badge"], "badge", "enabled"))
    left:Add(Options.WhereDropdown(page))
    left:Add(Dropdown(page, L["On which nameplates"], "badge", "scope", List(SCOPE_BADGE.order, SCOPE_BADGE.names),
        L["Your target only, or every elite and rare with a nameplate on screen."]))
    left:Add(Dropdown(page, L["Style"], "badge", "style", StyleOptions(),
        L["Bundled styles take the classification colour. Blizzard styles use the game's own art for each classification."]))
    left:Add(Dropdown(page, L["Position"], "badge", "point", List(ns.PLACEMENT_ORDER, ns.PLACEMENT_NAMES)))
    left:Add(Check(page, L["Mirrored pair on both sides"], "badge", "pair",
        L["A second badge on the opposite side, mirrored. Applies to the left, right and corner positions."]))
    left:Add(Check(page, L["Flip the art"], "badge", "flip",
        L["Art that points one way (wings, dragons) already faces outward; this turns it around."]))
    left:Add(Check(page, L["Tint with the classification colour"], "badge", "tint"))

    right:Header(L["Size and placement"])
    right:Add(Slider(page, L["Size"], "badge", "size", 8, 96, 1))
    right:Add(Slider(page, L["Horizontal offset"], "badge", "x", -100, 100, 1))
    right:Add(Slider(page, L["Vertical offset"], "badge", "y", -100, 100, 1))
    right:Add(Slider(page, L["Opacity"], "badge", "alpha", 0.1, 1, 0.05, "%.2f"))
    right:Add(Dropdown(page, L["Animation"], "badge", "anim", List(ns.ANIM_ORDER, ns.ANIM_NAMES)))
    right:Add(Check(page, L["Glow"], "badge", "glow"))
    right:Add(Slider(page, L["Glow strength"], "badge", "glowAlpha", 0.1, 1, 0.05, "%.2f"))
end

local function BuildOverhead(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Overhead marker"])
    left:Add(Check(page, L["Show the overhead marker"], "overhead", "enabled"))
    left:Add(Dropdown(page, L["Show on"], "overhead", "scope", List(SCOPE_OVER.order, SCOPE_OVER.names)))
    left:Add(Dropdown(page, L["Style"], "overhead", "style",
        StyleOptions(nil, { { value = "none", text = L["Text only"] } })))
    left:Add(Check(page, L["Tint with the classification colour"], "overhead", "tint"))
    left:Add(Check(page, L["Glow"], "overhead", "glow"))
    left:Add(Check(page, L["Show a text label"], "overhead", "label",
        L["Elite, Rare Elite, Rare or Boss, in the classification colour."]))
    left:Add(Dropdown(page, L["Label position"], "overhead", "labelPos",
        List({ "above", "below" }, { above = L["Above the marker"], below = L["Below the marker"] })))

    right:Header(L["Size and placement"])
    right:Add(Slider(page, L["Size"], "overhead", "size", 8, 96, 1))
    right:Add(Slider(page, L["Horizontal offset"], "overhead", "x", -100, 100, 1))
    right:Add(Slider(page, L["Height above the plate"], "overhead", "y", -40, 150, 1))
    right:Add(Slider(page, L["Opacity"], "overhead", "alpha", 0.1, 1, 0.05, "%.2f"))
    right:Add(Dropdown(page, L["Animation"], "overhead", "anim", List(ns.ANIM_ORDER, ns.ANIM_NAMES)))
    right:Add(Slider(page, L["Glow strength"], "overhead", "glowAlpha", 0.1, 1, 0.05, "%.2f"))
    right:Add(Slider(page, L["Label size"], "overhead", "labelSize", 8, 24, 1))
end

local function BuildClasses(page)
    local cols = { { L["Classification"], 14 }, { L["Show"], 128 }, { L["Colour"], 170 },
                   { L["Badge style"], 222 }, { L["Marker style"], 418 } }
    for _, col in ipairs(cols) do
        local t = W.Text(page, col[1], "GameFontNormalSmall", C.gold)
        t:SetPoint("TOPLEFT", col[2], -12)
    end

    local y = -34
    for _, class in ipairs(ns.CLASSES) do
        local cdb = function() return P().classes[class] end
        local name = W.Text(page, ns.CLASS_LABELS[class])
        name:SetPoint("TOPLEFT", 14, y - 4)

        local show = W.Check(page, "", function() return cdb().show end,
            function(v) cdb().show = v; Changed() end)
        show:SetPoint("TOPLEFT", 132, y - 3)
        Track(show)

        local swatch = W.Color(page,
            function() return cdb().color end,
            function(r, g, b)
                local c = cdb().color
                c.r, c.g, c.b = r, g, b
                Changed()
                Options.RefreshControls()
            end,
            L["Tints the bundled styles, the glow and the label."], ns.CLASS_LABELS[class])
        swatch:SetPoint("TOPLEFT", 170, y - 2)
        Track(swatch)

        local badge = W.Dropdown(page, nil, 186,
            StyleOptions(class, { { value = "", text = L["Same as the badge"] } }),
            function() return cdb().badgeStyle end,
            function(v) cdb().badgeStyle = v; Changed() end)
        badge:SetPoint("TOPLEFT", 222, y)
        Track(badge)

        local marker = W.Dropdown(page, nil, 186,
            StyleOptions(class, { { value = "", text = L["Same as the marker"] }, { value = "none", text = L["Text only"] } }),
            function() return cdb().overheadStyle end,
            function(v) cdb().overheadStyle = v; Changed() end)
        marker:SetPoint("TOPLEFT", 418, y)
        Track(marker)

        y = y - 36
    end

    local note = W.Note(page, L["Give each classification its own colour and, if you like, its own style: a gold wing for elites and a star for rares, say. Blizzard styles use the game's own art for each classification and are never tinted."], 580)
    note:SetPoint("TOPLEFT", 14, y - 10)
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

-- The badge on the target unit frame (Core/TargetFrame.lua).
local function BuildTargetFrame(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Target frame badge"])
    left:Add(Check(page, L["Show the badge"], "badge", "enabled"))
    left:Add(Options.WhereDropdown(page))
    left:Add(Dropdown(page, L["Attach to"], "targetFrame", "attach", List(
        { "frame", "screen" },
        { frame = L["Target frame (found automatically)"], screen = L["Free position on screen"] }),
        L["Free position: while this window is open, a gold box marks the spot; drag it. It is also used when no target frame is found."]))
    left:Add(Dropdown(page, L["Style"], "targetFrame", "style",
        StyleOptions(nil, { { value = "", text = L["Same as the nameplate badge"] } })))
    left:Add(Dropdown(page, L["Position"], "targetFrame", "point", List(ns.PLACEMENT_ORDER, ns.PLACEMENT_NAMES)))
    left:Add(Check(page, L["Mirrored pair on both sides"], "targetFrame", "pair"))
    left:Add(Check(page, L["Flip the art"], "targetFrame", "flip"))
    left:Add(Check(page, L["Tint with the classification colour"], "targetFrame", "tint"))

    right:Header(L["Size and placement"])
    right:Add(Slider(page, L["Size"], "targetFrame", "size", 8, 128, 1))
    right:Add(Slider(page, L["Horizontal offset"], "targetFrame", "x", -150, 150, 1))
    right:Add(Slider(page, L["Vertical offset"], "targetFrame", "y", -150, 150, 1))
    right:Add(Slider(page, L["Opacity"], "targetFrame", "alpha", 0.1, 1, 0.05, "%.2f"))
    right:Add(Dropdown(page, L["Animation"], "targetFrame", "anim", List(ns.ANIM_ORDER, ns.ANIM_NAMES)))
    right:Add(Check(page, L["Glow"], "targetFrame", "glow"))
    right:Add(Slider(page, L["Glow strength"], "targetFrame", "glowAlpha", 0.1, 1, 0.05, "%.2f"))
end

local TABS = {
    { key = "general",  text = L["General"],         build = BuildGeneral },
    { key = "badge",    text = L["Nameplate Badge"], build = BuildBadge },
    { key = "overhead", text = L["Overhead Marker"], build = BuildOverhead },
    { key = "frame",    text = L["Target Frame"],    build = BuildTargetFrame },
    { key = "classes",  text = L["Classifications"], build = BuildClasses },
}

local function SelectTab(key)
    for _, tab in ipairs(TABS) do
        tab.page:SetShown(tab.key == key)
        tab.button:SetSelected(tab.key == key)
    end
    W.CloseMenu()
end

local function SavePosition(frame)
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.db.global.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function Build()
    win = CreateFrame("Frame", "EliteMobVisualsOptionsFrame", UIParent)
    win:SetSize(WIDTH, HEIGHT)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    win:SetScript("OnHide", function()
        W.CloseMenu()
        ns.TargetFrame.RefreshHandle()   -- lock the free position's drag box
    end)
    W.Skin(win, C.bg, C.border)
    tinsert(UISpecialFrames, "EliteMobVisualsOptionsFrame")

    local pos = ns.db.global.window
    if pos and pos.point then
        win:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 260, 40)
    end

    -- Header: logo, title, version, close.
    local logo = win:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.LOGO)
    logo:SetSize(44, 44)
    logo:SetPoint("TOPLEFT", 10, -6)
    local title = W.Text(win, ns.TITLE, "GameFontNormalLarge", C.gold)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 8, -6)
    local sub = W.Text(win, "v" .. ns.VERSION .. "  -  " .. L["Elite, rare and boss markers for your nameplates"],
        "GameFontHighlightSmall", C.dim)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

    local close = W.Button(win, "X", 22, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)

    BuildPreview(win)

    -- Tabs and pages.
    for i, tab in ipairs(TABS) do
        tab.button = W.Button(win, tab.text, 118, function() SelectTab(tab.key) end)
        tab.button:SetHeight(24)
        tab.button:SetPoint("TOPLEFT", 14 + (i - 1) * 123, -216)
        local page = CreateFrame("Frame", nil, win)
        page:SetPoint("TOPLEFT", 14, -246)
        page:SetPoint("BOTTOMRIGHT", -14, 46)
        W.Skin(page, C.inset)
        tab.page = page
        tab.build(page)
    end

    -- Footer: test mode and reset.
    local test = W.Check(win, L["Test mode: mark every nameplate"],
        function() return ns.Classify.testClass ~= nil end,
        function(v) ns.SetTestMode(v, previewClass) end,
        L["Marks every non-player nameplate as the previewed classification and shows the badge (and the marker, if on) on all of them, ignoring Show on and the hostility filter, so you can position the visuals on real plates. Not saved: it ends at logout."])
    test:SetPoint("BOTTOMLEFT", 16, 16)
    Track(test)

    local reset = W.Button(win, L["Reset to defaults"], 140, function() StaticPopup_Show("ELITEMOBVISUALS_RESET") end)
    reset:SetPoint("BOTTOMRIGHT", -14, 13)

    SelectTab("badge")
end

StaticPopupDialogs["ELITEMOBVISUALS_RESET"] = {
    text = L["Reset every Elite Mob Visuals setting to its default?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function() ns.ResetProfile() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function Options.Show()
    if not win then Build() end
    Options.RefreshControls()
    Options.RefreshPreview()
    win:Show()
    ns.TargetFrame.RefreshHandle()   -- show the free position's drag box
end

function Options.Toggle()
    if win and win:IsShown() then win:Hide() else Options.Show() end
end

function Options.IsShown() return win and win:IsShown() end

-- "Show minimap button", shared by the General tab and the Settings page.
function Options.MinimapCheck(parent)
    local cb = W.Check(parent, L["Show minimap button"],
        function() return not ns.db.profile.minimap.hide end,
        function(v) ns.SetMinimapShown(v) end,
        L["Left-click it to open these options. Minimap button bags and broker displays (Titan Panel, ChocolateBar) can collect it too."])
    cb.keepWidth = true
    return cb
end

-- The page in the game's Settings, under AddOns: the everyday switches, plus a
-- button to the full options window for styles, placement and colours.
function Options.RegisterSettingsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.LOGO)
    logo:SetSize(72, 72)
    logo:SetPoint("TOPLEFT", 12, -8)
    local title = W.Text(panel, ns.TITLE, "GameFontNormalHuge", C.gold)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -12)
    local desc = W.Text(panel, L["A customisable marker beside your target's nameplate when it is an elite, rare or boss, and an optional marker above their heads."], "GameFontHighlightSmall", C.dim)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(460)

    local y = -100
    local function Section(text)
        local h = W.Header(panel, text)
        h:SetPoint("TOPLEFT", 16, y)
        h:SetWidth(420)
        y = y - 28
    end
    local function Add(w, height)
        w:SetPoint("TOPLEFT", 20, y)
        Track(w)
        y = y - (height or 26)
        return w
    end

    Section(L["General"])
    Add(Check(panel, L["Enable Elite Mob Visuals"], nil, "enabled"))
    Add(Check(panel, L["Show the badge"], "badge", "enabled",
        L["The badge on elite, rare and boss mobs: on the nameplate, the target frame or both."]))
    Add(Options.WhereDropdown(panel, 300), 50)
    Add(Check(panel, L["Show the overhead marker"], "overhead", "enabled",
        L["The marker above elite and rare mobs' nameplates."]))
    Add(Check(panel, L["Only mobs you can attack"], nil, "hostileOnly",
        L["Skip friendly elites and rares, such as town guards."]))
    Add(Check(panel, L["Only while in combat"], nil, "combatOnly"))
    Add(Options.MinimapCheck(panel))
    Add(W.Check(panel, L["Test mode: mark every nameplate"],
        function() return ns.Classify.testClass ~= nil end,
        function(v) ns.SetTestMode(v, previewClass) end,
        L["Marks every non-player nameplate and shows the badge on all of them, so you can position the visuals on real plates. Not saved: it ends at logout."]))

    y = y - 8
    Section(L["Styles, placement and colours"])
    local note = W.Note(panel, L["Badge and marker styles, size, position, animation and per-classification colours are in the options window, with a live preview."], 420)
    note:SetPoint("TOPLEFT", 20, y)
    y = y - 34
    local open = W.Button(panel, L["Open options"], 160, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        Options.Show()
    end)
    open:SetPoint("TOPLEFT", 20, y)
    local reset = W.Button(panel, L["Reset to defaults"], 140, function() StaticPopup_Show("ELITEMOBVISUALS_RESET") end)
    reset:SetPoint("LEFT", open, "RIGHT", 10, 0)
    local hint = W.Text(panel, L["Or type /emv in chat."], "GameFontHighlightSmall", C.dim)
    hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)

    -- Values can change elsewhere (slash commands, the window): re-read on show.
    panel:SetScript("OnShow", function() Options.RefreshControls() end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
    Options.category = category
    Options.settingsPanel = panel
end

-- Open the game's Settings at this addon's page (falls back to the window).
function Options.OpenSettingsPage()
    if Options.category and Settings and Settings.OpenToCategory then
        local id = Options.category.GetID and Options.category:GetID() or Options.category.ID
        Settings.OpenToCategory(id)
    else
        Options.Show()
    end
end

ns.OnSettingsChanged(function() Options.RefreshPreview() end)
