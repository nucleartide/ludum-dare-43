pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- super santa world
-- by @nucleartide

--[[
todos:

collision detection for santa
collision detection for snowballs
gravity
recoil
inhale air, slow descent
jetpack
camera shake
]]

-- enable mouse coords.
poke(0x5f2d, 1)

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
  local c = cam(p.pos)
  local cur = cursor_entity(c)
  p.cursor_entity = cur

  return {
    player = p,
    cam = c,
    cursor_entity = cur,
  }
end

-- λ game_update :: message -> game -> game
-- λ game_update = undefined
function game_update(msg, g)
  local horiz, vert = btntodirection()
  g.cursor_entity = cursor_entity_update(g.cursor_entity)
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
  palt(0, false)
  palt(1, true)
  cls(1)

  camera(cam_pos(g.cam))
  map(0, 0, 0, 0, 128, 128)
  player_draw(g.player)
  for i=1,#g.player.snowballs do
    snowball_draw(g.player.snowballs[i])
  end
  for i=1,#g.player.explosions do
    explosion_draw(g.player.explosions[i])
  end

  camera()
  cursor_entity_draw(g.cursor_entity)

  --camera()
  --print('ho ho ho! time to send gifts!', 4, 110, 7)
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
    width = w,
    height = h,
    cursor_width = 4,
    cursor_height = 4,
    ammo = 10,
    snowballs = {},
    explosions = {},
    radius = 6,
    cursor_entity = nil
  }
end

-- player_update :: message -> message -> player -> player
-- note: all vectors are expressed in screen space.
function player_update(horizdir, vertdir, p)
  assert(horizdir ~= nil)
  assert(vertdir ~= nil)
  assert(p.cursor_entity ~= nil)

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
  --if btnp(4) then
  if stat(34) == 1 then
    player_fire_snowball(p)
  end

  return p
end

function player_fire_snowball(p)
  local cx, cy = cursor_world_space(p.cursor_entity)
  local v = vec2(cx-p.pos.x, cy-p.pos.y)
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

  local cx, cy = player_center(p)
  pset(cx, cy, 15)
end

--
-- cursor entity.
--

function cursor_entity(cam)
  return {
    pos = vec2(),
    width = 4,
    height = 4,
    cam = cam,
    t = 0,
  }
end

function cursor_world_space(c)
  local cx, cy = cam_pos(c.cam)
  return cx+c.pos.x, cy+c.pos.y
end

function cursor_entity_update(c)
  c.t += 1
  c.t = c.t % 60

  c.pos.x = stat(32)
  c.pos.y = stat(33)

  c.pos.x = min(max(10, c.pos.x), 118)
  c.pos.y = min(max(10, c.pos.y), 118)

  return c
end

function cursor_entity_draw(c)
  rect(
    c.pos.x - c.width/2,
    c.pos.y - c.height/2,
    c.pos.x + c.width/2  - 1,
    c.pos.y + c.height/2 - 1,
    7
  )
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
      e.player.vel.x += v.x*0.7
      e.player.vel.y += v.y*0.7
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

function cam(target_pos)
  return {
    -- target to follow
    target = target_pos,

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
00000000777777777777777777777777000000007111111111111117000000000000000000000000000000007777777777777777777777770000000000000000
00000000111111111111111111111111000000007171111111111717000444404444000000004444044440000000000000000000000000000000000000000000
00700700177177177177771771771771000000007171111111111717000444404444040000404444044440000770770770777707707707700000000000000000
00077000111111111111111111111111000000007111111111111117000000000000000000000000000000000000000000000000000000000000000000000000
00077000111111111111111111111111000000007171111111111717044440444404444004444044440444400000000000000000000000000000000000000000
00700700111111111111111111111111000000007171111111111717044440444404444004444044440444400000000000000000000000000000000000000000
00000000111111111111111111111111000000007111111111111117000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111111111111111111111000000007171111111111717440444404444044444404444044440440000000000000000000000000000000000000000
00000000111171111111111100000700000000007171111111111717440444404444044444404444044440447000000000000000000000000000000000000000
00000000111188881111111100000888800000007111111111111117000000000000000000000000000000007070000000000000000000000000000000000000
00000000111118778111111100000087780000007171111111111717044440444404444004444044440444407070000000000000000000000000000000000000
00000000155517ff711111110000007ff70000007171111111111717044440444404444004444044440444407000000000000000000000000000000000000000
0000000056665f0f07111111000007f0f07000007171111111111717000000000000000000000000000000007070000000000000000000000000000000000000
00000000566657ff788111110000887ff78800007171111111111717000444404444040000404444044440007070000000000000000000000000000000000000
00000000566658778888111100088887788880007111111111111117000444404444000000004444044440007000000000000000000000000000000000000000
00000000155588778888811100888887788888007171111111111717000000000000000000000000000000007070000000000000000000000000000000000000
000000001fff88788888811100888886888888007171111111111717000000000000000000000000000000007070000000000000000000000000000000000000
00000000168888878888611100588888688885007111111111111117000444404444000000004444044440007000000000000000000000000000000000000000
00000000186888878886811100858888688858007171111111111717000444494444040000404444944440007070000000000000000000000000000000000000
00000000188668878668811100885588685588007171111111111717000000099000000000000009900000007070000000000000000000000000000000000000
00000000117886696887111100068855958860007111111111111117044440999404444004444049990444407070000000000000000000000000000000000000
00000000117788788877111100066886888660007171111111111717044440999904444004444099990444407070000000000000000000000000000000000000
000000001188777777881111000886666668800071711111111117170000009aa90000000000009aa90000007000000000000000000000000000000000000000
000000001181111111181111000800000000800071111111111111174404499aa99404444440499aa99440447070000000000000000000000000000000000000
00000000111111111111111111111111077777770000000000000000440449aaaa940444444049aaaa9440447070000000000000000000000000000000000000
000000001111111111111111111111117000000000000000000000000000099aa99000000000099aa99000007000000000000000000000000000000000000000
00000000111111111111111111111111707077070000000000000000044440999904444004444099990444407070000000000000000000000000000000000000
00000000111111111111111111111111700000000000000000000000044440455404444004444045540444407070000000000000000000000000000000000000
00000000111111111111111111111111707000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000
00000000177177177177771771771771707000000000000000000000000444404444040000404444044440007070000000000000000000000000000000000000
00000000111111111111111111111111700000000000000000000000000444404444000000004444044440007070000000000000000000000000000000000000
00000000777777777777777777777777707000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000
__gff__
0001010100040200000000010101000000000000000402000000000400000000000000000004020000000004000000000008080805000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000313232323232323232323232323232323232323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006101007080708101010070807081010100708070805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016101017181718101010171817181010101718171815000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016100708292a070810090a2728070810070827280915000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016101718393a171810191a3738171810171837381915000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016101007080708101010070807081010100708070815000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00161010171817181010101718171810101017340c0c15000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
002610101010101010101010101010101010102b101025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000010202020202020202020202020202020202020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
