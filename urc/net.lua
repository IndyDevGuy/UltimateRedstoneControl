--============================
-- File: /urc/net.lua
--============================
local N = {}

function N.open(prefer)
  if prefer and peripheral.getType(prefer) == "modem" then rednet.open(prefer); return end
  for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "modem" then rednet.open(side); return end
  end
end

local PROTOCOL = "BaseControl"

function N.sendState(server, cable, state)
  if not server then return end
  rednet.send(tonumber(server), (cable .. "/" .. state), PROTOCOL)
end

function N.sendAllOff(server)
  if not server then return end
  rednet.send(tonumber(server), "AllOff/", PROTOCOL)
end

return N