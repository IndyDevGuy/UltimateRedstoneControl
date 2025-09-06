-- /urc/version.lua
-- Exposes VERSION by reading the same text file used by your Pages workflow.
local M = {}

local function readAll(p) local f=fs.open(p,"r"); if not f then return nil end local s=f.readAll(); f.close(); return s end
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function combine(a,b) return fs.combine(a or "", b or "") end
M.RUN_BASE = fs.getDir("")

local function readVersion()
  -- Look for app_version.txt in sensible places
  local candidates = {
    combine(M.RUN_BASE, "app_version.txt"),
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

M.VERSION = readVersion()
return M
