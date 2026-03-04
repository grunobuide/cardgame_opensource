--- Nine-patch (9-slice) image drawing for LOVE2D.
-- Splits an image into 9 regions (4 corners, 4 edges, 1 center)
-- and stretches only the edges/center when drawing at arbitrary sizes.

local NinePatch = {}
NinePatch.__index = NinePatch

local quad_cache = {}

--- Create a new NinePatch from a LOVE2D Image.
-- @param image  love.Image
-- @param corner  pixel size of the fixed corner region (default 12)
-- @return NinePatch instance
function NinePatch.new(image, corner)
  local self = setmetatable({}, NinePatch)
  self.image = image
  self.iw = image:getWidth()
  self.ih = image:getHeight()
  self.corner = math.min(corner or 12, math.floor(self.iw / 2), math.floor(self.ih / 2))
  self:_build_quads()
  return self
end

function NinePatch:_build_quads()
  local c = self.corner
  local iw, ih = self.iw, self.ih
  local mw = iw - c * 2  -- middle width in source
  local mh = ih - c * 2  -- middle height in source

  local key = ("%d:%d:%d"):format(iw, ih, c)
  if quad_cache[key] then
    self.quads = quad_cache[key]
    return
  end

  local q = {}
  -- corners
  q.tl = love.graphics.newQuad(0,        0,        c,  c,  iw, ih)
  q.tr = love.graphics.newQuad(iw - c,   0,        c,  c,  iw, ih)
  q.bl = love.graphics.newQuad(0,        ih - c,   c,  c,  iw, ih)
  q.br = love.graphics.newQuad(iw - c,   ih - c,   c,  c,  iw, ih)
  -- edges
  q.t  = love.graphics.newQuad(c,        0,        mw, c,  iw, ih)
  q.b  = love.graphics.newQuad(c,        ih - c,   mw, c,  iw, ih)
  q.l  = love.graphics.newQuad(0,        c,        c,  mh, iw, ih)
  q.r  = love.graphics.newQuad(iw - c,   c,        c,  mh, iw, ih)
  -- center
  q.c  = love.graphics.newQuad(c,        c,        mw, mh, iw, ih)

  q.mw = mw
  q.mh = mh

  quad_cache[key] = q
  self.quads = q
end

--- Draw the nine-patch stretched to fill a rectangle.
-- @param x, y   top-left position
-- @param w, h   target size (must be >= corner*2)
-- @param alpha   optional opacity (0-1, default 1)
function NinePatch:draw(x, y, w, h, alpha)
  local c = self.corner
  -- clamp minimum size to 2 corners
  w = math.max(w, c * 2)
  h = math.max(h, c * 2)

  local q = self.quads
  local mw = q.mw  -- source middle width
  local mh = q.mh  -- source middle height
  local dw = w - c * 2  -- destination middle width
  local dh = h - c * 2  -- destination middle height
  local sx = mw > 0 and (dw / mw) or 0
  local sy = mh > 0 and (dh / mh) or 0

  love.graphics.setColor(1, 1, 1, alpha or 1)
  local img = self.image

  -- corners (no scale)
  love.graphics.draw(img, q.tl, x,          y,          0, 1, 1)
  love.graphics.draw(img, q.tr, x + w - c,  y,          0, 1, 1)
  love.graphics.draw(img, q.bl, x,          y + h - c,  0, 1, 1)
  love.graphics.draw(img, q.br, x + w - c,  y + h - c,  0, 1, 1)

  -- edges (stretch one axis)
  if dw > 0 then
    love.graphics.draw(img, q.t, x + c, y,         0, sx, 1)
    love.graphics.draw(img, q.b, x + c, y + h - c, 0, sx, 1)
  end
  if dh > 0 then
    love.graphics.draw(img, q.l, x,         y + c, 0, 1, sy)
    love.graphics.draw(img, q.r, x + w - c, y + c, 0, 1, sy)
  end

  -- center (stretch both axes)
  if dw > 0 and dh > 0 then
    love.graphics.draw(img, q.c, x + c, y + c, 0, sx, sy)
  end
end

return NinePatch
