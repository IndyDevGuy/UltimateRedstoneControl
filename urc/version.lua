-- /urc/version.lua
-- Exposes VERSION by reading the same text file used by your Pages workflow.
local M = {}

local function readAll(p)
  local f = fs.open(p, "r")
  if not f then return nil end
  local s = f.readAll(); f.close(); return s
end

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function findVersionTxt()
  -- Prefer alongside this module (installed under /urc)
  local here = fs.combine(fs.getDir(shell.getRunningProgram()), "app_version.txt")
  if fs.exists(here) then return here end
  -- Fallbacks (in case of different loaders)
  if fs.exists("urc/app_version.txt") then return "urc/app_version.txt" end
  if fs.exists("app_version.txt") then return "app_version.txt" end
  return nil
end

local function readVersion()
  local p = findVersionTxt()
  if not p then return "0.0.0" end
  return trim(readAll(p)) ~= "" and trim(readAll(p)) or "0.0.0"
end

M.VERSION = readVersion()

return M
