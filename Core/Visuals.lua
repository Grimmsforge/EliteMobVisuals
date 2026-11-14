-- =============================================================================
-- Elite Mob Visuals: the visuals on one nameplate
-- A visual set belongs to one nameplate frame (plates are recycled, so the set
-- is too) and holds up to three elements, each created on first use:
--   badge   the badge beside the plate
--   badge2  its mirrored pair on the opposite side
--   overhead the marker above the plate (the mob's head), with an optional label
-- The options preview draws with this same code on a mock plate.
-- =============================================================================
local _, ns = ...
local L = ns.L
local Media = ns.Media
local Readable = ns.Readable

local Visuals = {}
ns.Visuals = Visuals

-- Where a badge sits. Key: the point on the plate. my: the badge's own point
-- placed there, so the badge sits outside the plate. side: which way the badge
-- faces outward. mirror: the matching point on the opposite side, for pairs.
ns.PLACEMENTS = {
    LEFT        = { my = "RIGHT",       side = "left",  mirror = "RIGHT" },
    RIGHT       = { my = "LEFT",        side = "right", mirror = "LEFT" },
    TOP         = { my = "BOTTOM" },
    BOTTOM      = { my = "TOP" },
    CENTER      = { my = "CENTER" },
    TOPLEFT     = { my = "BOTTOMLEFT",  side = "left",  mirror = "TOPRIGHT" },
    TOPRIGHT    = { my = "BOTTOMRIGHT", side = "right", mirror = "TOPLEFT" },
    BOTTOMLEFT  = { my = "TOPLEFT",     side = "left",  mirror = "BOTTOMRIGHT" },
    BOTTOMRIGHT = { my = "TOPRIGHT",    side = "right", mirror = "BOTTOMLEFT" },
}
ns.PLACEMENT_ORDER = { "LEFT", "RIGHT", "TOP", "BOTTOM", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" }
ns.PLACEMENT_NAMES = {
    LEFT = L["Left of plate"], RIGHT = L["Right of plate"],
    TOP = L["Above plate"], BOTTOM = L["Below plate"], CENTER = L["Centre of plate"],
    TOPLEFT = L["Above, left end"], TOPRIGHT = L["Above, right end"],
    BOTTOMLEFT = L["Below, left end"], BOTTOMRIGHT = L["Below, right end"],
}

ns.ANIM_ORDER = { "none", "pulse", "breathe", "bob", "spin" }
ns.ANIM_NAMES = {
    none = L["None"], pulse = L["Pulse"], breathe = L["Breathe"], bob = L["Bob"], spin = L["Spin"],
}

ns.CLASS_LABELS = {
    elite = L["Elite"], rareelite = L["Rare Elite"], rare = L["Rare"], worldboss = L["Boss"],
}

-- ---------------------------------------------------------------------------
-- Elements
-- ---------------------------------------------------------------------------

local function CreateElement(parent, withLabel)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(1, 1)
    f:Hide()
    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetTexture(Media.GLOW)
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("CENTER")
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    if withLabel then
        f.label = f:CreateFontString(nil, "OVERLAY")
        f.label:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        f.label:Hide()
    end
    return f
end

-- Animations are built the first time each kind is used. Spin turns the art
-- only; the rest move the whole element (art, glow and label).
local function BuildAnim(f, kind)
    local group, anim
    if kind == "spin" then
        group = f.tex:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        anim = group:CreateAnimation("Rotation")
        anim:SetDegrees(-360)
        anim:SetDuration(4)
    else
        group = f:CreateAnimationGroup()
        group:SetLooping("BOUNCE")
        if kind == "pulse" then
            anim = group:CreateAnimation("Alpha")
            anim:SetFromAlpha(1)
            anim:SetToAlpha(0.35)
            anim:SetDuration(0.8)
        elseif kind == "breathe" then
            anim = group:CreateAnimation("Scale")
            anim:SetScaleFrom(1, 1)
            anim:SetScaleTo(1.18, 1.18)
            anim:SetOrigin("CENTER", 0, 0)
            anim:SetDuration(0.9)
        else -- bob
            anim = group:CreateAnimation("Translation")
            anim:SetOffset(0, 5)
            anim:SetDuration(0.7)
        end
        anim:SetSmoothing("IN_OUT")
    end
    return group
end

-- Call after Show(): a hidden element's animation does not keep playing.
local function SetAnim(f, kind)
    if not ns.ANIM_NAMES[kind] then kind = "none" end
    f.anims = f.anims or {}
    if f.animKind ~= kind then
        for _, group in pairs(f.anims) do group:Stop() end
        f.animKind = kind
    end
    if kind ~= "none" then
        local group = f.anims[kind]
        if not group then
            group = BuildAnim(f, kind)
            f.anims[kind] = group
        end
        if not group:IsPlaying() then group:Play() end
    end
end

-- Draw a style spec into an element. opts: the badge or overhead settings.
local function Paint(f, spec, opts, color, mirrored)
    local size = opts.size
    local w = size * (spec.aspect or 1)
    f:SetSize(w, size)

    local tex = f.tex
    tex:SetTexture(spec.file)
    local l, r, t, b = spec.coords[1], spec.coords[2], spec.coords[3], spec.coords[4]
    if mirrored then
        tex:SetTexCoord(r, l, t, b)
    else
        tex:SetTexCoord(l, r, t, b)
    end
    if opts.tint and spec.tintable then
        tex:SetVertexColor(color.r, color.g, color.b)
    else
        tex:SetVertexColor(1, 1, 1)
    end
    tex:SetAlpha(opts.alpha)
    tex:Show()

    if opts.glow then
        f.glow:SetSize(w * 1.9, size * 1.9)
        f.glow:SetVertexColor(color.r, color.g, color.b)
        f.glow:SetAlpha(opts.glowAlpha)
        f.glow:Show()
    else
        f.glow:Hide()
    end
end

-- Draw above the frame it is anchored to (health bars sit high in the plate).
local function Raise(f, anchor)
    local ok, level = pcall(anchor.GetFrameLevel, anchor)
    level = ok and Readable(level)
    if type(level) == "number" then f:SetFrameLevel(level + 15) end
end

-- A style override for one classification, or the section's own style.
local function StyleFor(override, fallback)
    if override and override ~= "" and (override == "none" or Media.Exists(override)) then
        return override
    end
    return fallback
end

-- ---------------------------------------------------------------------------
-- Placement: what the visuals hang off (Core/Plates.lua finds the frames)
-- ---------------------------------------------------------------------------

-- Fills `out` for a nameplate: host, strata and level from the plate's
-- adapter, plus the two anchors the anchor setting picks:
--   badge  the health bar ("health", the default) or the nameplate frame
--   over   above the name/plate ("health") or the nameplate frame's top
function Visuals.Place(nameplate, unit, profile, out)
    ns.Plates.Resolve(nameplate, unit, out)
    if profile.anchor == "plate" then
        out.badge, out.over = nameplate, nameplate
    else
        out.badge = out.bar or nameplate
        out.over = out.top or nameplate
    end
    return out
end

-- Parent an element to the host and set its draw order: the adapter's strata
-- and level when it has one, else just above the frame it is anchored to.
local function Attach(e, place, anchor)
    if e:GetParent() ~= place.host then e:SetParent(place.host) end
    if place.strata then
        e:SetFrameStrata(place.strata)
        e:SetFrameLevel(place.level)
        e.lifted = true
    else
        if e.lifted then
            -- Back from a lifted host: follow this host's strata again.
            local ok, strata = pcall(place.host.GetFrameStrata, place.host)
            strata = ok and Readable(strata)
            if type(strata) == "string" then e:SetFrameStrata(strata) end
            e.lifted = nil
        end
        Raise(e, anchor)
    end
end

-- ---------------------------------------------------------------------------
-- Visual sets
-- ---------------------------------------------------------------------------

local Set = {}
Set.__index = Set

-- parent: the Blizzard nameplate (or the preview's mock plate). Elements are
-- created on it and return to it when hidden, so a host frame another addon
-- recycles never carries them to another mob.
function Visuals.Create(parent)
    return setmetatable({ parent = parent, place = {} }, Set)
end

function Set:Element(key, withLabel)
    local e = self[key]
    if not e then
        e = CreateElement(self.parent, withLabel)
        self[key] = e
    end
    return e
end

local function HideElement(e, home)
    if not e then return end
    e:Hide()
    if home and e:GetParent() ~= home then e:SetParent(home) end
end

function Set:HideAll()
    HideElement(self.badge, self.parent)
    HideElement(self.badge2, self.parent)
    HideElement(self.overhead, self.parent)
    self.key = nil
end

-- Draw the set for a unit of this classification. place: from Visuals.Place.
-- badgeOpts: the badge settings to draw with (default profile.badge; the
-- target frame passes its own, whose style "" means the nameplate badge's).
-- Skips all work when nothing changed since the last call (same settings,
-- class, scope, host and anchors).
function Set:Update(class, place, showBadge, showOverhead, profile, badgeOpts)
    local key = ns.settingsVersion .. class .. (showBadge and "B" or "") .. (showOverhead and "O" or "")
        .. tostring(place.host) .. tostring(place.badge) .. tostring(place.over)
    if key == self.key then return end
    self.key = key
    local anchor = place.badge

    local cdb = profile.classes[class]
    local color = cdb.color

    -- Badge, and its mirrored pair.
    local b = badgeOpts or profile.badge
    if showBadge then
        local baseStyle = (b.style and b.style ~= "") and b.style or profile.badge.style
        local spec = Media.Resolve(StyleFor(cdb.badgeStyle, baseStyle), class)
        local spot = ns.PLACEMENTS[b.point] or ns.PLACEMENTS.LEFT
        local point = ns.PLACEMENTS[b.point] and b.point or "LEFT"
        -- Art that points right faces outward on the left side; Flip inverts.
        local mirrored = (spec.facing == "right" and spot.side == "left") ~= (b.flip == true)

        local e = self:Element("badge")
        Attach(e, place, anchor)
        Paint(e, spec, b, color, mirrored)
        e:ClearAllPoints()
        e:SetPoint(spot.my, anchor, point, b.x, b.y)
        e:Show()
        SetAnim(e, b.anim)

        if b.pair and spot.mirror then
            local other = ns.PLACEMENTS[spot.mirror]
            local e2 = self:Element("badge2")
            Attach(e2, place, anchor)
            Paint(e2, spec, b, color, not mirrored)
            e2:ClearAllPoints()
            e2:SetPoint(other.my, anchor, spot.mirror, -b.x, b.y)
            e2:Show()
            SetAnim(e2, b.anim)
        else
            HideElement(self.badge2, self.parent)
        end
    else
        HideElement(self.badge, self.parent)
        HideElement(self.badge2, self.parent)
    end

    -- Overhead marker, with its optional label.
    local o = profile.overhead
    if showOverhead then
        local e = self:Element("overhead", true)
        local over = place.over
        Attach(e, place, over)
        local styleKey = StyleFor(cdb.overheadStyle, o.style)
        if styleKey == "none" then
            -- Text only: an empty anchor point for the label.
            e:SetSize(1, 1)
            e.tex:Hide()
            e.glow:Hide()
        else
            Paint(e, Media.Resolve(styleKey, class), o, color, false)
        end
        e:ClearAllPoints()
        e:SetPoint("BOTTOM", over, "TOP", o.x, o.y)

        local label = e.label
        if o.label or styleKey == "none" then
            label:SetFont(STANDARD_TEXT_FONT, o.labelSize, "OUTLINE")
            label:SetText(ns.CLASS_LABELS[class] or "")
            label:SetTextColor(color.r, color.g, color.b, o.alpha)
            label:ClearAllPoints()
            if o.labelPos == "below" and styleKey ~= "none" then
                label:SetPoint("TOP", e, "BOTTOM", 0, -1)
            else
                label:SetPoint("BOTTOM", e, "TOP", 0, 1)
            end
            label:Show()
        else
            label:Hide()
        end
        e:Show()
        SetAnim(e, o.anim)
    else
        HideElement(self.overhead, self.parent)
    end
end
