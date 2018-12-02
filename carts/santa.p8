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
  local p = player(64, 64, 13, 16)
  return {
    player = p,
    cam = cam(p.pos, p.cursor_pos),
  }
end

-- λ game_update :: message -> game -> game
-- λ game_update = undefined
function game_update(msg, g)
  local horiz, vert = btntodirection()
  g.player = player_update(horiz, vert, g.player)
  g.cam = cam_update(g.cam)
  for i=1,#g.player.snowballs do
    g.player.snowballs[i] = snowball_update(g.player.snowballs[i])
  end
  for i=1,#g.player.explosions do
    g.player.explosions[i] = explosion_update(g.player.explosions[i])
  end
  return g
end

-- λ game_draw :: game -> io ()
-- λ game_draw = undefined
function game_draw(g)
  cls()
  camera(cam_pos(g.cam))
  map(0, 0, 0, 0, 128, 128)
  player_draw(g.player)
  for i=1,#g.player.snowballs do
    snowball_draw(g.player.snowballs[i])
  end
  for i=1,#g.player.explosions do
    explosion_draw(g.player.explosions[i])
  end
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
    cursor_width = 4,
    cursor_height = 4,
    ammo = 10,
    snowballs = {},
    explosions = {},
    radius = 6,
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

  -- add ceiling collisions
  collide_ceil(p)

  -- add wall collisions
  collide_wall(p)
  collide_wall_left(p)

  -- apply friction
  if p.vel.y == 0 then
    -- ground friction
    p.vel.x = lerp(p.vel.x, 0, 0.4)
  else
    -- air friction.. nope
    --p.vel.x = lerp(p.vel.x, 0, 0.95)
  end

  -- move position
  p.pos.x += p.vel.x
  p.pos.y += p.vel.y

  -- z button, then fire snowball
  if btnp(4) then
    player_fire_snowball(p)
  end

  return p
end

function player_fire_snowball(p)
  local v = vec2(p.cursor_pos.x-p.pos.x, p.cursor_pos.y-p.pos.y)
  v = vec2_norm(v)
  local offset_x = 3
  local offset_y = 6
  add(p.snowballs, snowball(p.pos.x+offset_x, p.pos.y+offset_y, v.x, v.y, p))
end

function player_center(p)
  return p.pos.x+7, p.pos.y+9
end

-- player_draw :: player -> io ()
function player_draw(p)
  spr(
    17,
    p.pos.x,
    p.pos.y,
    2,
    2
  )

  rect(
    p.cursor_pos.x,
    p.cursor_pos.y,
    p.cursor_pos.x + p.cursor_width  - 1,
    p.cursor_pos.y + p.cursor_height - 1,
    7
  )

  local cx, cy = player_center(p)
  pset(cx, cy, 15)
end

--
-- snowball entity.
--

function snowball(px, py, vx, vy, p)
  return {
    pos = vec2(px, py),
    vel = vec2(vx, vy),
    radius = 2,
    player = p,
    exploded = false,
  }
end

function snowball_update(s)
  if s.exploded then return s end

  s.pos.x += s.vel.x
  s.pos.y += s.vel.y

  -- check if collides with floor tile
  -- if it collides, instantiate an explosion

  -- screen space to map space
  local cell_x = s.pos.x/8
  local cell_y = s.pos.y/8
  local tile   = mget(cell_x, cell_y)

  -- if collision,
  if fget(tile, 0) or fget(tile, 1) or fget(tile, 2) or fget(tile, 3) then
    -- instantiate an explosion
    add(s.player.explosions, explosion(s.pos.x, s.pos.y, s.player))
    s.exploded = true
  end

  return s
end

function snowball_draw(s)
  if s.exploded then return end

  circfill(
    s.pos.x-s.radius/2,
    s.pos.y-s.radius/2,
    s.radius,
    7
  )
end

--
-- explosion entity.
--

function explosion(x, y, p)
  return {
    pos = vec2(x, y),
    t = 0,
    lifetime = 10,
    radius = 5,
    player = p,
    applied = false,
  }
end

function explosion_update(e)
  e.t += 1
  local cx, cy = player_center(e.player)

  if e.t <= e.lifetime then
    -- then check for collision with player
    local dx = abs(e.pos.x - cx)
    local dy = abs(e.pos.y - cy)
    local collides = false
    local combined_radius = e.radius + e.player.radius

    -- ensure no overflow
    if dx < 1.2*combined_radius and dy < 1.2*combined_radius then
      local dist = vec2_mag(vec2(dx, dy))
      if dist < combined_radius+5 then collides = true end
    end

    if collides and (not applied) then
      -- add velocity to player
      local v = vec2(cx-e.pos.x, cy-e.pos.y)
      v = vec2_norm(v)
      e.player.vel.x += v.x*0.4
      e.player.vel.y += v.y*0.4
      e.applied = true
    end
  end

  return e
end

function explosion_draw(e)
  if e.t <= e.lifetime then
    if e.t <= e.lifetime/5 then
      circfill(e.pos.x, e.pos.y, e.radius, 8)
    elseif e.t <= 2*e.lifetime/5 then
      circfill(e.pos.x, e.pos.y, e.radius, 10)
    elseif e.t <= 3*e.lifetime/5 then
      circfill(e.pos.x, e.pos.y, e.radius, 6)
    else
      circfill(e.pos.x, e.pos.y, e.radius, 7)
    end
  end
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

-- requires:
-- - .pos.x
-- - .pos.y
-- - .vel.y
-- - .width
-- - .height
function collide_ceil(entity)
  -- not colliding if falling.
  if entity.vel.y > 0 then
    return false
  end

  local step = entity.width / 3
  for i=-step,step,step do
    local cell_y = flr(
      (entity.pos.y-1) / 8
    )

    local cx, cy = player_center(entity)

    -- screen space to map space.
    local tile = mget(
      (cx+i) / 8,
      cell_y
    )

    -- if tile is a ceiling tile,
    if fget(tile, 3) then
      entity.vel.y = 0
      entity.pos.y = (
          cell_y * 8 -- map space to screen space
        + 8
      )

      return true
    end
  end

  return false
end

-- requires:
-- - .pos.x
-- - .pos.y
-- - .vel.x
-- - .width
-- - .height
function collide_wall(entity)
  if entity.vel.x <= 0 then
    return false
  end

  local step = entity.height / 3
  for i=-step,step,step do
    -- check right cell first
    local cell_x = flr(
      (entity.pos.x+entity.width) / 8
    )

    -- screen space to map space.
    local cx, cy = player_center(entity)
    local tile = mget(
      cell_x,
      (cy+i)/8
    )

    -- if tile is a side tile,
    if fget(tile, 2) then
      entity.vel.x = 0
      entity.pos.x = (
          cell_x * 8 -- map space to screen space
        - entity.width
      )

      return true
    end
  end

  return false
end

-- requires:
-- - .pos.x
-- - .pos.y
-- - .vel.x
-- - .width
-- - .height
function collide_wall_left(entity)
  if entity.vel.x >= 0 then
    return false
  end

  local step = entity.height / 3
  for i=-step,step,step do
    -- check left cell first
    local cell_x = flr(
      (entity.pos.x-1) / 8
    )

    -- screen space to map space.
    local cx, cy = player_center(entity)
    local tile = mget(
      cell_x,
      (cy+i)/8
    )

    -- if tile is a side tile,
    if fget(tile, 1) then
      entity.vel.x = 0
      entity.pos.x = (
          cell_x * 8 -- map space to screen space
        + 8
      )

      return true
    end
  end

  return false
end

--
-- cam entity.
--

function cam(target_pos, _cursor)
  return {
    -- target to follow
    -- assumes target has .cursor_pos
    target = target_pos,
    _cursor = _cursor,

    -- camera position
    pos = vec2(target_pos.x, target_pos.y),

    -- how far from (64, 64) before camera starts moving
    pull_threshold = 16,

    -- edges of level
    pos_min = vec2(64, 64),
    pos_max = vec2(320, 64),
  }
end

function cam_update(c)

  --
  -- follow target if target exceeds pull range.
  --

  if pull_max_x(c) < c.target.x then
    -- move at most 4 pixels right, per frame.
    c.pos.x += min(c.target.x-pull_max_x(c), 4)
  end

  if c.target.x < pull_min_x(c) then
    -- move at most 4 pixels left, per frame.
    c.pos.x += max(c.target.x-pull_min_x(c), -4)
  end

  if pull_max_y(c) < c.target.y then
    -- move at most 4 pixels down, per frame.
    c.pos.y += min(c.target.y-pull_max_y(c), 4)
  end

  if c.target.y < pull_min_y(c) then
    -- move at most 4 pixels up, per frame.
    c.pos.y += max(c.target.y-pull_min_y(c), -4)
  end

  --
  -- enforce min and max positions.
  --

  c.pos.x = min(max(c.pos_min.x, c.pos.x), c.pos_max.x)
  c.pos.y = min(max(c.pos_min.y, c.pos.y), c.pos_max.y)

  c._cursor.x = min(max(c.pos.x-54, c._cursor.x), c.pos.x+54)
  c._cursor.y = min(max(c.pos.y-54, c._cursor.y), c.pos.y+54)

  -- remember to return!!
  return c
end

function pull_max_x(c)
  return c.pos.x + c.pull_threshold
end

function pull_min_x(c)
  return c.pos.x - c.pull_threshold
end

function pull_max_y(c)
  return c.pos.y + c.pull_threshold
end

function pull_min_y(c)
  return c.pos.y - c.pull_threshold
end

-- camera position that is fed to `camera()`.
-- note that we subtract (64, 64) because we want
-- the camera (as an entity) to be centered in screen space.
function cam_pos(c)
  return c.pos.x-64, c.pos.y-64
end

--
-- lerp util.
--

function lerp(a, b, t)
  return (1-t)*a + t*b
end
__gfx__
00000000777777777777777777777777000000007000000000000007000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000007070000000000707000444404444000000004444044440000000000000000000000000000000000000000000
00700700077077077077770770770770000000007070000000000707000444404444040000404444044440000000000000000000000000000000000000000000
00077000000000000000000000000000000000007000000000000007000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000007070000000000707044440444404444004444044440444400000000000000000000000000000000000000000
00700700000000000000000000000000000000007070000000000707044440444404444004444044440444400000000000000000000000000000000000000000
00000000000000000000000000000000000000007000000000000007000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000007070000000000707440444404444044444404444044440440000000000000000000000000000000000000000
00000000000070000000000000000700000000007070000000000707440444404444044444404444044440440000000000000000000000000000000000000000
00000000000088880000000000000888800000007000000000000007000000000000000000000000000000000000000000000000000000000000000000000000
00000000000008778000000000000087780000007070000000000707044440444404444004444044440444400000000000000000000000000000000000000000
00000000055507ff700000000000007ff70000007070000000000707044440444404444004444044440444400000000000000000000000000000000000000000
0000000056665f0f07000000000007f0f07000007070000000000707000000000000000000000000000000000000000000000000000000000000000000000000
00000000566657ff788000000000887ff78800007070000000000707000444404444040000404444044440000000000000000000000000000000000000000000
00000000566658778888000000088887788880007000000000000007000444404444000000004444044440000000000000000000000000000000000000000000
00000000055588778888800000888887788888007070000000000707000000000000000000000000000000000000000000000000000000000000000000000000
000000000fff88788888800000888886888888007070000000000707000000000000000000000000000000000000000000000000000000000000000000000000
00000000068888878888600000588888688885007000000000000007000444404444000000004444044440000000000000000000000000000000000000000000
00000000086888878886800000858888688858007070000000000707000444494444040000404444944440000000000000000000000000000000000000000000
00000000088668878668800000885588685588007070000000000707000000099000000000000009900000000000000000000000000000000000000000000000
00000000007886696887000000068855958860007000000000000007044440999404444004444049990444400000000000000000000000000000000000000000
00000000007788788877000000066886888660007070000000000707044440999904444004444099990444400000000000000000000000000000000000000000
000000000088777777880000000886666668800070700000000007070000009aa90000000000009aa90000000000000000000000000000000000000000000000
000000000080000000080000000800000000800070000000000000074404499aa99404444440499aa99440440000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000440449aaaa940444444049aaaa9440440000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000099aa99000000000099aa99000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000044440999904444004444099990444400000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000044440455404444004444045540444400000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077077077077770770770770000000000000000000000000000444404444040000404444044440000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000444404444000000004444044440000000000000000000000000000000000000000000
00000000777777777777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0001010100040200000000000000000000000000000402000000000000000000000000000004020101000000000000000008080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000007080000000000000000090a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000017180000000000000000191a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000027280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000037380000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000313232323232323232323232323232323232323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006000000000000000000000000000000000000000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016000000000000000000000000000000000000000015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016000000000000000000000000000000000000000015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016000000000000000000000000000000000000000015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016000000003132323233000000000000000000000015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016000000000000000000000000000000000000000015000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0026000000000000000000000000000000000000000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000010202020202020202020202020202020202020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
