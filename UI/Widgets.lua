-- =============================================================================
-- Elite Mob Visuals: option widgets
-- Small flat controls with no Blizzard templates, so nothing breaks when a
-- template changes between clients. Every control has :Refresh() to re-read
-- its value (after a reset) and takes get/set functions.
-- =============================================================================
local _, ns = ...

local W = {}
ns.Widgets = W

-- Palette: gold on near-black, from the logo.
W.C = {
    bg       = { 0.06, 0.05, 0.07, 0.97 },
    inset    = { 0.10, 0.09, 0.11, 1 },
    control  = { 0.14, 0.13, 0.16, 1 },
    hover    = { 0.22, 0.19, 0.16, 1 },
    border   = { 0.42, 0.32, 0.13, 1 },
    gold     = { 0.95, 0.74, 0.25, 1 },
    text     = { 0.93, 0.91, 0.87, 1 },
    dim      = { 0.62, 0.60, 0.57, 1 },
}
local C = W.C

local function Fill(tex, c) tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end

-- A flat background and 1px border on any frame.
function W.Skin(frame, bg, border)
    local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    t:SetAllPoints()
    Fill(t, bg or C.inset)
    frame.skinBg = t
    border = border or C.border
    local edges = {}
    for i, spec in ipairs({
        { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
    }) do
        local e = frame:CreateTexture(nil, "BORDER")
        Fill(e, border)
        e:SetPoint(spec[1])
        e:SetPoint(spec[2])
        if spec[3] then e:SetWidth(spec[3]) else e:SetHeight(spec[4]) end
        edges[i] = e
    end
    frame.skinEdges = edges
end

function W.SetBorderColor(frame, c)
    for _, e in ipairs(frame.skinEdges or {}) do Fill(e, c) end
end

function W.Text(parent, text, font, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
    fs:SetText(text or "")
    local c = color or C.text
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH("LEFT")
    return fs
end

local function Tooltip(frame, title, body)
    if not body then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0.25)
        GameTooltip:AddLine(body, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Section heading: gold text over a faint rule.
function W.Header(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(20)
    f.text = W.Text(f, text, "GameFontNormal", C.gold)
    f.text:SetPoint("LEFT", 0, 1)
    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
    rule:SetHeight(1)
    rule:SetPoint("LEFT", f.text, "RIGHT", 8, 0)
    rule:SetPoint("RIGHT")
    return f
end

-- A note in small dim text that wraps to the column width.
function W.Note(parent, text, width)
    local fs = W.Text(parent, text, "GameFontHighlightSmall", C.dim)
    fs:SetWidth(width)
    fs:SetJustifyV("TOP")
    fs:SetSpacing(2)
    return fs
end

function W.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 22)
    W.Skin(b, C.control)
    b.text = W.Text(b, text, "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self) Fill(self.skinBg, C.hover); W.SetBorderColor(self, C.gold) end)
    b:SetScript("OnLeave", function(self)
        Fill(self.skinBg, self.selected and C.hover or C.control)
        W.SetBorderColor(self, self.selected and C.gold or C.border)
    end)
    b:SetScript("OnClick", onClick)
    function b:SetSelected(on)
        self.selected = on
        Fill(self.skinBg, on and C.hover or C.control)
        W.SetBorderColor(self, on and C.gold or C.border)
        local c = on and C.gold or C.text
        self.text:SetTextColor(c[1], c[2], c[3])
    end
    return b
end

-- Checkbox with a clickable label.
function W.Check(parent, label, get, set, tip)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(16, 16)
    W.Skin(cb, C.control)
    local check = cb:CreateTexture(nil, "ARTWORK")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetPoint("CENTER")
    check:SetSize(20, 20)
    cb:SetCheckedTexture(check)
    cb.label = W.Text(cb, label)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 7, 0)
    cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 10), -2, -2)
    cb:SetScript("OnEnter", function(self) W.SetBorderColor(self, C.gold) end)
    cb:SetScript("OnLeave", function(self) W.SetBorderColor(self, C.border) end)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    Tooltip(cb, label, tip)
    function cb:Refresh() self:SetChecked(get() and true or false) end
    cb:Refresh()
    cb.height = 22
    return cb
end

local function Round(v, step)
    local n = math.floor(v / step + 0.5) * step
    -- Keep 0.05 steps free of float noise.
    return tonumber(string.format("%.2f", n))
end

-- Labelled horizontal slider; the mouse wheel steps it too.
function W.Slider(parent, label, minV, maxV, step, get, set, fmt, width)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 220
    f:SetSize(width, 36)
    f.label = W.Text(f, label)
    f.label:SetPoint("TOPLEFT")
    f.value = W.Text(f, "", "GameFontHighlightSmall", C.gold)
    f.value:SetPoint("TOPRIGHT")
    f.value:SetJustifyH("RIGHT")

    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", 0, -18)
    s:SetPoint("TOPRIGHT", 0, -18)
    s:SetHeight(14)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    Fill(track, C.control)
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(8, 14)
    Fill(thumb, C.gold)
    s:SetThumbTexture(thumb)
    f.slider = s

    local function Show(v) f.value:SetText(string.format(fmt or "%d", v)) end
    s:SetScript("OnValueChanged", function(_, v)
        v = Round(v, step)
        Show(v)
        if not f.refreshing and v ~= get() then set(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = math.max(minV, math.min(maxV, self:GetValue() + delta * step))
        self:SetValue(v)
    end)
    function f:Refresh()
        self.refreshing = true
        s:SetValue(get())
        Show(get())
        self.refreshing = false
    end
    f:Refresh()
    f.height = 40
    return f
end

-- ---------------------------------------------------------------------------
-- Dropdown: one shared popup list, opened under the button that asked for it.
-- Options: { { value = v, text = "...", icon = spec, tint = color }, ... }
-- ---------------------------------------------------------------------------

local menu, catcher
local ITEM_H = 20

local function CloseMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
end
W.CloseMenu = CloseMenu

local function SetIcon(tex, spec, tint)
    if not spec then tex:Hide() return end
    ns.Media.Apply(tex, spec, false)
    if tint and spec.tintable then
        tex:SetVertexColor(tint.r, tint.g, tint.b)
    else
        tex:SetVertexColor(1, 1, 1)
    end
    tex:SetWidth(16 * math.min(spec.aspect or 1, 1.6))
    tex:Show()
end

local function EnsureMenu()
    if menu then return end
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetScript("OnClick", CloseMenu)
    catcher:Hide()

    menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    menu:SetClampedToScreen(true)
    W.Skin(menu, C.bg, C.gold)
    menu.items = {}
    menu:Hide()
end

local function MenuItem(i)
    local item = menu.items[i]
    if item then return item end
    item = CreateFrame("Button", nil, menu)
    item:SetHeight(ITEM_H)
    item:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ITEM_H)
    item:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * ITEM_H)
    local hl = item:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints()
    Fill(hl, C.hover)
    hl:Hide()
    item.hl = hl
    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetHeight(16)
    item.icon:SetPoint("LEFT", 6, 0)
    item.text = W.Text(item, "", "GameFontHighlightSmall")
    item:SetScript("OnEnter", function(self) self.hl:Show() end)
    item:SetScript("OnLeave", function(self) if not self.current then self.hl:Hide() end end)
    menu.items[i] = item
    return item
end

function W.Dropdown(parent, label, width, getOptions, get, set, tip)
    -- label = nil: just the button (for grids with column headings).
    local top = label and -16 or 0
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, label and 40 or 22)
    if label then
        f.label = W.Text(f, label)
        f.label:SetPoint("TOPLEFT")
    end

    local b = CreateFrame("Button", nil, f)
    b:SetPoint("TOPLEFT", 0, top)
    b:SetPoint("TOPRIGHT", 0, top)
    b:SetHeight(22)
    W.Skin(b, C.control)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetHeight(16)
    b.icon:SetPoint("LEFT", 6, 0)
    b.text = W.Text(b, "", "GameFontHighlightSmall")
    b.arrow = W.Text(b, "v", "GameFontHighlightSmall", C.gold)
    b.arrow:SetPoint("RIGHT", -7, 0)
    b:SetScript("OnEnter", function(self) W.SetBorderColor(self, C.gold) end)
    b:SetScript("OnLeave", function(self) W.SetBorderColor(self, C.border) end)
    Tooltip(b, label or "", tip)
    f.button = b

    local function Current()
        local value = get()
        for _, opt in ipairs(getOptions()) do
            if opt.value == value then return opt end
        end
    end

    local function Place(text, icon, opt, x)
        SetIcon(icon, opt and opt.icon, opt and opt.tint)
        text:ClearAllPoints()
        if opt and opt.icon then
            text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        else
            text:SetPoint("LEFT", x or 8, 0)
        end
    end

    function f:Refresh()
        local opt = Current()
        b.text:SetText(opt and opt.text or tostring(get()))
        Place(b.text, b.icon, opt)
        b.text:SetPoint("RIGHT", b.arrow, "LEFT", -4, 0)
    end

    b:SetScript("OnClick", function()
        EnsureMenu()
        if menu:IsShown() and menu.owner == f then CloseMenu() return end
        local options = getOptions()
        local value = get()
        for i, opt in ipairs(options) do
            local item = MenuItem(i)
            item.text:SetText(opt.text)
            Place(item.text, item.icon, opt)
            item.current = (opt.value == value)
            item.hl:SetShown(item.current)
            local c = item.current and C.gold or C.text
            item.text:SetTextColor(c[1], c[2], c[3])
            item:SetScript("OnClick", function()
                CloseMenu()
                set(opt.value)
                f:Refresh()
            end)
            item:Show()
        end
        for i = #options + 1, #menu.items do menu.items[i]:Hide() end
        menu.owner = f
        menu:SetSize(math.max(b:GetWidth(), 150), #options * ITEM_H + 2)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
        catcher:Show()
        menu:Show()
    end)

    f:SetScript("OnHide", function() if menu and menu.owner == f then CloseMenu() end end)
    f:Refresh()
    f.height = label and 46 or 26
    return f
end

-- ---------------------------------------------------------------------------
-- Colour swatch, opening the game's colour picker.
-- ---------------------------------------------------------------------------

local function OpenColorPicker(r, g, b, onChange)
    local function Apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        onChange(nr, ng, nb)
    end
    local function Cancel() onChange(r, g, b) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = Apply, cancelFunc = Cancel,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = Apply
        ColorPickerFrame.cancelFunc = Cancel
        ColorPickerFrame.previousValues = { r = r, g = g, b = b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- get() returns a { r, g, b } table; set(r, g, b).
function W.Color(parent, get, set, tip, title)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(36, 18)
    W.Skin(b, C.control)
    local sw = b:CreateTexture(nil, "ARTWORK")
    sw:SetPoint("TOPLEFT", 2, -2)
    sw:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetScript("OnEnter", function(self) W.SetBorderColor(self, C.gold) end)
    b:SetScript("OnLeave", function(self) W.SetBorderColor(self, C.border) end)
    b:SetScript("OnClick", function()
        local c = get()
        OpenColorPicker(c.r, c.g, c.b, function(r, g, bl)
            set(r, g, bl)
            b:Refresh()
        end)
    end)
    Tooltip(b, title or "", tip)
    function b:Refresh()
        local c = get()
        sw:SetColorTexture(c.r, c.g, c.b, 1)
    end
    b:Refresh()
    return b
end
