--============================
-- File: /urc/store.lua
--============================
local S = {}

local LEGACY = "redstOneCOntrol.txt" -- keep backward compat
local CURRENT = LEGACY -- you can change later; migration keeps both

local function migrate(tbl)
  tbl = tbl or {}
  for _, srv in pairs(tbl) do
    srv.outputs = srv.outputs or {}
    for _, o in pairs(srv.outputs) do
      if o.invert == nil then o.invert = false end
      if o.state ~= "On" and o.state ~= "Off" then o.state = "Off" end
    end
  end
  return tbl
end

function S.load()
  local path = fs.exists(CURRENT) and CURRENT or (fs.exists(LEGACY) and LEGACY or CURRENT)
  if not fs.exists(path) then return {} end
  local f = fs.open(path, "r"); local raw = f.readAll(); f.close()
  local ok, data = pcall(textutils.unserialize, raw)
  if not ok or type(data) ~= "table" then return {} end
  return migrate(data)
end

function S.save(pages)
  local f = fs.open(CURRENT, "w"); f.write(textutils.serialize(pages)); f.close()
end

return S