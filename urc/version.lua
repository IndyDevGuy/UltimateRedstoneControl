-- /urc/version.lua
-- Exposes VERSION by reading the same text file used by your Pages workflow.
local Version = {}

function Version.new()
  local self = {
    runBase = fs.getDir("")
  }

  function self:readAll(p) local f=fs.open(p,"r"); if not f then return nil end local s=f.readAll(); f.close(); return s end
  function self:trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
  function self:combine(a,b) return fs.combine(a or "", b or "") end

  function self:readVersion()
    -- Look for app_version.txt in sensible places
    local candidates = {
      self:combine(M.RUN_BASE, "app_version.txt"),
      "urc/app_version.txt",
      "app_version.txt",
    }
    for _,p in ipairs(candidates) do
      if fs.exists(p) then
        local v = trim(readAll(p) or "")
        if v~="" then return v end
      end
    end
    return nil
  end
  return self
end
return Version
