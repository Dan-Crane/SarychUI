local AddonName = ...
local MAJOR, MINOR = "ClassicAPI", 12901

local LibStub = _G.LibStub
if not LibStub then
    error(MAJOR .. " requires its bundled LibStub to load first.")
end

local Library, OldMinor = LibStub:NewLibrary(MAJOR, MINOR)
if not Library then
    _G.ClassicAPI = LibStub:GetLibrary(MAJOR)
    _G.__CLASSICAPI_SKIP = true
    return
end

_G.__CLASSICAPI_SKIP = false
_G.ClassicAPI = Library

Library.MAJOR = MAJOR
Library.MINOR = MINOR
Library.VERSION = "1.29-embedded.1"
Library.OLD_MINOR = OldMinor
Library.ADDON_NAME = AddonName
Library.PATH = "Interface\\AddOns\\" .. AddonName .. "\\libs\\ClassicAPI\\"
Library.TEXTURE_PATH = Library.PATH .. "Texture\\"
Library.__loaded = false
