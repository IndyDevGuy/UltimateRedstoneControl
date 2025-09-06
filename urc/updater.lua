-- updater.lua — update URC from GitHub Pages manifest with versioning
-- Usage:
--   updater <owner> <repo>
--   updater <manifest-url>
--   updater                  -- uses urc/.manifest.lock from last run
-- Flags:
--   --force                  -- overwrite even if versions match
--   --check                  -- just print versions and exit

local args = {...}
local FORCE, CHECK = false, false
for i = #args, 1, -1 do
  if args[i] == "--force" then FORCE = true; table.remove(args, i)
  elseif args[i] == "--check" then CHECK = true; table.remove(args, i)
  end
end

local LOCK_PATH = "urc/.manifest.lock"

-- ---------- misc helpers ----------
local function readAll(p) local f=fs.open(p,"r"); if not f then return nil end local s=f.readAll(); f.close(); return s end
local function writeAll(p,s) local d=fs.getDir(p); if d~="" and not fs.exists(d) then fs.makeDir(d) end local f=fs.open(p,"w"); assert(f,"Cannot write "..p); f.write(s); f.close() end
local function fetch(url) if not http then error("HTTP API disabled") end local ok,res=pcall(http.get,url); if not ok or not res then error("HTTP GET failed: "..tostring(url)) end local b=res.readAll(); res.close(); return b end
local function jsonD(s) local f=textutils.unserialiseJSON or textutils.unserializeJSON; local ok,v=pcall(f,s); return ok and v or nil end
local function jsonE(t) local f=textutils.serialiseJSON or textutils.serializeJSON; return f(t,true) end

local function pathFromUrl(url)
  local rel = url:match("^https?://raw%.githubusercontent%.com/[^/]+/[^/]+/[^/]+/(.+)$")
           or url:match("^https?://github%.com/[^/]+/[^/]+/raw/[^/]+/(.+)$")
           or url:match("/(urc/.+)$")
           or ("urc/"..(url:match("/([^/]+)$") or "downloaded.file"))
  return rel
end

local function baseFromManifest(url) return (url:gsub("/manifest%.json$","")) end
local function appJsonFromManifest(url) return baseFromManifest(url).."/app.json" end
local function manifestFromOwnerRepo(owner,repo) return ("https://%s.github.io/%s/manifest.json"):format(owner,repo) end

local function vcmp(a,b)  -- returns -1,0,1
  local function parts(v) local t={} for n in tostring(v):gmatch("%d+") do t[#t+1]=tonumber(n) end return t end
  local A,B=parts(a or "0"),parts(b or "0"); local n=math.max(#A,#B)
  for i=1,n do local x=A[i] or 0; local y=B[i] or 0; if x<y then return -1 elseif x>y then return 1 end end
  return 0
end

-- ---------- lock handling ----------
local function loadLock()
  local s = readAll(LOCK_PATH); if not s then return nil end
  local obj = jsonD(s); if type(obj)~="table" then return nil end
  return obj
end
local function saveLock(obj) writeAll(LOCK_PATH, jsonE(obj)) end

-- ---------- choose manifest URL ----------
local manifestUrl
local lock = loadLock()
if lock then
manifestUrl = lock.manifest_url
elseif not lock or not lock.manifest_url then
manifestUrl = manifestFromOwnerRepo("indydevguy", "UltimateRedstoneControl")
end

-- ---------- fetch latest version info ----------
local installedVersion = "0.0.0"
local prev = loadLock()
if prev and prev.version then installedVersion = prev.version end

local latestVersion, latestManifestUrl = nil, manifestUrl
do
  local ok, data = pcall(fetch, appJsonFromManifest(manifestUrl))
  if ok and data then
    local app = jsonD(data)
    if type(app)=="table" then
      latestVersion = app.version or latestVersion
      latestManifestUrl = app.manifest_url or latestManifestUrl
    end
  end
end

-- Fallback if app.json missing
if not latestVersion then latestVersion = "0.0.0" end

print(("Installed version: %s"):format(installedVersion))
print(("Available  version: %s"):format(latestVersion))

if CHECK and not FORCE then return end
if not FORCE and vcmp(installedVersion, latestVersion) >= 0 then
  print("Already up to date. Use --force to re-install.")
  return
end

-- ---------- update using manifest ----------
print("Fetching manifest: "..latestManifestUrl)
local items = jsonD(fetch(latestManifestUrl))
assert(type(items)=="table","Invalid manifest JSON")

-- Build sets for cleanup
local newList, newSet = {}, {}
for _,url in ipairs(items) do
  if type(url)=="string" then
    local path = pathFromUrl(url)
    newList[#newList+1] = {url=url, path=path}
    newSet[path] = true
  end
end

local prevSet = {}
if prev and prev.files then for _,p in ipairs(prev.files) do prevSet[p]=true end end

local created, updated, skipped = 0,0,0
for i,it in ipairs(newList) do
  local path, url = it.path, it.url
  local needs = FORCE or (not fs.exists(path))
  local remote
  if not needs then
    remote = fetch(url)
    if readAll(path) ~= remote then needs = true end
  end
  if needs then
    remote = remote or fetch(url)
    writeAll(path, remote)
    if prevSet[path] then updated=updated+1 else created=created+1 end
    print("updated: "..path)
  else
    skipped=skipped+1
  end
end

-- Remove files no longer in manifest (safety: only under urc/)
local removed = 0
for p,_ in pairs(prevSet) do
  if not newSet[p] and p:sub(1,4)=="urc/" and fs.exists(p) then
    fs.delete(p); removed=removed+1; print("removed: "..p)
  end
end

-- Save lock with latest version
saveLock({
  manifest_url = latestManifestUrl,
  version      = latestVersion,
  files        = (function(t) local r={} for _,it in ipairs(newList) do r[#r+1]=it.path end return r end)()
})

print(("-- done --\ncreated: %d  updated: %d  skipped: %d  removed: %d"):format(created, updated, skipped, removed))
print("Run: /urc/app.lua")
