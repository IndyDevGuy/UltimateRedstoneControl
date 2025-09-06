-- urc/manifestmanager.lua
local ManifestManager = {}

function ManifestManager.new(manifestUrl)
  local self = {
    manifestUrl        = manifestUrl or "https://IndyDevGuy.github.io/UltimateRedstoneControlClient/manifest.json",
    latestVersion      = nil,
    latestManifestUrl  = nil,
    builtAt            = nil,
    commit             = nil,
    items              = nil,
  }

function self:jsonD(s)
    local f = textutils.unserialiseJSON or textutils.unserializeJSON
    local ok, v = pcall(f, s)
    return ok and v or nil
  end

  function self:baseFromManifest()
    return (self.manifestUrl:gsub("/manifest%.json$", ""))
  end

  function self:appJsonFromManifest()
    return self:baseFromManifest() .. "/app.json"
  end

  function self:setManifestItems()
    self.items = self:jsonD(self:fetch(self.manifestUrl))
  end

  function self:fetch(url)
    if not http then error("HTTP API disabled") end
    local ok, res = pcall(http.get, url)
    if not ok or not res then return nil end
    local b = res.readAll()
    res.close()
    return b
  end

  function self:setData()
    local data = self:fetch(self:appJsonFromManifest())
    if not data then return end
    local app = self:jsonD(data)
    if type(app) == "table" then
      self.latestVersion     = app.version
      self.latestManifestUrl = app.manifest_url
      self.builtAt           = app.built_at
      self.commit            = app.commit
    end
  end

  function self:vcmp(a,b)
    local function parts(v)
      local t = {}
      for n in tostring(v or "0"):gmatch("%d+") do t[#t+1] = tonumber(n) end
      return t
    end
    local A, B = parts(a), parts(b)
    local n = math.max(#A, #B)
    for i = 1, n do
      local x, y = A[i] or 0, B[i] or 0
      if x < y then return -1 elseif x > y then return 1 end
    end
    return 0
  end

  self:setData()
  self:setManifestItems()
  return self
end

return ManifestManager