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
data game
  = game
    { foo :: string
    }

data message
  = button horizdir vertdir
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

function btntodirection()
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

-- λ game_update :: message -> game -> game
-- λ game_update = undefined
function game_update(msg, g)
  local horiz, vert = btntodirection()
  g.player = player_update(horiz, vert, g.player)
  return g
end

-- λ game_draw :: game -> io ()
-- λ game_draw = undefined
function game_draw(g)
  cls(1)
  map(0, 0, 0, 0, 128, 128)
  player_draw(g.player)
end

--
-- vec2 helper.
--

--[[ λλ
data vec2
  = vec2
    { x :: float
    , y :: float
    }
λλ ]]

function vec2(x, y)
  return {
    x = x or 0,
    y = y or 0,
  }
end

-- vec2_mag :: vec2 -> nonnegative.float
function vec2_mag(v)
  return sqrt(v.x^2 + v.y^2)
end

-- vec2_norm :: vec2 -> vec2
function vec2_norm(v)
  local m = vec2_mag(v)
  if m == 0 then return vec2() end
  return vec2(v.x/m, v.y/m)
end

--
-- player entity.
--

--[[ λλ
data player
  = player
    { pos :: vec2
    }
λλ ]]

function player(x, y, w, h)
  return {
    pos = vec2(x, y), -- center of player (4,4)
    vel = vec2(0, 0),
    max_vel = vec2(0, 2),
    cursor_pos = vec2(x, y),
    width = w,
    height = h,
  }
end

-- player_update :: message -> message -> player -> player
-- note: all vectors are expressed in screen space.
function player_update(horizdir, vertdir, p)
  assert(horizdir ~= nil)
  assert(vertdir ~= nil)

  -- move cursor
  if horizdir == horiz_dir.left  then p.cursor_pos.x -= 1 end
  if horizdir == horiz_dir.right then p.cursor_pos.x += 1 end

  if vertdir == vert_dir.up   then p.cursor_pos.y -= 1 end
  if vertdir == vert_dir.down then p.cursor_pos.y += 1 end

  -- apply gravity
  local grav = 0.15
  p.vel.y += grav
  p.vel.y = max(-p.max_vel.y, p.vel.y)
  p.vel.y = min(p.vel.y, p.max_vel.y)

  -- add floor collisions
  collide_floor(p)

  -- move position
  p.pos.y += p.vel.y

  return p
end

-- player_draw :: player -> io ()
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

  print(p.pos.x .. ', ' .. p.pos.y)
  print(p.vel.x .. ', ' .. p.vel.y)
end

--
-- collision utils.
--

-- requires:
-- - .pos.x
-- - .pos.y
-- - .vel.y
-- - .width
-- - .height
function collide_floor(entity)
  -- not colliding if not falling.
  if entity.vel.y < 0 then
    return false
  end

  local step = entity.width / 3
  for i=-step,step,step do
    local cell_y = flr(
      (entity.pos.y+entity.height) / 8
    )

    -- screen space to map space.
    local tile = mget(
      (entity.pos.x+i) / 8,
      cell_y
    )

    -- if tile is a floor tile,
    if fget(tile, 0) then
      entity.vel.y = 0
      entity.pos.y = (
          cell_y * 8 -- map space to screen space
        - entity.height
      )

      return true
    end
  end

  return false
end
__gfx__
00000000777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700077707777770777077077077777077077777077007777077707777070000000000000000000000000000000000000000000000000000000000000000
__gff__
0001010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808010101010801080101010808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080408040808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808040404040404040404080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0808080808080808080808080808080808080808080808080808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
