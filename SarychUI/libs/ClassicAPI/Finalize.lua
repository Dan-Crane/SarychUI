if not _G.__CLASSICAPI_SKIP and _G.ClassicAPI then
    _G.ClassicAPI.__loaded = true
    -- SarychUI files still read WidgetAPI from the addon namespace.
    local _, addonTable = ...
    if type(addonTable) == "table" then
        addonTable.WidgetAPI = _G.ClassicAPI.WidgetAPI
    end
end

_G.__CLASSICAPI_SKIP = nil
