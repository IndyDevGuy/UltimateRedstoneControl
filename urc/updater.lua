-- updater.lua — update URC from GitHub Pages manifest
-- Usage:
--   updater                -- uses urc/.manifest.lock from last run
-- Options:
--   --force                -- overwrite all files even if unchanged

local args = {...}
local FORCE = false
for i = #args, 1, -1 do
  if args[i] == "--force" then FORCE = true; table.remove(args, i) end
end

local LOCK_PATH = "urc/.manifest.lock"

local function usage()
  print("Usage:")
  print(" updater            (uses previous manifest from "..LOCK_PATH..")")
end

local function readAll(p)
  local f = fs.open(p, "r"); if not f then return nil end
  local s = f.readAll(); f.close(); return s
end

local function writeAll(p, s)
  local dir = fs.getDir(p); if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local f = fs.open(p, "w"); if not f then error("Cannot write "..p) end
  f.write(s); f.close()
end

local function loadLock()
  local s = readAll(LOCK_PATH)
  if not s then return nil end
  local decode = textutils.unserialiseJSON or textutils.unserializeJSON
  local ok, obj = pcall(decode, s)
  if not ok or type(obj) ~= "table" then return nil end
  return obj
end

local function saveLock(obj)
  local encode = textutils.serialiseJSON or textutils.serializeJSON
  writeAll(LOCK_PATH, encode(obj, true))
end

local function pathFromUrl(url)
  -- Prefer raw.githubusercontent.com …/<sha>/<path>
  local rel = url:match("^https?://raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)$")
          or url:match("^https?://github%.com/[^/]+/[^/]+/raw/[^/]+/(.+)$")
  if rel and rel ~= "" then return rel end
  -- Fallbacks (keep under urc/ to avoid writing elsewhere)
  local under = url:match("/(urc/.+)$")
  if under then return under end
  return fs.combine("urc", (url:match("/([^/]+)$") or "downloaded.file"))
end

local function fetch(url)
  if not http then error("HTTP API disabled in config") end
  local ok, res = pcall(http.get, url)
  if not ok or not res then error("HTTP GET failed: "..tostring(url)) end
  local body = res.readAll() res.close()
  return body
end

-- decide manifest URL
local manifestUrl
if #args == 0 then
  local lock = loadLock()
  if not lock or not lock.manifest_url then
    usage(); error("No args and no previous manifest saved.")
  end
  manifestUrl = lock.manifest_url
else
   manifestUrl = ("https://indydevguy.github.io/UltimateRedstoneControl/manifest.json")
end

print("Fetching manifest: "..manifestUrl)
local raw = fetch(manifestUrl)
local decode = textutils.unserialiseJSON or textutils.unserializeJSON
local ok, items = pcall(decode, raw)
if not ok or type(items) ~= "table" then error("Invalid manifest JSON") end

-- Build new file map
local newList, newSet = {}, {}
for _, url in ipairs(items) do
  if type(url) == "string" then
    local path = pathFromUrl(url)
    table.insert(newList, {url=url, path=path})
    newSet[path] = url
  end
end

-- Load previous file set (for cleanup)
local prev = loadLock() or { files = {} }
local prevSet = {}
for _, p in ipairs(prev.files or {}) do prevSet[p] = true end

-- Update / install files
local updated, created, skipped = 0, 0, 0
for i, it in ipairs(newList) do
  local path, url = it.path, it.url
  local needsWrite = FORCE or (not fs.exists(path))
  local remote
  if not needsWrite then
    -- compare existing vs remote
    remote = fetch(url)
    local localData = readAll(path)
    if localData ~= remote then needsWrite = true end
  end
  if needsWrite then
    if not remote then remote = fetch(url) end
    writeAll(path, remote)
    if fs.exists(path) and (prevSet[path] or FORCE) then updated = updated + 1 else created = created + 1 end
    print(("updated: %s"):format(path))
  else
    skipped = skipped + 1
  end
end

-- Remove files that no longer exist in manifest (only under urc/)
local removed = 0
for p,_ in pairs(prevSet) do
  if not newSet[p] and p:sub(1,4) == "urc/" and fs.exists(p) then
    fs.delete(p); removed = removed + 1
    print(("removed: %s"):format(p))
  end
end

-- Save lock
local lock = { manifest_url = manifestUrl, files = {} }
for _, it in ipairs(newList) do table.insert(lock.files, it.path) end
saveLock(lock)

-- Summary
print(("-- done --\ncreated: %d  updated: %d  skipped: %d  removed: %d"):format(created, updated, skipped, removed))
print("Run: /urc/app.lua")
