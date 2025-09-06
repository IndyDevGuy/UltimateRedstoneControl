--============================
-- File: /urc/palette.lua
--============================
local P = {}

P.COLORS = {
  white = colors.white, orange = colors.orange, magenta = colors.magenta, lightblue = colors.lightBlue,
  yellow = colors.yellow, lime = colors.lime, black = colors.black, gray = colors.gray,
  lightgray = colors.lightGray, cyan = colors.cyan, purple = colors.purple, blue = colors.blue,
  brown = colors.brown, green = colors.green, red = colors.red, pink = colors.pink,
}

P.ROWS = {
  {"white","orange","magenta","lightblue"},
  {"yellow","lime","black","gray"},
  {"lightgray","cyan","purple","blue"},
  {"brown","green","red","pink"},
}

--- Draw a 4x4 palette at (ox,oy). Each swatch is 2 chars wide.
--- exists(name) -> bool is used to put XX on used colors.
function P.draw(buf, selected, ox, oy, exists)
  for r = 1, 4 do
    for c = 1, 4 do
      local name = P.ROWS[r][c]
      local col = P.COLORS[name]
      local bx = ox + (c - 1) * 2
      local by = oy + (r - 1)
      buf:hline(bx, by, bx + 1, col)
      if exists and exists(name) then
        buf:text(bx, by, "XX", name == "black" and colors.white or colors.black, col)
      end
      if selected == name then
        buf:hline(bx, by + 1, bx + 1, colors.black)
        buf:text(bx, by + 1, "==", colors.white, colors.black)
      end
    end
  end
end

function P.hit(px, py, ox, oy)
  for r = 1, 4 do
    for c = 1, 4 do
      local bx = ox + (c - 1) * 2
      local by = oy + (r - 1)
      if py == by and px >= bx and px <= bx + 1 then
        return P.ROWS[r][c]
      end
    end
  end
  return nil
end

return P