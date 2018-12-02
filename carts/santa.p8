pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- super santa world
-- by @nucleartide

--
-- game loop.
--

do
  local g

  function _init()
    g = game()
  end

  function _update60()
    g = game_update(nil, g)
  end

  function _draw()
    if g ~= nil then
      game_draw(g)
    end
  end
end

--
-- game entity.
--

--[[ λλ
data Game
  = Game
    { foo :: String
    }

data Message
  = Button HorizDir VertDir
λλ ]]

horiz_dir = {
  none  = 0,
  left  = 1,
  right = 2,
}

vert_dir = {
  none = 0,
  up   = 1,
  down = 2,
}

function btnToDirection()
  local horiz
  local vert

  if btn(0) == btn(1) then
    horiz = horiz_dir.none
  elseif btn(0) then
    horiz = horiz_dir.left
  elseif btn(1) then
    horiz = horiz_dir.right
  end

  if btn(2) == btn(3) then
    vert = vert_dir.none
  elseif btn(2) then
    vert = vert_dir.up
  elseif btn(3) then
    vert = vert_dir.down
  end

  return horiz, vert
end

function game()
  return {
    player = player(64, 64, 4, 4),
  }
end

-- λ game_update :: Message -> Game -> Game
-- λ game_update = undefined
function game_update(msg, g)
  local horiz, vert = btnToDirection()
  g.player = player_update(horiz, vert, g.player)
  return g
end

-- λ game_draw :: Game -> IO ()
-- λ game_draw = undefined
function game_draw(g)
  cls(1)
  player_draw(g.player)
end

--
-- vec2 helper.
--

--[[ λλ
data Vec2
  = Vec2
    { x :: Float
    , y :: Float
    }
λλ ]]

function vec2(x, y)
  return {
    x = x or 0,
    y = y or 0,
  }
end

-- vec2_mag :: Vec2 -> NonNegative.Float
function vec2_mag(v)
  return sqrt(v.x^2 + v.y^2)
end

-- vec2_norm :: Vec2 -> Vec2
function vec2_norm(v)
  local m = vec2_mag(v)
  if m == 0 then return vec2() end
  return vec2(v.x/m, v.y/m)
end

--
-- player entity.
--

--[[ λλ
data Player
  = Player
    { pos :: Vec2
    }
λλ ]]

function player(x, y, w, h)
  return {
    pos = vec2(x, y),
    vel = vec2(0, 0),
    max_vel = vec2(0, 2),
    cursor_pos = vec2(x, y),
    width = w,
    height = h,
  }
end

-- player_update :: Message -> Message -> Player -> Player
-- note: all vectors are expressed in screen space.
function player_update(horizDir, vertDir, p)
  assert(horizDir ~= nil)
  assert(vertDir ~= nil)

  -- move cursor
  if horizDir == horiz_dir.left  then p.cursor_pos.x -= 1 end
  if horizDir == horiz_dir.right then p.cursor_pos.x += 1 end

  if vertDir == vert_dir.up   then p.cursor_pos.y -= 1 end
  if vertDir == vert_dir.down then p.cursor_pos.y += 1 end

  -- apply gravity
  local grav = 0.15
  p.vel.y += grav
  p.vel.y = max(-p.max_vel.y, p.vel.y)
  p.vel.y = min(p.vel.y, p.max_vel.y)
  p.pos.y += p.vel.y

  -- add floor collisions

  return p
end

-- player_draw :: Player -> IO ()
function player_draw(p)
  rectfill(
    p.pos.x,
    p.pos.y,
    p.pos.x + p.width  - 1,
    p.pos.y + p.height - 1,
    8
  )

  rect(
    p.cursor_pos.x,
    p.cursor_pos.y,
    p.cursor_pos.x + p.width - 1,
    p.cursor_pos.y + p.height - 1,
    7
  )
end

--
-- collision utils.
--

-- Requires:
-- - .x
-- - .y
-- - .dy
-- - .h
-- - .width
-- - .height
function collide_floor(entity)
  -- Not colliding if not falling.
  if entity.dy < 0 then return false end

  local step = entity.width / 3
  for i=-step,step,step do
    local cell_y = flr(
      (entity.y+entity.h/2) / 8
    )

    -- screen space to map space.
    local tile = mget(
      (entity.x+i) / 8,
      cell_y
    )

    -- if tile is a floor tile,
    if fget(tile, 0) then
      entity.dy = 0
      entity.y = (
          cell_y * 8 -- map space to screen space
        - entity.height/2
      )

      return true
    end
  end

  return false
end
