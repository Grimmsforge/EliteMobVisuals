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

local WIDTH, HEIGHT = 700, 650
local COL_W = 300
local LEFT_X, RIGHT_X = 14, 356

local win
local controls = {}
local previewClass, previewTarget, previewPlates = "elite", true, true
local previewPlate, previewBar, previewSet, previewNotice
local previewFrame, previewFrameSet
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

-- The preview follows the game's rules: the mock nameplate shows while
-- "Nameplates on" is ticked, the mock target frame while the mob is "your
-- target", and each gets the badge or marker the game would put there.
function Options.RefreshPreview()
    if not previewSet then return end
    local p = P()
    local c = p.classes[previewClass]
    previewSet:HideAll()
    previewFrameSet:HideAll()
    previewPlate:SetShown(previewPlates)
    previewPlate:SetAlpha(previewTarget and 1 or 0.6)
    previewFrame:SetShown(previewTarget)
    for cls, btn in pairs(classButtons) do btn:SetSelected(cls == previewClass) end

    previewNotice:Hide()
    local function Notice(text)
        previewNotice:SetText(text)
        previewNotice:Show()
    end
    if not p.enabled or not c.show then
        Notice(not p.enabled and L["The addon is turned off (General tab)."]
            or string.format(L["%s is turned off (Classifications tab)."], ns.CLASS_LABELS[previewClass]))
        return
    end

    -- Nameplate: badge and overhead marker.
    local b, o = p.badge, p.overhead
    local showBadge = previewPlates and ns.BadgeOnNameplates(p) and (b.scope == "all" or previewTarget)
    local showOver = previewPlates and o.enabled and (o.scope == "all"
        or (o.scope == "target" and previewTarget)
        or (o.scope == "nontarget" and not previewTarget))
    if showBadge or showOver then
        -- The mock plate's frame includes its name, like Blizzard's own plates.
        local place = previewSet.place
        place.host = previewPlate
        place.badge = (p.anchor == "health") and previewBar or previewPlate
        place.over = previewPlate
        place.strata, place.level = nil, nil
        previewSet:Update(previewClass, place, showBadge, showOver, p)
    end

    -- Target frame: only for your target; always when it is ticked, else as
    -- the fallback while its nameplate isn't showing the badge.
    local tf = p.targetFrame
    local showFrame = previewTarget and (tf.enabled or (tf.fallback and not showBadge))
    if showFrame then
        local place = previewFrameSet.place
        place.host, place.badge, place.over = previewFrame, previewFrame, previewFrame
        place.strata, place.level = nil, nil
        previewFrameSet:Update(previewClass, place, true, false, p, p.targetFrame)
    end

    -- Say why the preview is empty, if it is.
    if not (showBadge or showOver or showFrame) then
        if not previewPlates and not previewTarget then
            Notice(L["Nameplates off and not your target: nothing to mark it with."])
        elseif not b.enabled and not o.enabled and not ns.BadgeOnTargetFrame(p) then
            Notice(L["Everything is turned off (Visibility tab)."])
        elseif not previewPlates then
            Notice(L["Nameplates off: only the target frame badge can show."])
        elseif not previewTarget then
            Notice(L["The target frame badge shows once the mob is your target."])
        end
    end
end

-- For the tests: set the preview's toggles, and read its two visual sets.
function Options.SetPreview(target, plates)
    previewTarget, previewPlates = target, plates
    Options.RefreshPreview()
end
function Options.PreviewSets() return previewSet, previewFrameSet end

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
    plate:SetPoint("CENTER", box, "CENTER", -190, -10)
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
    local plateCaption = W.Text(box, L["Nameplate"], "GameFontDisableSmall", C.dim)
    plateCaption:SetPoint("TOP", plate, "BOTTOM", 0, -4)

    -- A mock target unit frame, laid out like Blizzard's: name, health and
    -- mana bars, portrait on the right. Its outline is what the target frame
    -- badge attaches to.
    local tf = CreateFrame("Frame", nil, box)
    tf:SetSize(160, 54)
    tf:SetPoint("CENTER", box, "CENTER", 20, -8)
    W.Skin(tf, { 0.06, 0.05, 0.06, 0.95 }, { 0.55, 0.45, 0.22, 1 })
    local portrait = tf:CreateTexture(nil, "ARTWORK")
    portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    portrait:SetSize(44, 44)
    portrait:SetPoint("RIGHT", -5, 0)
    local tfName = W.Text(tf, L["Defias Pillager"], "GameFontNormalSmall", { 1, 0.82, 0 })
    tfName:SetPoint("TOPLEFT", 7, -6)
    local function Bar(height, y, r, g, bl, value)
        local sb = CreateFrame("StatusBar", nil, tf)
        sb:SetSize(100, height)
        sb:SetPoint("TOPLEFT", 6, y)
        sb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        sb:SetStatusBarColor(r, g, bl)
        sb:SetMinMaxValues(0, 100)
        sb:SetValue(value)
        local bg = sb:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.7)
    end
    Bar(12, -22, 0.10, 0.75, 0.10, 72)
    Bar(6, -36, 0.20, 0.35, 0.95, 100)
    previewFrame = tf
    previewFrameSet = ns.Visuals.Create(tf)
    local frameCaption = W.Text(box, L["Target frame"], "GameFontDisableSmall", C.dim)
    frameCaption:SetPoint("TOP", tf, "BOTTOM", 0, -4)

    previewNotice = W.Text(box, "", "GameFontHighlightSmall", C.dim)
    previewNotice:SetPoint("TOP", box, "TOP", -60, -8)
    previewNotice:Hide()

    for i, class in ipairs(ns.CLASSES) do
        local btn = W.Button(box, ns.CLASS_LABELS[class], 110, function() SetPreviewClass(class) end)
        btn:SetPoint("TOPRIGHT", -10, -10 - (i - 1) * 26)
        classButtons[class] = btn
    end

    local asTarget = W.Check(box, L["As your target"],
        function() return previewTarget end,
        function(v) previewTarget = v; Options.RefreshPreview() end,
        L["Preview the mob as your current target (it gets a target frame), or as another mob on screen."])
    asTarget:SetPoint("BOTTOMRIGHT", -102, 12)
    Track(asTarget)
    local platesOn = W.Check(box, L["Nameplates on"],
        function() return previewPlates end,
        function(v) previewPlates = v; Options.RefreshPreview() end,
        L["Preview with enemy nameplates on or off (V in game). With them off, the badge can only show on the target frame."])
    platesOn:SetPoint("BOTTOMLEFT", 10, 10)
    Track(platesOn)
end

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

local function BuildGeneral(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Minimap"])
    left:Add(Options.MinimapCheck(page))

    -- Which nameplate addon the visuals are fitted to.
    if ns.Plates.EllesmereLoaded() then
        left:Gap(8)
        left:Header(L["EllesmereUI Nameplates"])
        left:Add(Check(page, L["Hide EllesmereUI's own Rare/Elite icon"], nil, "hideNameplateIcons",
            L["EllesmereUI's Rare/Elite indicator uses the same Blizzard icons and has its own size and slot, which these options can't move. This hides it on mobs Elite Mob Visuals marks (it also carries EllesmereUI's quest icon there), and gives it back on every other mob."]))
        local eui = W.Note(page, L["Detected. The visuals ride EllesmereUI's own plates: beside its health bar and above its name, scaling and fading with its plates."], COL_W)
        left:Add(eui, 48)
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
local SCOPE_OVER = {
    order = { "all", "target", "nontarget" },
    names = { all = L["Every marked nameplate"], target = L["Your target only"], nontarget = L["All but your target"] },
}

-- The three visuals' on/off switches, shared by the Visibility tab and the
-- game Settings page.
local FALLBACK_LABEL = L["If the nameplate badge is off, use the target frame"]
local FALLBACK_TIP = L["Shows the badge on your target frame whenever it isn't showing on your target's nameplate: the nameplate badge is turned off, nameplates are off, or the target is out of nameplate range. Not needed when Target frame badge is ticked."]

-- Visibility: everything about what shows, and where, in one place. The
-- other tabs only set how each visual looks.
local function BuildVisibility(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Show"])
    left:Add(Check(page, L["Enable Elite Mob Visuals"], nil, "enabled"))
    left:Gap(4)
    left:Add(Check(page, L["Nameplate badge"], "badge", "enabled",
        L["The badge beside the nameplate above the mob's head (enemy nameplates on)."]))
    left:Add(Dropdown(page, L["On which nameplates"], "badge", "scope", List(SCOPE_BADGE.order, SCOPE_BADGE.names),
        L["Your target only, or every elite and rare with a nameplate on screen."]), nil, 22)
    left:Add(Check(page, L["Overhead marker"], "overhead", "enabled",
        L["The marker above elite and rare mobs' nameplates (their heads)."]))
    left:Add(Dropdown(page, L["On which nameplates"], "overhead", "scope", List(SCOPE_OVER.order, SCOPE_OVER.names)), nil, 22)
    left:Add(Check(page, L["Target frame badge"], "targetFrame", "enabled",
        L["The badge on your target's unit frame at the top of the screen (EllesmereUI's or Blizzard's), always, alongside the nameplate badge."]))
    left:Add(Check(page, FALLBACK_LABEL, "targetFrame", "fallback", FALLBACK_TIP), nil, 22)

    right:Header(L["Filters"])
    right:Add(Check(page, L["Only mobs you can attack"], nil, "hostileOnly",
        L["Skip friendly elites and rares, such as town guards."]))
    right:Add(Check(page, L["Only while in combat"], nil, "combatOnly"))
    right:Add(Check(page, L["Hide on dead mobs"], nil, "hideDead"))
    right:Gap(8)
    local note = W.Note(page, L["The preview above follows these settings. Use its Nameplates on and As your target boxes to see each case, and test mode to try them on real nameplates."], COL_W)
    right:Add(note, 60)
end

local function BuildBadge(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Nameplate badge"])
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

-- Backgrounds: a plain rectangle behind each visual's art. One set of
-- controls, pointed at the visual chosen at the top (bgTarget).
local bgTarget = "badge"
local BG_TARGETS = {
    order = { "badge", "targetFrame", "overhead" },
    names = { badge = L["Nameplate badge"], targetFrame = L["Target frame badge"], overhead = L["Overhead marker"] },
}

local function BG() return P()[bgTarget].bg end

local function BgField(key)
    return function() return BG()[key] end,
           function(v) BG()[key] = v; Changed() end
end

local function BgCheck(page, label, key, tip)
    local get, set = BgField(key)
    local cb = W.Check(page, label, get, set, tip)
    cb.keepWidth = true
    return cb
end

local function BgSlider(page, label, key, minV, maxV, step, fmt)
    local get, set = BgField(key)
    return W.Slider(page, label, minV, maxV, step, get, set, fmt, COL_W)
end

-- A label with a colour swatch at the right.
local function BgColorRow(page, label, key)
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(COL_W, 22)
    local text = W.Text(row, label)
    text:SetPoint("LEFT")
    local swatch = W.Color(row,
        function() return BG()[key] end,
        function(r, g, b)
            local c = BG()[key]
            c.r, c.g, c.b = r, g, b
            Changed()
        end, nil, label)
    swatch:SetPoint("RIGHT")
    function row:Refresh() swatch:Refresh() end
    row.height = 28
    return row
end

local function BuildBackground(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Background"])
    left:Add(W.Dropdown(page, L["Background for"], COL_W, List(BG_TARGETS.order, BG_TARGETS.names),
        function() return bgTarget end,
        function(v) bgTarget = v; Options.RefreshControls() end,
        L["Each visual has its own background. Pick one, then set it up below."]))
    left:Add(BgCheck(page, L["Show a background"], "enabled",
        L["A plain rectangle behind the icon, sized however you like."]))
    left:Add(BgSlider(page, L["Width"], "width", 4, 200, 1))
    left:Add(BgSlider(page, L["Height"], "height", 4, 200, 1))
    left:Add(BgSlider(page, L["Horizontal offset"], "x", -60, 60, 1))
    left:Add(BgSlider(page, L["Vertical offset"], "y", -60, 60, 1))

    right:Header(L["Colour and border"])
    right:Add(BgColorRow(page, L["Background colour"], "color"))
    right:Add(BgSlider(page, L["Background opacity"], "alpha", 0, 1, 0.05, "%.2f"))
    right:Add(BgCheck(page, L["Border"], "border"))
    right:Add(BgCheck(page, L["Tint the border with the classification colour"], "borderTint",
        L["Gold for elites, blue for rare elites and so on (the Classifications tab sets them). Overrides the border colour below."]))
    right:Add(BgColorRow(page, L["Border colour"], "borderColor"))
    right:Add(BgSlider(page, L["Border thickness"], "borderSize", 1, 6, 1))
    local note = W.Note(page, L["The preview above shows it. A mirrored pair gets a background each; a text-only marker's background frames its label."], COL_W)
    right:Add(note, 40)
end

local TABS = {
    { key = "general",  text = L["General"],         build = BuildGeneral },
    { key = "visible",  text = L["Visibility"],      build = BuildVisibility },
    { key = "badge",    text = L["Nameplate Badge"], build = BuildBadge },
    { key = "overhead", text = L["Overhead Marker"], build = BuildOverhead },
    { key = "frame",    text = L["Target Frame"],    build = BuildTargetFrame },
    { key = "bg",       text = L["Background"],      build = BuildBackground },
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
        tab.button = W.Button(win, tab.text, 92, function() SelectTab(tab.key) end)
        tab.button:SetHeight(24)
        tab.button:SetPoint("TOPLEFT", 14 + (i - 1) * 96, -216)
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
    Add(Check(panel, L["Nameplate badge"], "badge", "enabled",
        L["The badge beside the nameplate above the mob's head."]))
    Add(Check(panel, L["Overhead marker"], "overhead", "enabled",
        L["The marker above elite and rare mobs' nameplates."]))
    Add(Check(panel, L["Target frame badge"], "targetFrame", "enabled",
        L["The badge on your target's unit frame, always."]))
    local fallback = Add(Check(panel, FALLBACK_LABEL, "targetFrame", "fallback", FALLBACK_TIP))
    fallback:ClearAllPoints()
    fallback:SetPoint("TOPLEFT", 42, y + 26)
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
