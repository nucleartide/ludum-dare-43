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
    game_draw(g)
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
  -- spr(68, 1, 1, 2, 2)
  sspr(32, 32, 16, 8, 1, 1, 32, 16)

  -- 20px
  local tens = ceil(g.player.ammo/10)
  rectfill(9, 5, 28, 8, 0)
  if g.player.ammo > 0 then
    rectfill(9, 5, 9+tens*2-1, 8, 7)
  end
--   print(g.player.collide_floor)
--   print(g.player.collide_ceil)
--   print(g.player.collide_wall)
--   print(g.player.collide_wall_left)

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
    ammo = 100,
    snowballs = {},
    explosions = {},
    radius = 6,
    cursor_entity = nil,

    collide_floor = false,
    collide_ceil = false,
    collide_wall = false,
    collide_wall_left = false,
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
  p.collide_floor = collide_floor(p)

  -- add ceiling collisions
  p.collide_ceil = collide_ceil(p)

  -- add wall collisions
  p.collide_wall = collide_wall(p)
  p.collide_wall_left = collide_wall_left(p)

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

  if btn(0) then
    p.pos.x -= 1
  end
  if btn(1) then
    p.pos.x += 1
  end

  -- z button, then fire snowball
  --if btnp(4) then
  if stat(34) == 1 and p.ammo > 0 then
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
  p.ammo -= 1
end

function player_center(p)
  return p.pos.x+7, p.pos.y+9
end

-- player_draw :: player -> io ()
function player_draw(p)
  -- 17 - neutral
  -- 19 - neutral,    facing left
  -- 28 - looking up, facing left
  -- 30 - looking up, facing right
  -- 64 - looking down, facing left
  -- 66 - looking down, facing right

  local sp = 17
  local cx, cy = cursor_world_space(p.cursor_entity)

  local is_facing_left = false
  if cx < p.pos.x then
    is_facing_left = true
  end

  local vertical_dir -- 0 for up, 1 for neutral, 2 for down
  if cy < p.pos.y-15 then
    vertical_dir = 0
  elseif cy > p.pos.y+15 then
    vertical_dir = 2
  else
    vertical_dir = 1
  end

  if is_facing_left then
    if vertical_dir == 0 then
      sp = 28
    elseif vertical_dir == 1 then
      sp = 19
    else
      sp = 64
    end
  else
    if vertical_dir == 0 then
      sp = 30
    elseif vertical_dir == 1 then
      sp = 17
    else
      sp = 66
    end
  end

  spr(
    sp,
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

  local step = entity.width / 4
  for i=-step,step,step do
    local cell_y = flr(
      (entity.pos.y+entity.height) / 8
    )

    local cx, cy = player_center(entity)

    -- screen space to map space.
    local tile = mget(
      (cx+i) / 8,
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

  local step = entity.width / 4
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
      -- todo: collisions with side should not zero velocity
      if entity.vel.y == 0 then
        entity.vel.x = 0
      else
        entity.vel.x = entity.vel.x * 0.8
      end
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
      if entity.vel.y == 0 then
        entity.vel.x = 0
      else
        entity.vel.x = entity.vel.x * 0.8
      end
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
00000000777777777777777777777777000000007111111111111117dddddddddddddddddddddddddddddddd7777777777777777777777770000000000000000
00000000111111111111111111111111000000007171111111111717dddccccdccccdddddddd4444d4444ddd0000000000000000000000000000000000000000
00700700177177177177771771771771000000007171111111111717dddccccdccccdcdddd4d4444d4444ddd0770770770777707707707700000000000000000
00077000111111111111111111111111000000007111111111111117dddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
00077000111111111111111111111111000000007171111111111717dccccdccccdccccdd4444d4444d4444d0000000000000000000000000000000000000000
00700700111111111111111111111111000000007171111111111717dccccdccccdccccdd4444d4444d4444d0000000000000000000000000000000000000000
00000000111111111111111111111111000000007111111111111117dddddddddddddddddddddddddddddddd0000000000000000000000000000000000000000
00000000111111111111111111111111000000007171111111111717ccdccccdccccdccc444d4444d4444d440000000000000000000000000000000000000000
dddddddd111171111111111111117111111111117171111111111717ccdccccdccccdccc444d4444d4444d447000000011117111111111111111711111111111
dddddddd111188881111111111118888111111117111111111111117dddddddddddddddddddddddddddddddd7070000011118888111111111111888811111111
dddddddd111118778111111111111877811111117171111111111717dccccdccccdccccdd4444d4444d4444d7070000015511877811111111155187781111111
dddddddd155517ff71111111155117ff711111117171111111111717dccccdccccdccccdd4444d4444d4444d70000000566510f0711111111566570f01111111
dddddddd56665f0f07111111566550f0f71111117171111111111717dddddddddddddddddddddddddddddddd7070000056651ffff711111115665ffff7111111
dddddddd566657ff78811111566557ff788111117171111111111717dddccccdccccdcdddd4d4444d4444ddd70700000566557ff78811111156657ff78811111
dddddddd566658778888111156655877888811117111111111111117dddccccdccccdddddddd4444d4444ddd7000000015558877888811111155587788881111
dddddddd155588778888811115588877888881117171111111111717dddddddddddddddddddddddddddddddd707000001ff888778888811118ff887788888111
000000001fff8878888881111ff88878888881117171111111111717000000000000000000000000000000007070000018888878888881111f88887888888111
00000000168888878888611116888887888861117111111111111117000444404444000000004444044440007000000016888887888861111688888788886111
00000000186888878886811118688887888681117171111111111717000444494444040000404444944440007070000018688887888681111868888788868111
00000000188668878668811118866878866881117171111111111717000000099000000000000009900000007070000018866878866881111886688786688111
00000000117886696887111111788669688711117111111111111117044440999404444004444049990444407070000011788669688711111178866968871111
00000000117788788877111111778878887711117171111111111717044440999904444004444099990444407070000011778878887711111177887888771111
000000001188777777881111118877777788111171711111111117170000009aa90000000000009aa90000007000000011887777778811111188777777881111
000000001181111111181111118111111118111171111111111111174404499aa99404444440499aa99440447070000011811111111811111181111111181111
00000000111111111111111111111111177777777777777100000000440449aaaa940444444049aaaa9440447070000000000000000000000000000000000000
000000001111111111111111111111117cccccccccccccc7000000000000099aa99000000000099aa99000007000000000000000000000000000000000000000
000000001111111111111111111111117c7c77c77c77c7c700000000044440999904444004444099990444407070000000000000000000000000000000000000
000000001111111111111111111111117cccccccccccccc700000000044440455404444004444045540444407070000000000000000000000000000000000000
000000001111111111111111111111117c7cccccccccc7c700000000000000000000000000000000000000007000000000000000000000000000000000000000
000000001771771771777717717717717c7cccccccccc7c700000000000444404444040000404444044440007070000000000000000000000000000000000000
000000001111111111111111111111117cccccccccccccc700000000000444404444000000004444044440007070000000000000000000000000000000000000
000000007777777777777777777777777c7cccccccccc7c700000000000000000000000000000000000000007000000000000000000000000000000000000000
11117111111111111111711111111111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11118888111111111111888811111111111555555555551100000000000000000000000000000000000000000000000000000000000000000000000000000000
11111877811111111155187781111111111555555555555100000000000000000000000000000000000000000000000000000000000000000000000000000000
15515fff71111111155557fff1111111111555555555555100000000000000000000000000000000000000000000000000000000000000000000000000000000
566550f0f711111115665f0f07111111111555555555555100000000000000000000000000000000000000000000000000000000000000000000000000000000
56655fff78811111156657ff78811111115551111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
56658877888811111566587788881111155511111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
15588877888881111855887788888111115111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
18888878888881111f88887888888111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
16888887888861111688888788886111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
18688887888681111868888788868111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
18866878866881111886688786688111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11788669688711111178866968871111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11778878887711111177887888771111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11887777778811111188777777881111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
11811111111811111181111111181111111111111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0001010100040200000000010101000000000000000402000000000400000000000000000004020000000004000000000008080805030000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00161010171817181010101718171810340c0c35171815000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00261010101010101010101010101034340c0c35351025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000010202020202020202020202020202020202020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
