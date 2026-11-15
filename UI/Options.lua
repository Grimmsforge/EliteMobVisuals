-- =============================================================================
-- Elite Mob Visuals: options window
-- A small movable window (/emv) rather than the full-screen Settings panel, so
-- the nameplates stay in view while positioning. A sidebar on the left lists
-- the pages; a live preview, drawn with the same code as the real visuals,
-- shows what the selected page edits. The game's Settings list gets a short
-- page with the everyday switches and a button that opens this window.
--
-- Pages: General, Visibility, Nameplate > Badge / Marker, Target frame >
-- Badge / Marker, Classifications. The four visual pages share one builder:
-- look, size and placement, style per classification and background.
-- =============================================================================
local _, ns = ...
local L = ns.L
local W = ns.Widgets
local C = W.C
local Media = ns.Media

local Options = {}
ns.Options = Options

local WIDTH, HEIGHT = 840, 660
local NAV_W = 150
local CONTENT_X = 14 + NAV_W + 10          -- where the preview and pages start
local COL_W = 300
local LEFT_X, RIGHT_X = 10, 330            -- the two columns inside a page

local win
local controls = {}
local currentPage = "visible"
local previewClass, previewTarget, previewPlates = "elite", true, true
local previewPlate, previewBar, previewSet, previewNotice
local previewFrame, previewFrameSet, previewToggles
local plateCaption, frameCaption
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

-- How far down the page being built goes, so it knows how far to scroll.
local deepest = 0

local function Column(page, x)
    local col = { y = -10 }
    local function Reach(self) deepest = math.min(deepest, self.y) end
    function col:Add(w, height, indent)
        w:SetPoint("TOPLEFT", page, "TOPLEFT", x + (indent or 0), self.y)
        if w.SetWidth and not w.keepWidth then w:SetWidth(COL_W - (indent or 0)) end
        self.y = self.y - (height or w.height or 24)
        Reach(self)
        return Track(w)
    end
    function col:Header(text)
        local h = W.Header(page, text)
        h:SetPoint("TOPLEFT", page, "TOPLEFT", x, self.y)
        h:SetWidth(COL_W)
        self.y = self.y - 26
        Reach(self)
        return h
    end
    function col:Gap(px) self.y = self.y - px; Reach(self) end
    return col
end

-- Line both columns up below whichever reaches lower, for a new section.
local function Sync(left, right, gap)
    local y = math.min(left.y, right.y) - (gap or 10)
    left.y, right.y = y, y
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
-- extra: entries to list first, such as "same as above" or "text only".
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

-- A label with a colour swatch at the right. get() returns { r, g, b }.
local function ColorRow(page, label, get, tip)
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(COL_W, 22)
    local text = W.Text(row, label)
    text:SetPoint("LEFT")
    local swatch = W.Color(row, get,
        function(r, g, b)
            local c = get()
            c.r, c.g, c.b = r, g, b
            Changed()
        end, tip, label)
    swatch:SetPoint("RIGHT")
    function row:Refresh() swatch:Refresh() end
    row.height = 28
    return row
end

-- ---------------------------------------------------------------------------
-- Preview
-- Each page previews what it edits: a visual's page shows that visual alone,
-- on its mock nameplate or mock target frame, even while the Visibility page
-- has it off (so it can be set up first). General, Visibility and
-- Classifications show everything, following the Visibility rules, with the
-- "Nameplates on" and "As your target" toggles to try each case.
-- ---------------------------------------------------------------------------

local PREVIEW_MODE = {
    general = "all", visible = "all", classes = "all",
    npBadge = "npBadge", npMarker = "npMarker", tfBadge = "tfBadge", tfMarker = "tfMarker",
}
-- Where the mocks sit: side by side, or the one in use centred.
local PLATE_X, FRAME_X, FOCUS_X = -200, 20, -60

local function PlacePreview(mode)
    previewPlate:ClearAllPoints()
    previewFrame:ClearAllPoints()
    local focused = mode ~= "all"
    previewPlate:SetPoint("CENTER", previewPlate:GetParent(), "CENTER", focused and FOCUS_X or PLATE_X, -10)
    previewFrame:SetPoint("CENTER", previewFrame:GetParent(), "CENTER", focused and FOCUS_X or FRAME_X, -14)
    previewToggles:SetShown(not focused)
end

local function PlatePlace(p)
    -- The mock plate's frame includes its name, like Blizzard's own plates.
    local place = previewSet.place
    place.host = previewPlate
    place.badge = (p.anchor == "health") and previewBar or previewPlate
    place.over = previewPlate
    place.strata, place.level = nil, nil
    return place
end

local function FramePlace()
    local place = previewFrameSet.place
    place.host, place.badge, place.over = previewFrame, previewFrame, previewFrame
    place.strata, place.level = nil, nil
    return place
end

function Options.RefreshPreview()
    if not previewSet then return end
    local p = P()
    local c = p.classes[previewClass]
    local mode = PREVIEW_MODE[currentPage] or "all"
    PlacePreview(mode)
    previewSet:HideAll()
    previewFrameSet:HideAll()
    for cls, btn in pairs(classButtons) do btn:SetSelected(cls == previewClass) end

    previewNotice:Hide()
    local function Notice(text)
        previewNotice:SetText(text)
        previewNotice:Show()
    end

    if mode ~= "all" then
        -- One visual, alone, whatever the Visibility page says.
        local onPlate = (mode == "npBadge" or mode == "npMarker")
        previewPlate:SetShown(onPlate)
        previewPlate:SetAlpha(1)
        previewFrame:SetShown(not onPlate)
        plateCaption:SetShown(onPlate)
        frameCaption:SetShown(not onPlate)
        if onPlate then
            previewSet:Update(previewClass, PlatePlace(p), mode == "npBadge", mode == "npMarker", p)
        else
            previewFrameSet:Update(previewClass, FramePlace(), mode == "tfBadge", mode == "tfMarker", p,
                p.targetFrame, p.targetMarker)
        end
        local on = (mode == "npBadge" and p.badge.enabled) or (mode == "npMarker" and p.overhead.enabled)
            or (mode == "tfBadge" and ns.BadgeOnTargetFrame(p)) or (mode == "tfMarker" and ns.MarkerOnTargetFrame(p))
        if not p.enabled or not c.show or not on then
            Notice(L["Off on the Visibility page: shown here so you can set it up."])
        end
        return
    end

    previewPlate:SetShown(previewPlates)
    previewPlate:SetAlpha(previewTarget and 1 or 0.6)
    previewFrame:SetShown(previewTarget)
    plateCaption:SetShown(true)
    frameCaption:SetShown(true)
    if not p.enabled or not c.show then
        Notice(not p.enabled and L["The addon is turned off (Visibility page)."]
            or string.format(L["%s is turned off (Classifications page)."], ns.CLASS_LABELS[previewClass]))
        return
    end

    -- Nameplate: badge and marker.
    local b, o = p.badge, p.overhead
    local showBadge = previewPlates and b.enabled and (b.scope == "all" or previewTarget)
    local showOver = previewPlates and o.enabled and (o.scope == "all"
        or (o.scope == "target" and previewTarget)
        or (o.scope == "nontarget" and not previewTarget))
    if showBadge or showOver then
        previewSet:Update(previewClass, PlatePlace(p), showBadge, showOver, p)
    end

    -- Target frame: only for your target; each always when ticked, else as
    -- the fallback while its nameplate counterpart isn't showing.
    local tf, tm = p.targetFrame, p.targetMarker
    local frameBadge = previewTarget and (tf.enabled or (tf.fallback and not showBadge))
    local frameMarker = previewTarget and (tm.enabled or (tm.fallback and not showOver))
    if frameBadge or frameMarker then
        previewFrameSet:Update(previewClass, FramePlace(), frameBadge, frameMarker, p, tf, tm)
    end

    -- Say why the preview is empty, if it is.
    if not (showBadge or showOver or frameBadge or frameMarker) then
        if not previewPlates and not previewTarget then
            Notice(L["Nameplates off and not your target: nothing to mark it with."])
        elseif not previewPlates then
            Notice(L["Nameplates off: only the target frame visuals can show."])
        elseif not previewTarget then
            Notice(L["The target frame visuals show once the mob is your target."])
        else
            Notice(L["Everything is turned off (Visibility page)."])
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
    box:SetPoint("TOPLEFT", CONTENT_X, -58)
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
    plateCaption = W.Text(box, L["Nameplate"], "GameFontDisableSmall", C.dim)
    plateCaption:SetPoint("TOP", plate, "BOTTOM", 0, -4)

    -- A mock target unit frame, laid out like Blizzard's: name, health and
    -- mana bars, portrait on the right. Its outline is what the target frame
    -- badge and marker attach to.
    local tf = CreateFrame("Frame", nil, box)
    tf:SetSize(160, 54)
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
    frameCaption = W.Text(box, L["Target frame"], "GameFontDisableSmall", C.dim)
    frameCaption:SetPoint("TOP", tf, "BOTTOM", 0, -4)

    previewNotice = W.Text(box, "", "GameFontHighlightSmall", C.dim)
    previewNotice:SetPoint("TOP", box, "TOP", -60, -8)
    previewNotice:Hide()

    for i, class in ipairs(ns.CLASSES) do
        local btn = W.Button(box, ns.CLASS_LABELS[class], 110, function() SetPreviewClass(class) end)
        btn:SetPoint("TOPRIGHT", -10, -10 - (i - 1) * 26)
        classButtons[class] = btn
    end

    -- The toggles, for the pages that preview everything.
    previewToggles = CreateFrame("Frame", nil, box)
    previewToggles:SetAllPoints()
    local asTarget = W.Check(previewToggles, L["As your target"],
        function() return previewTarget end,
        function(v) previewTarget = v; Options.RefreshPreview() end,
        L["Preview the mob as your current target (it gets a target frame), or as another mob on screen."])
    asTarget:SetPoint("BOTTOMRIGHT", -102, 12)
    Track(asTarget)
    local platesOn = W.Check(previewToggles, L["Nameplates on"],
        function() return previewPlates end,
        function(v) previewPlates = v; Options.RefreshPreview() end,
        L["Preview with enemy nameplates on or off (V in game). With them off, only the target frame visuals can show."])
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
    right:Add(Dropdown(page, L["Nameplate visuals attach to"], nil, "anchor", List(
        { "health", "plate" },
        { health = L["Health bar and name (recommended)"], plate = L["Nameplate frame (click box)"] }),
        L["Health bar and name: the badge sits beside the health bar and the marker above the name, on Blizzard, EllesmereUI, Plater, ElvUI and KuiNameplates plates (any other falls back to the nameplate frame). Nameplate frame: Blizzard's click box, which nameplate addons size in their own ways."]))
    right:Add(Dropdown(page, L["Target frame visuals attach to"], "targetFrame", "attach", List(
        { "frame", "screen" },
        { frame = L["Target frame (found automatically)"], screen = L["Free position on screen"] }),
        L["Target frame: EllesmereUI's, Blizzard's, ElvUI's or Shadowed Unit Frames', whichever is in use. Free position: while this window is open a gold box marks the spot; drag it. Also used when no target frame is found."]))
    local note = W.Note(page, L["Every nameplate addon draws its plate differently. Pick the anchor that sits best, then fine-tune with each visual's offsets."], COL_W)
    right:Add(note, 48)

    right:Header(L["Slash commands"])
    local cmds = W.Note(page,
        "|cffe8b23a/emv|r  " .. L["open these options"] .. "\n" ..
        "|cffe8b23a/emv test|r  " .. L["mark every nameplate, to position visuals"] .. "\n" ..
        "|cffe8b23a/emv test rare|r  " .. L["the same, as a chosen classification"] .. "\n" ..
        "|cffe8b23a/emv on|r, |cffe8b23a/emv off|r  " .. L["turn the addon on or off"] .. "\n" ..
        "|cffe8b23a/emv minimap|r  " .. L["show or hide the minimap button"] .. "\n" ..
        "|cffe8b23a/emv debug|r  " .. L["what the addon sees, for bug reports"] .. "\n" ..
        "|cffe8b23a/emv reset|r  " .. L["back to the defaults"], COL_W)
    right:Add(cmds, 110)
end

local SCOPE_BADGE = { order = { "target", "all" }, names = { target = L["Your target only"], all = L["Every marked nameplate"] } }
local SCOPE_OVER = {
    order = { "all", "target", "nontarget" },
    names = { all = L["Every marked nameplate"], target = L["Your target only"], nontarget = L["All but your target"] },
}

-- The four visuals' on/off switches, shared by the Visibility page and the
-- game Settings page.
local FALLBACK_BADGE = L["If the nameplate badge is off, use the target frame"]
local FALLBACK_BADGE_TIP = L["Shows the badge on your target frame whenever it isn't showing on your target's nameplate: the nameplate badge is turned off, nameplates are off, or the target is out of nameplate range. Not needed when Target frame badge is ticked."]
local FALLBACK_MARKER = L["If the nameplate marker is off, use the target frame"]
local FALLBACK_MARKER_TIP = L["Shows the marker above your target frame whenever it isn't showing above your target's nameplate: the nameplate marker is turned off, nameplates are off, or the target is out of nameplate range. Not needed when Target frame marker is ticked."]

-- Visibility: everything about what shows, and where, in one place. The
-- visual pages only set how each one looks.
local function BuildVisibility(page)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)

    left:Header(L["Addon"])
    left:Add(Check(page, L["Enable Elite Mob Visuals"], nil, "enabled"))

    left:Gap(6)
    left:Header(L["Nameplate"])
    left:Add(Check(page, L["Badge"], "badge", "enabled",
        L["The badge beside the nameplate above the mob's head (enemy nameplates on)."]))
    left:Add(Dropdown(page, L["On which nameplates"], "badge", "scope", List(SCOPE_BADGE.order, SCOPE_BADGE.names),
        L["Your target only, or every elite and rare with a nameplate on screen."]), nil, 22)
    left:Add(Check(page, L["Marker"], "overhead", "enabled",
        L["The marker above elite and rare mobs' nameplates (their heads)."]))
    left:Add(Dropdown(page, L["On which nameplates"], "overhead", "scope", List(SCOPE_OVER.order, SCOPE_OVER.names)), nil, 22)

    right:Header(L["Target frame"])
    right:Add(Check(page, L["Badge"], "targetFrame", "enabled",
        L["The badge on your target's unit frame at the top of the screen (EllesmereUI's or Blizzard's), always, alongside the nameplate badge."]))
    right:Add(Check(page, FALLBACK_BADGE, "targetFrame", "fallback", FALLBACK_BADGE_TIP), nil, 22)
    right:Add(Check(page, L["Marker"], "targetMarker", "enabled",
        L["The marker above your target's unit frame, always, alongside the nameplate marker."]))
    right:Add(Check(page, FALLBACK_MARKER, "targetMarker", "fallback", FALLBACK_MARKER_TIP), nil, 22)

    right:Gap(6)
    right:Header(L["Filters"])
    right:Add(Check(page, L["Only mobs you can attack"], nil, "hostileOnly",
        L["Skip friendly elites and rares, such as town guards."]))
    right:Add(Check(page, L["Only while in combat"], nil, "combatOnly"))
    right:Add(Check(page, L["Hide on dead mobs"], nil, "hideDead"))

    Sync(left, right)
    local note = W.Note(page, L["The preview above follows these settings: use its Nameplates on and As your target boxes to see each case, and test mode to try them on real nameplates."], COL_W * 2)
    note.keepWidth = true
    left:Add(note, 40)
end

-- One visual's page. v: { section, kind = "badge" | "marker", parent =
-- "badge" | "overhead" for the target frame ones, frame = true for those }.
local function BuildVisual(page, v)
    local left, right = Column(page, LEFT_X), Column(page, RIGHT_X)
    local s, isMarker = v.section, v.kind == "marker"

    -- Look.
    left:Header(L["Look"])
    local extra = {}
    if v.parent then
        extra[#extra + 1] = { value = "", text = isMarker and L["Same as the nameplate marker"] or L["Same as the nameplate badge"] }
    end
    if isMarker then extra[#extra + 1] = { value = "none", text = L["Text only"] } end
    left:Add(Dropdown(page, L["Style"], s, "style", StyleOptions(nil, extra),
        L["Bundled styles take the classification colour. Blizzard styles use the game's own art for each classification."]))
    if not isMarker then
        left:Add(Dropdown(page, L["Position"], s, "point", List(ns.PLACEMENT_ORDER, ns.PLACEMENT_NAMES)))
        left:Add(Check(page, L["Mirrored pair on both sides"], s, "pair",
            L["A second badge on the opposite side, mirrored. Applies to the left, right and corner positions."]))
        left:Add(Check(page, L["Flip the art"], s, "flip",
            L["Art that points one way (wings, dragons) already faces outward; this turns it around."]))
    end
    left:Add(Check(page, L["Tint with the classification colour"], s, "tint"))
    left:Add(Check(page, L["Glow"], s, "glow"))
    if isMarker then
        left:Add(Check(page, L["Show a text label"], s, "label",
            L["Elite, Rare Elite, Rare or Boss, in the classification colour."]))
        left:Add(Dropdown(page, L["Label position"], s, "labelPos",
            List({ "above", "below" }, { above = L["Above the marker"], below = L["Below the marker"] })))
    end

    -- Size and placement.
    right:Header(L["Size and placement"])
    right:Add(Slider(page, L["Size"], s, "size", 8, v.frame and 128 or 96, 1))
    right:Add(Slider(page, L["Width"], s, "width", 0.5, 2.5, 0.05, "x%.2f"))
    right:Add(Slider(page, L["Horizontal offset"], s, "x", -150, 150, 1))
    if isMarker then
        right:Add(Slider(page, v.frame and L["Height above the frame"] or L["Height above the plate"], s, "y", -40, 150, 1))
    else
        right:Add(Slider(page, L["Vertical offset"], s, "y", -150, 150, 1))
    end
    right:Add(Slider(page, L["Opacity"], s, "alpha", 0.1, 1, 0.05, "%.2f"))
    right:Add(Dropdown(page, L["Animation"], s, "anim", List(ns.ANIM_ORDER, ns.ANIM_NAMES),
        L["Moves the icon only: a background stays still behind it."]))
    right:Add(Slider(page, L["Glow strength"], s, "glowAlpha", 0.1, 1, 0.05, "%.2f"))
    if isMarker then right:Add(Slider(page, L["Label size"], s, "labelSize", 8, 24, 1)) end

    -- Style per classification.
    Sync(left, right)
    left:Header(L["Style per classification"])
    local same = { { value = "", text = L["Same as the style above"] } }
    if isMarker then same[2] = { value = "none", text = L["Text only"] } end
    for _, class in ipairs(ns.CLASSES) do
        left:Add(W.Dropdown(page, ns.CLASS_LABELS[class], COL_W, StyleOptions(class, same),
            function() return P()[s].classStyles[class] end,
            function(value) P()[s].classStyles[class] = value; Changed() end,
            L["This classification's own style. Same as the style above: the Style chosen at the top."]))
    end

    -- Background.
    right:Header(L["Background"])
    local function bg() return P()[s].bg end
    local function BgCheck(label, key, tip)
        local cb = W.Check(page, label, function() return bg()[key] end,
            function(value) bg()[key] = value; Changed() end, tip)
        cb.keepWidth = true
        return cb
    end
    local function BgSlider(label, key, minV, maxV, step, fmt)
        return W.Slider(page, label, minV, maxV, step,
            function() return bg()[key] end,
            function(value) bg()[key] = value; Changed() end, fmt, COL_W)
    end
    right:Add(BgCheck(L["Show a background"], "enabled", L["A plain rectangle behind the icon, sized however you like."]))
    right:Add(BgSlider(L["Width"], "width", 4, 200, 1))
    right:Add(BgSlider(L["Height"], "height", 4, 200, 1))
    right:Add(BgSlider(L["Horizontal offset"], "x", -60, 60, 1))
    right:Add(BgSlider(L["Vertical offset"], "y", -60, 60, 1))
    right:Add(ColorRow(page, L["Background colour"], function() return bg().color end))
    right:Add(BgSlider(L["Background opacity"], "alpha", 0, 1, 0.05, "%.2f"))
    right:Add(BgCheck(L["Border"], "border"))
    right:Add(BgCheck(L["Tint the border with the classification colour"], "borderTint",
        L["Gold for elites, blue for rare elites and so on (the Classifications page sets them). Overrides the border colour below."]))
    right:Add(ColorRow(page, L["Border colour"], function() return bg().borderColor end))
    right:Add(BgSlider(L["Border thickness"], "borderSize", 1, 6, 1))
end

local function BuildClasses(page)
    local cols = { { L["Classification"], 14 }, { L["Show"], 140 }, { L["Colour"], 190 } }
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
        show:SetPoint("TOPLEFT", 144, y - 3)
        Track(show)

        local swatch = W.Color(page,
            function() return cdb().color end,
            function(r, g, b)
                local c = cdb().color
                c.r, c.g, c.b = r, g, b
                Changed()
                Options.RefreshControls()
            end,
            L["Tints the bundled styles, the glow, the label and a tinted border."], ns.CLASS_LABELS[class])
        swatch:SetPoint("TOPLEFT", 190, y - 2)
        Track(swatch)

        y = y - 32
    end

    local note = W.Note(page, L["Each classification's colour tints the bundled styles, glows, labels and tinted borders. Its own style for each visual is on that visual's page, under Style per classification. Blizzard styles use the game's own art for each classification and are never tinted."], 600)
    note:SetPoint("TOPLEFT", 14, y - 10)
    page.contentHeight = -y + 70
end

-- ---------------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------------

-- The sidebar: group headings, and pages beneath them.
local PAGES = {
    { key = "general",  text = L["General"],    build = BuildGeneral },
    { key = "visible",  text = L["Visibility"], build = BuildVisibility },
    { group = L["Nameplate"] },
    { key = "npBadge",  text = L["Badge"],  sub = true,  build = function(pg) BuildVisual(pg, { section = "badge", kind = "badge" }) end },
    { key = "npMarker", text = L["Marker"], sub = true, build = function(pg) BuildVisual(pg, { section = "overhead", kind = "marker" }) end },
    { group = L["Target frame"] },
    { key = "tfBadge",  text = L["Badge"],  sub = true,  build = function(pg) BuildVisual(pg, { section = "targetFrame", kind = "badge", parent = "badge", frame = true }) end },
    { key = "tfMarker", text = L["Marker"], sub = true, build = function(pg) BuildVisual(pg, { section = "targetMarker", kind = "marker", parent = "overhead", frame = true }) end },
    { group = "" },
    { key = "classes",  text = L["Classifications"], build = BuildClasses },
}

function Options.SelectPage(key)
    if not win then return end
    for _, pg in ipairs(PAGES) do
        if pg.key then
            pg.page:SetShown(pg.key == key)
            pg.button:SetSelected(pg.key == key)
        end
    end
    currentPage = key
    W.CloseMenu()
    Options.RefreshPreview()
end

local function SavePosition(frame)
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.db.global.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function BuildSidebar()
    local nav = CreateFrame("Frame", nil, win)
    nav:SetPoint("TOPLEFT", 14, -58)
    nav:SetPoint("BOTTOMLEFT", 14, 46)
    nav:SetWidth(NAV_W)
    W.Skin(nav, C.inset)

    local y = -8
    for _, pg in ipairs(PAGES) do
        if pg.group then
            y = y - 6
            if pg.group ~= "" then
                local h = W.Text(nav, pg.group:upper(), "GameFontNormalSmall", C.gold)
                h:SetPoint("TOPLEFT", 10, y - 2)
                y = y - 18
            end
        else
            local b = W.Button(nav, pg.text, NAV_W - 12, function() Options.SelectPage(pg.key) end)
            b:SetHeight(24)
            b:SetPoint("TOPLEFT", 6, y)
            b.text:ClearAllPoints()
            b.text:SetPoint("LEFT", pg.sub and 20 or 10, 0)
            pg.button = b
            y = y - 28
        end
    end
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
        win:SetPoint("CENTER", UIParent, "CENTER", 200, 40)
    end

    -- Header: logo, title, version, close.
    local logo = win:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(ns.LOGO)
    logo:SetSize(44, 44)
    logo:SetPoint("TOPLEFT", 10, -6)
    local title = W.Text(win, ns.TITLE, "GameFontNormalLarge", C.gold)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 8, -6)
    local sub = W.Text(win, "v" .. ns.VERSION .. "  -  " .. L["Elite, rare and boss markers for your nameplates and target frame"],
        "GameFontHighlightSmall", C.dim)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

    local close = W.Button(win, "X", 22, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)

    BuildPreview(win)
    BuildSidebar()

    -- Pages: each scrolls inside the area under the preview.
    for _, pg in ipairs(PAGES) do
        if pg.key then
            local holder = CreateFrame("Frame", nil, win)
            holder:SetPoint("TOPLEFT", CONTENT_X, -216)
            holder:SetPoint("BOTTOMRIGHT", -14, 46)
            W.Skin(holder, C.inset)
            local scroll, child = W.ScrollPage(holder)
            child:SetWidth(WIDTH - CONTENT_X - 14 - 16)
            pg.page, pg.child = holder, child

            deepest = 0
            pg.build(child)
            scroll:SetContentHeight(child.contentHeight or (-deepest + 16))
        end
    end

    -- Footer: test mode and reset.
    local test = W.Check(win, L["Test mode: mark every nameplate"],
        function() return ns.Classify.testClass ~= nil end,
        function(v) ns.SetTestMode(v, previewClass) end,
        L["Marks every non-player nameplate (and your target) as the previewed classification and shows the nameplate visuals on all of them, ignoring which nameplates they're set to and the hostility filter, so you can position them on real plates. Not saved: it ends at logout."])
    test:SetPoint("BOTTOMLEFT", 16, 16)
    Track(test)

    local reset = W.Button(win, L["Reset to defaults"], 140, function() StaticPopup_Show("ELITEMOBVISUALS_RESET") end)
    reset:SetPoint("BOTTOMRIGHT", -14, 13)

    Options.SelectPage(currentPage)
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

-- "Show minimap button", shared by the General page and the Settings page.
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
    local desc = W.Text(panel, L["A customisable marker for elite, rare and boss mobs: beside and above their nameplates, and on your target frame."], "GameFontHighlightSmall", C.dim)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(460)

    local y = -100
    local function Section(text)
        local h = W.Header(panel, text)
        h:SetPoint("TOPLEFT", 16, y)
        h:SetWidth(420)
        y = y - 28
    end
    local function Add(w, indent)
        w:SetPoint("TOPLEFT", 20 + (indent or 0), y)
        Track(w)
        y = y - 26
        return w
    end

    Section(L["Visibility"])
    Add(Check(panel, L["Enable Elite Mob Visuals"], nil, "enabled"))
    Add(Check(panel, L["Nameplate badge"], "badge", "enabled",
        L["The badge beside the nameplate above the mob's head."]))
    Add(Check(panel, L["Nameplate marker"], "overhead", "enabled",
        L["The marker above elite and rare mobs' nameplates."]))
    Add(Check(panel, L["Target frame badge"], "targetFrame", "enabled",
        L["The badge on your target's unit frame, always."]))
    Add(Check(panel, FALLBACK_BADGE, "targetFrame", "fallback", FALLBACK_BADGE_TIP), 22)
    Add(Check(panel, L["Target frame marker"], "targetMarker", "enabled",
        L["The marker above your target's unit frame, always."]))
    Add(Check(panel, FALLBACK_MARKER, "targetMarker", "fallback", FALLBACK_MARKER_TIP), 22)
    Add(Check(panel, L["Only mobs you can attack"], nil, "hostileOnly",
        L["Skip friendly elites and rares, such as town guards."]))
    Add(Check(panel, L["Only while in combat"], nil, "combatOnly"))
    Add(Options.MinimapCheck(panel))
    Add(W.Check(panel, L["Test mode: mark every nameplate"],
        function() return ns.Classify.testClass ~= nil end,
        function(v) ns.SetTestMode(v, previewClass) end,
        L["Marks every non-player nameplate, so you can position the visuals on real plates. Not saved: it ends at logout."]))

    y = y - 8
    Section(L["Styles, placement and colours"])
    local note = W.Note(panel, L["Each visual's style, size, position, animation, background and per-classification styles are in the options window, with a live preview."], 420)
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
