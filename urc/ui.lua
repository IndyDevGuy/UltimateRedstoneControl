local M = {}

function M.newBuffer(w, h, parent)
  parent = parent or term.current()
  local win = window.create(parent, 1, 1, w, h, false) -- start hidden

  local buf = { win = win, w = w, h = h }

  function buf:clear(bg)
    self.win.setBackgroundColor(bg or colors.black)
    self.win.setTextColor(colors.white)
    self.win.clear()
  end

  function buf:text(x, y, s, fg, bg)
    if bg then self.win.setBackgroundColor(bg) end
    if fg then self.win.setTextColor(fg) end
    self.win.setCursorPos(x, y)
    self.win.write(s)
    self.win.setBackgroundColor(colors.black)
    self.win.setTextColor(colors.white)
  end

  function buf:pixel(x, y, col)
    self.win.setBackgroundColor(col)
    self.win.setCursorPos(x, y)
    self.win.write(" ")
    self.win.setBackgroundColor(colors.black)
  end

  function buf:hline(x1, y, x2, col)
    self.win.setBackgroundColor(col)
    self.win.setCursorPos(x1, y)
    self.win.write(string.rep(" ", math.max(0, x2 - x1 + 1)))
    self.win.setBackgroundColor(colors.black)
  end

  -- Present one frame: briefly show, then hide
  function buf:commit()
    self.win.setVisible(true)
    self.win.redraw()
    self.win.setVisible(false)
  end

  -- Keep shown/hidden explicitly (for interactive input)
  function buf:show()  self.win.setVisible(true)  end
  function buf:hide()  self.win.setVisible(false) end
  function buf:term()  return self.win end

  return buf
end

function M.header(buf, title, rightLabel, rightColor)
  local w = buf.w
  buf:hline(1, 1, w - 1, colors.blue)
  buf:text(1, 1, title or "", colors.white, colors.blue)
  buf:hline(1, 2, w, colors.white)
  if rightLabel then
    buf:hline(w - 1, 1, w, rightColor or colors.green)
    buf:text(w - 1, 1, rightLabel, colors.white, rightColor or colors.green)
  end
end

function M.footerBack(buf)
  local w, h = buf.w, buf.h
  buf:hline(1, h, w, colors.black)
  buf:text(1, h, "<-Back", colors.white, colors.black)
end

function M.footerVersion(buf, version, updateText)
  local w, h = buf.w, buf.h
  local upd = tostring(updateText or "")
  local ver = tostring(version or "")
  local total = #upd + 1 + #ver           -- one space between
  local x1 = math.floor((w / 2) + ((w / 2) - total) / 2) + 1
  local y  = h

  -- clean just the area we’ll draw on
  buf:hline(x1, y, x1 + total - 1, colors.black)
  local updateColor = (upd == "Update") and colors.yellow or colors.green
  buf:text(x1, y, upd, updateColor, colors.black)
  buf:text(x1 + #upd + 1, y, ver, colors.white, colors.black)

  -- return a clickable rect for the update word
  return { x1 = x1, x2 = x1 + #upd - 1, y = y, active = (upd == "Update") }
end

-- NEW: visible input helper (shows buffer while typing)
function M.readAt(buf, x, y, opts)
  opts = opts or {}
  buf:show()
  local prev = term.redirect(buf:term())
  if opts.bg then term.setBackgroundColor(opts.bg) else term.setBackgroundColor(colors.black) end
  if opts.fg then term.setTextColor(opts.fg) else term.setTextColor(colors.white) end
  term.setCursorPos(x, y)
  term.setCursorBlink(true)
  local text = read() or ""
  term.setCursorBlink(false)
  term.redirect(prev)
  -- leave what you typed visible, then hide; caller will re-render next frame
  buf:hide()
  return text
end

return M
