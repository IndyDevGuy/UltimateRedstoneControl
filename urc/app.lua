--============================
-- File: /urc/app.lua
--============================
local base = fs.getDir(shell.getRunningProgram())
local function rel(p) return fs.combine(base, p) end
local ui      = dofile(rel("ui.lua"))
local palette = dofile(rel("palette.lua"))
local store   = dofile(rel("store.lua"))
local net     = dofile(rel("net.lua"))
local version = require("version")
local manifestManager = require("manifestmanager")

-- State ------------------------------------------------------------
local pages = store.load()
local pageState = "main"
local currentServerId = 1
local serverScroll, outputScroll = 0, 0

local W, H = term.getSize()
local buf = ui.newBuffer(W, H)
local updateBtn = nil   -- rect from ui.footerVersion; nil until drawn


local manifestMngr = manifestManager.new()

local function effectiveState(o)
  if o.invert then return (o.state == "On") and "Off" or "On" end
  return o.state
end

local function colorExists(srvId, name)
  for _, o in pairs(pages[srvId].outputs) do
    if o.cable == name then return true end
  end
  return false
end
local function colorExistsExcept(srvId, name, exceptIdx)
  for i, o in ipairs(pages[srvId].outputs) do
    if i ~= exceptIdx and o.cable == name then return true end
  end
  return false
end

local function renderVersion()
  local installedVersion = "v" .. version.VERSION   -- version = dofile("urc/version.lua")
  manifestMngr:setData()
  local latestVersion    = manifestMngr.latestVersion or installedVersion
  local updateText = (manifestMngr:vcmp(installedVersion, latestVersion) >= 0) and "Latest" or "Update"
  -- draw + capture clickable rect
  updateBtn = ui.footerVersion(buf, installedVersion, updateText)
end

-- Renderers --------------------------------------------------------
local function renderMain()
  buf:clear(colors.black)
  ui.header(buf, "Ultimate Redstone Control")
  buf:text(1, 2, "'N' new server  |  Scroll wheel or ", colors.black, colors.white)
  buf:text(1, 3, string.rep(" ", W), nil, colors.black) -- divider space

  local firstY = 4
  local visible = math.max(0, (H) - firstY)
  local maxStart = math.max(0, #pages - visible)
  serverScroll = math.min(serverScroll, maxStart)

  for i = 1, visible do
    local idx = serverScroll + i
    local rowY = firstY + (i - 1)
    buf:hline(1, rowY, W, colors.black)
    local srv = pages[idx]
    if srv then
      buf:text(1, rowY, srv.name)
      local count = #srv.outputs
      buf:text(math.floor(W / 2) + 7, rowY, (count < 10 and ("0" .. count) or tostring(count)) .. "/16")
      buf:hline(W, rowY, W, colors.red); buf:text(W, rowY, "X", colors.white, colors.red)
    end
  end
  renderVersion()
  buf:commit()
end

local function renderServer()
  local srv = pages[currentServerId]
  buf:clear(colors.black)
  ui.header(buf, srv.name, "SR", colors.green)
  buf:text(1, 2, "'N' new  |  Click color/name/i/state  |  Scroll", colors.black, colors.white)
  buf:text(1, 3, string.rep(" ", W), nil, colors.black)

  local firstY = 4
  local visible = math.max(0, (H) - firstY)
  local outputs = srv.outputs
  local maxStart = math.max(0, #outputs - visible)
  outputScroll = math.min(outputScroll, maxStart)

  for i = 1, visible do
    local idx = outputScroll + i
    local rowY = firstY + (i - 1)
    buf:hline(1, rowY, W, colors.black)
    local o = outputs[idx]
    if o then
      -- color chip (single cell)
      buf:pixel(1, rowY, palette.COLORS[o.cable] or colors.black)
      -- name
      buf:text(2, rowY, o.name, colors.white, colors.black)
      -- state bar (x-6..x-3)
      local bar = (o.state == "On") and colors.green or colors.red
      buf:hline(W - 6, rowY, W - 3, bar)
      buf:text(W - 6, rowY, o.state, colors.white, bar)
      -- invert marker at x-2
      if o.invert then buf:text(W - 2, rowY, "i", colors.yellow, colors.black) end
      -- delete X at x
      buf:hline(W, rowY, W, colors.red); buf:text(W, rowY, "X", colors.white, colors.red)
    end
  end
  ui.footerBack(buf)
  renderVersion()
  buf:commit()
end

local function renderPickColor(title, selected, existsFn)
  buf:clear(colors.black)
  ui.header(buf, title)
  ui.footerBack(buf)
  renderVersion()
  buf:text(2, 5, "Pick a new cable color:")
  local pox, poy = math.floor(W/2 - 7), 7
  palette.draw(buf, selected, pox, poy, existsFn)
  buf:hline(2, poy + 5, W - 2, colors.black)
  buf:text(2, poy + 5, "Selected: " .. (selected or "-"))
  buf:commit()
  return pox, poy
end

local function renderAddForm(name, color, invert)
  buf:clear(colors.black)
  ui.header(buf, "New redstOne output for:")
  buf:text(1, 2, pages[currentServerId].name)
  ui.footerBack(buf)

  buf:hline(2, 4, W - 2, colors.black)
  buf:text(2, 4, "Name: " .. (name == "" and "<click to enter>" or name))

  buf:text(2, 6, "Cable Color:")
  local pox, poy = math.floor(W/2 - 7), 8
  palette.draw(buf, color, pox, poy, function(n) return colorExists(currentServerId, n) end)

  buf:hline(2, poy + 5, W - 2, colors.black)
  buf:text(2, poy + 5, "Selected: " .. (color or "-"))

  buf:hline(2, poy + 6, W - 2, colors.black)
  buf:text(2, poy + 6, "Invert: ")
  buf:text(10, poy + 6, invert and "[X]" or "[ ]")

  local ok = (name ~= "" and color ~= nil and not colorExists(currentServerId, color))
  local by = poy + 8
  local bx1, bx2 = W - 12, W - 4
  local col = ok and colors.green or colors.gray
  buf:hline(bx1, by, bx2, col)
  buf:text(bx1 + 1, by, " Save ", colors.white, col)

  buf:commit()
  return pox, poy, by, bx1, bx2, ok
end

-- Screens ----------------------------------------------------------
local function screenMain()
  pageState = "main"
  renderMain()
end

local function screenServer(idx)
  currentServerId = idx
  pageState = "page"
  renderServer()
end

local function screenPickColorFor(outIdx)
  pageState = "pickColor"
  local out = pages[currentServerId].outputs[outIdx]
  local pox, poy = renderPickColor("Change color: " .. out.name, out.cable, function(n)
    return colorExistsExcept(currentServerId, n, outIdx)
  end)
  while true do
    local ev, b, mx, my = os.pullEvent()
    if ev == "mouse_click" then
      if mx <= 6 and my == H then return screenServer(currentServerId) end
      local chosen = palette.hit(mx, my, pox, poy)
      if chosen and not colorExistsExcept(currentServerId, chosen, outIdx) then
        local srv = pages[currentServerId]
        local oldCable = out.cable
        if oldCable ~= chosen then
          -- Turn old wire Off, switch, then push effective state to new wire
          net.sendState(srv.server, oldCable, "Off")
        end
        out.cable = chosen
        store.save(pages)
        net.sendState(srv.server, out.cable, effectiveState(out))
        return screenServer(currentServerId)
      end
    elseif ev == "key" and b == keys.escape then
      return screenServer(currentServerId)
    end
  end
end

local function screenAddOutput()
  pageState = "addOutput"
  local name, color, inv = "", nil, false
  local pox, poy, by, bx1, bx2, ok = renderAddForm(name, color, inv)
  while true do
    local ev, b, mx, my = os.pullEvent()
    if ev == "mouse_click" then
      if mx <= 6 and my == H then return screenServer(currentServerId) end

      -- Name edit (clear line, then read visibly)
      if my == 4 and mx >= 2 and mx <= W - 2 then
        buf:hline(2, 4, W - 2, colors.black)
        buf:text(2, 4, "Name: ")
        name = ui.readAt(buf, 8, 4, { fg = colors.white, bg = colors.black })
        pox, poy, by, bx1, bx2, ok = renderAddForm(name, color, inv)

      -- Palette select
      else
        local c = palette.hit(mx, my, pox, poy)
        if c then
          color = c
          pox, poy, by, bx1, bx2, ok = renderAddForm(name, color, inv)
        end

        -- Invert toggle
        if my == poy + 6 and mx >= 10 and mx <= 12 then
          inv = not inv
          pox, poy, by, bx1, bx2, ok = renderAddForm(name, color, inv)
        end

        -- Save
        if my == by and mx >= bx1 and mx <= bx2 and ok then
          local srv = pages[currentServerId]
          table.insert(srv.outputs, { name = name, cable = color, state = "Off", invert = inv })
          store.save(pages)
          -- Immediately enforce Off on the new cable
          net.sendState(srv.server, color, "Off")
          return screenServer(currentServerId)
        end
      end

    elseif ev == "key" and b == keys.escape then
      return screenServer(currentServerId)
    end
  end
end

-- Networking helpers ------------------------------------------------
local function refreshServer(id)
  local srv = pages[id]
  for _, o in pairs(srv.outputs) do
    net.sendState(srv.server, o.cable, effectiveState(o))
  end
end

-- Boot --------------------------------------------------------------
net.open("back")
screenMain()
for i = 1, #pages do refreshServer(i) end

-- Event loop --------------------------------------------------------
while true do
  local ev, p1, p2, p3 = os.pullEvent()

  if ev == "key" then
    local key = p1
    if pageState == "main" then
      local firstY, visible = 4, math.max(0, (H - 1) - 4)
      local maxStart = math.max(0, #pages - visible)
      if key == keys.up   then serverScroll = math.max(0, serverScroll - 1); renderMain() end
      if key == keys.down then serverScroll = math.min(maxStart, serverScroll + 1); renderMain() end

      if key == keys.n then
        -- add server via visible prompts (no goto)
        -- Prompt name
        buf:hline(1, H - 2, W, colors.black)
        buf:hline(1, H - 1, W, colors.black)
        buf:text(1, H - 2, "New server name:")
        local name = ui.readAt(buf, 1, H - 1, { fg = colors.white, bg = colors.black })

        if name ~= "" then
          -- Prompt ID
          buf:hline(1, H - 2, W, colors.black)
          buf:hline(1, H - 1, W, colors.black)
          buf:text(1, H - 2, "Server Id:")
          local sid = ui.readAt(buf, 1, H - 1, { fg = colors.white, bg = colors.black })

          if sid ~= "" then
            table.insert(pages, { name = name, server = sid, outputs = {} })
            store.save(pages)
          end
        end
        renderMain()
      end

    elseif pageState == "page" then
      local firstY, visible = 4, math.max(0, (H - 2) - 4)
      local maxStart = math.max(0, #pages[currentServerId].outputs - visible)
      if key == keys.up   then outputScroll = math.max(0, outputScroll - 1); renderServer() end
      if key == keys.down then outputScroll = math.min(maxStart, outputScroll + 1); renderServer() end
      if key == keys.n and #pages[currentServerId].outputs < 16 then screenAddOutput() end
    end

  elseif ev == "mouse_scroll" then
    local dir = p1
    if pageState == "main" then
      local firstY, visible = 4, math.max(0, (H - 1) - 4)
      local maxStart = math.max(0, #pages - visible)
      serverScroll = math.max(0, math.min(maxStart, serverScroll + (dir > 0 and 1 or -1)))
      renderMain()
    elseif pageState == "page" then
      local firstY, visible = 4, math.max(0, (H - 2) - 4)
      local maxStart = math.max(0, #pages[currentServerId].outputs - visible)
      outputScroll = math.max(0, math.min(maxStart, outputScroll + (dir > 0 and 1 or -1)))
      renderServer()
    end

  elseif ev == "mouse_click" then
    local mx, my = p2, p3
    -- Global footer "Update" button
    if updateBtn and updateBtn.active then
      local mx, my = p2, p3
      if my == updateBtn.y and mx >= updateBtn.x1 and mx <= updateBtn.x2 then
        -- Optional: show feedback
        buf:text(updateBtn.x1, updateBtn.y, "Updating…", colors.white, colors.black)
        buf:commit()

        -- Run updater (no args -> uses lock). Adjust path if you keep it elsewhere.
        local ok, err = pcall(function() shell.run("urc/updater.lua") end)
        if not ok then
          -- brief error flash; keep it simple to avoid flashing whole UI
          buf:text(updateBtn.x1, updateBtn.y, "Update failed", colors.red, colors.black)
          buf:commit()
          sleep(1)
        end

        -- Reload version + manifest and re-render current screen
        version       = dofile(rel("version.lua"))
        manifestMngr:setData()

        if pageState == "main" then
          renderMain()
        elseif pageState == "page" then
          renderServer()
        else
          -- fallback: redraw current buffer if you have other screens
          renderMain()
        end
        -- consume click so it doesn't fall through to list logic
        --goto continue_event_loop
      end
    end
    if pageState == "main" then
      if not (mx <= 6 and my == H) then
        local firstY, visible = 4, math.max(0, (H) - 4)
        local rowIndex = my - firstY + 1
        if rowIndex >= 1 and rowIndex <= visible then
          local idx = serverScroll + rowIndex
          if pages[idx] then
            if mx == W then
              net.sendAllOff(pages[idx].server)
              table.remove(pages, idx); store.save(pages); renderMain()
            else
              screenServer(idx)
            end
          end
        end
      end

    elseif pageState == "page" then
      if mx <= 6 and my == H then
        screenMain()
      elseif mx >= W - 1 and mx <= W and my == 1 then
        refreshServer(currentServerId); renderServer()
      else
        local firstY, visible = 4, math.max(0, (H - 2) - 4)
        local rowIndex = my - firstY + 1
        if rowIndex >= 1 and rowIndex <= visible then
          local idx = outputScroll + rowIndex
          local out = pages[currentServerId].outputs[idx]
          if out then
            if mx == W then
              net.sendState(pages[currentServerId].server, out.cable, "Off")
              table.remove(pages[currentServerId].outputs, idx); store.save(pages); renderServer()

            elseif mx == 1 then
              screenPickColorFor(idx)

            elseif mx >= 2 and mx <= W - 7 then
              -- two-line rename at bottom
              buf:hline(1, H - 2, W, colors.black)
              buf:hline(1, H - 1, W, colors.black)
              buf:text(1, H - 2, "New name for '" .. out.name .. "':")
              local name = ui.readAt(buf, 1, H - 1, { fg = colors.white, bg = colors.black })
              if name and name ~= "" then out.name = name; store.save(pages) end
              renderServer()

            elseif mx == W - 2 then
              out.invert = not out.invert; store.save(pages)
              net.sendState(pages[currentServerId].server, out.cable, effectiveState(out))
              renderServer()

            elseif mx >= W - 6 and mx <= W - 3 then
              out.state = (out.state == "Off") and "On" or "Off"; store.save(pages)
              net.sendState(pages[currentServerId].server, out.cable, effectiveState(out))
              renderServer()
            end
          end
        end
      end
    end
  end
end
