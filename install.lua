-- install.lua  (ComputerCraft / CC:Tweaked)
-- Usage:
--  install <owner> <repo>                -- uses https://<owner>.github.io/<repo>/manifest.json
--  install <manifest-url>                -- uses the given full URL
-- Example:
--  install yourname urc
--  install https://yourname.github.io/urc/manifest.json

local args = {...}

local manifestUrl = "https://indydevguy.github.io/ultimateredstonecontrol/manifest.json"


if not http then
  error("HTTP API is disabled. Enable it in ComputerCraft/CC:Tweaked config.")
end

local function fetch(url)
  local ok, res = pcall(http.get, url)
  if not ok or not res then error("HTTP GET failed: "..tostring(url)) end
  local body = res.readAll() res.close()
  return body
end

local function ensureDir(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
end

local function pathFromUrl(url)
  -- Raw form: https://raw.githubusercontent.com/<owner>/<repo>/<sha>/<path>
  local p = url:match("^https?://raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)$")
          or url:match("^https?://github%.com/[^/]+/[^/]+/raw/[^/]+/(.+)$")
          or url:match("/(urc/.+)$")   -- fallback: anything under urc/
          or url:match("/([^/]+)$")    -- just filename
  return p or "downloaded.file"
end

print("Fetching manifest: "..manifestUrl)
local raw = fetch(manifestUrl)

local ok, items = pcall(textutils.unserialiseJSON or textutils.unserializeJSON, raw)
if not ok or type(items) ~= "table" then
  error("Manifest is not valid JSON array")
end

for i,url in ipairs(items) do
  if type(url) == "string" then
    local path = pathFromUrl(url)
    ensureDir(path)
    write((" [%2d/%2d] %s\n   -> %s"):format(i, #items, url, path))
    local content = fetch(url)
    local f = fs.open(path,"w"); f.write(content); f.close()
  end
end

print("Done. You can run: /urc/app.lua")
