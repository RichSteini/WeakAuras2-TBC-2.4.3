-- all this is is a frame that ensures that the SV is a table type
local loader = CreateFrame("FRAME")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, addon)
  if addon == "WeakAurasArchive" then
    if type(WeakAurasArchive) ~= "table" then
      WeakAurasArchive = {}
    end
    self:UnregisterEvent("ADDON_LOADED")
  end
end)