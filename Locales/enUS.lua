-- =============================================================================
-- Elite Mob Visuals: strings
-- Keys are the English text, so enUS needs no table: a missing key returns
-- itself. A translation file sets only the keys it translates, for example:
--   if GetLocale() ~= "deDE" then return end
--   local L = select(2, ...).L
--   L["Elite"] = "Elite"
-- =============================================================================
local _, ns = ...

ns.L = setmetatable({}, {
    __index = function(_, key) return key end,
})
