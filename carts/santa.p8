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

- snow collectibles
    - provides incentive
        - replenishes snow
        - elf entity
        - huff and puff
        - reset: de-color and reset

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
    music(0)
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
  p.cam = c

  return {
    player = p,
    cam = c,
    cursor_entity = cur,
    t = 0,
    spawn_time = 300,
    elves = {},
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
  g.t += 1
  if g.t >= g.spawn_time then
    g.t = 0
    g.spawn_time = 300 + flr(rnd(200))
    add(g.elves, elf(64,64))
  end
  for i=1,#g.elves do
    g.elves[i] = elf_update(g.elves[i])
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
  --spr(39, 30, 60, 2, 2, t()%2>1)
  --spr(41, 30, 30, 2, 2, t()%2>1)
  player_draw(g.player)
  for i=1,#g.elves do
    elf_draw(g.elves[i])
  end
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
  --print(g.player.score, hcenter(tostr(g.player.score)), 4)
end

function hcenter(s)
    -- screen center minus the
      -- string length times the 
        -- pixels in a char's width,
          -- cut in half
            return 64-#s*2
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
    floor_collided = false,

    mouse_pressed = false,
    cam = nil,
    score = 0,
    label = "player",
  }
end

function palette_swap()
  pal(10,12)
  pal(9, 13)
  pal(13, 5)
  pal(12, 6)
  pal(7, 6)
  pal(8, 6)
  pal(6, 0)
  pal(15, 6)
end

-- player_update :: message -> message -> player -> player
-- note: all vectors are expressed in screen space.
function player_update(horizdir, vertdir, p)
--  if p.ammo <= 0 then
--    stop()
--  end

-- if btn(0) then
--   palette_swap()
--   return p
-- end

  assert(p.cam ~= nil)
  assert(horizdir ~= nil)
  assert(vertdir ~= nil)
  assert(p.cursor_entity ~= nil)

  -- apply gravity
  local grav = 0.15
  p.vel.y += grav
  p.vel.y = max(-p.max_vel.y, p.vel.y)
  p.vel.y = min(p.vel.y, p.max_vel.y)

  -- add floor collisions
  local prev_collide_floor = p.collide_floor
  p.collide_floor = collide_floor(p)
  if not prev_collide_floor and p.collide_floor then
    p.floor_collided = true
    cam_shake(p.cam, 8, 2)
  else
    p.floor_collided = false
  end

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

--   if btn(0) then
--     p.pos.x -= 1
--   end
--   if btn(1) then
--     p.pos.x += 1
--   end

  -- z button, then fire snowball
  --if btnp(4) then
  if stat(34) == 1 and p.ammo > 0 and not p.mouse_pressed then
    player_fire_snowball(p)
    p.mouse_pressed = true
  elseif stat(34) != 1 then
    p.mouse_pressed = false
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
  sfx(7)
end

function player_center(p)
  return p.pos.x+7, p.pos.y+9
end

function elf_center(e)
  return e.pos.x+4, e.pos.y+5
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

  local sx = (sp%16)*8
  local sy = flr(sp/16)*8
  local sw = 16
  local sh = p.floor_collided and 15 or 16
  local dx = p.pos.x
  local dy = p.pos.y
  local dw = 16
  local dh = p.floor_collided and 15 or 16

  sspr(sx, sy, sw, sh, dx, dy, dw, dh)

  --[[
  spr(
    sp,
    p.pos.x,
    p.pos.y,
    2,
    2
  )
  --]]

  --local cx, cy = player_center(p)
  --pset(cx, cy, 15)
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

--  s.vel.y += 0.15
--  if s.vel.y > .5 then
--    s.vel.y = .5
--  end
--
  s.pos.x += s.vel.x*3
  s.pos.y += s.vel.y*3

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
  if (e.t == 1) then
    local r = flr(rnd(2))
    sfx(0)
  end

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
      e.player.vel.x += v.x*2
      e.player.vel.y += v.y*2
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

    local cx, cy
    if entity.label == "player" then
     cx, cy = player_center(entity)
    elseif entity.label == "elf" then
      cx, cy = elf_center(entity)
      -- cx, cy = entity.pos.x, entity.pos.y
    end

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
function collide_wall(entity, do_not_zero)
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
    local cx, cy
    if entity.label ==  'player' then
      cx, cy = player_center(entity)
    elseif entity.label == 'elf' then
      cx, cy = elf_center(entity)
    end
    local tile = mget(
      cell_x,
      (cy+i)/8
    )

    -- if tile is a side tile,
    if fget(tile, 2) then
      -- todo: collisions with side should not zero velocity
      if do_not_zero == nil then
        if entity.vel.y == 0 then
          entity.vel.x = 0
        else
          entity.vel.x = entity.vel.x * 0.8
        end
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
function collide_wall_left(entity, do_not_zero)
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
    local cx, cy
    if entity.label ==  'player' then
      cx, cy = player_center(entity)
    elseif entity.label == 'elf' then
      cx, cy = elf_center(entity)
    end
    local tile = mget(
      cell_x,
      (cy+i)/8
    )

    -- if tile is a side tile,
    if fget(tile, 1) then
      if do_not_zero == nil then
        if entity.vel.y == 0 then
          entity.vel.x = 0
        else
          entity.vel.x = entity.vel.x * 0.8
        end
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

    shake_remaining = 0,
    shake_force = 0,
  }
end

function cam_shake(c, ticks, force)
  sfx(6)
  c.shake_remaining = ticks
  c.shake_force = force
end

function cam_update(c)
  assert(c ~= nil)
  c.shake_remaining = max(c.shake_remaining-1, 0)

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
  local rx, ry = 0, 0

  if c.shake_remaining > 0 then
    rx = rnd(c.shake_force) - c.shake_force/2
    ry = rnd(c.shake_force) - c.shake_force/2
  end

  return c.pos.x-64+rx, c.pos.y-64+ry
end

--
-- lerp util.
--

function lerp(a, b, t)
  return (1-t)*a + t*b
end

--
-- elf entity.
--

function elf(x, y)
  -- 70, 71, 72
  -- 70 is idle

  return {
    pos = vec2(x, y),
    vel = vec2(rnd() > 0.5 and 0.2 or -0.2, 0),
    t = 0,
    width = 5,
    height = 9,
    label = "elf",
  }
end

function elf_update(e)
  local grav = 0.15
  e.vel.y += grav
  e.vel.y = max(-2, e.vel.y)
  e.vel.y = min(e.vel.y, 2)

  collide_floor(e)

  local wall_collided = collide_wall(e, true)
  if wall_collided then
    e.vel.x = -e.vel.x
  end

  local wall_collided_left = collide_wall_left(e, true)
  if wall_collided_left then
    e.vel.x = -e.vel.x
  end

  e.pos.x += e.vel.x
  e.pos.y += e.vel.y
  e.t += 1
  return e
end

function elf_draw(e)
  local t = time()%1

  local should_flip = false
  if e.vel.x >= 0 then
    should_flip = true
  end

  if t>0.5 then
    spr(71, e.pos.x, e.pos.y, 1, 2, should_flip)
  else
    spr(72, e.pos.x, e.pos.y, 1, 2, should_flip)
  end
end

function particle(x, y)
  return {
    head = {
      pos = vec2(x, y),
      vel = vec2(rnd(2)-1, rnd(1)-2),
    },

    body = {
      pos = vec2(x, y),
      vel = vec2(rnd(2)-1, rnd(1)-2),
    },

    limbs = {
      -- arms
      {
        pos = vec2(x,y),
        vel = vec2(rnd(2)-1, rnd(1)-2),
      },
      {
        pos = vec2(x,y),
        vel = vec2(rnd(2)-1, rnd(1)-2),
      },

      -- legs
      {
        pos = vec2(x,y),
        vel = vec2(rnd(2)-1, rnd(1)-2),
      },
      {
        pos = vec2(x,y),
        vel = vec2(rnd(2)-1, rnd(1)-2),
      },
    },
  }
end

function particle_update(p)
  if p.head.pos.y < 13*8 then
    p.head.pos.x += p.head.vel.x
    p.head.pos.y += p.head.vel.y
  end
  if p.body.pos.y < 13*8 then
    p.body.pos.x += p.body.vel.x
    p.body.pos.y += p.body.vel.y
  end
  for i=1,#p.limbs do
    local limb = p.limbs[i]
    if p.limb.pos.y < 13*8 then
      p.limb.pos.x += p.limb.vel.x
      p.limb.pos.y += p.limb.vel.y
    end
  end
  return p
end

function particle_draw(p)
  spr(73,p.head.pos.x,p.head.pos.y)
  rectfill(p.body.pos.x,p.body.pos.y,p.body.pos.x+2,p.body.pos.y+1,8)
  for i=1,2 do
    local limb = p.limbs[i]
    pset(limb.pos.x, limb.pos.y, 3)
  end
  for i=3,4 do
    local limb = p.limbs[i]
    rectfill(limb.pos.x, limb.pos.y, limb.pos.x, limb.pos.y+1, 3)
  end
end

__gfx__
00000000777777777777777777777777000000007111111111111117dddddddddddddddddddddddddddddddd7777777777777777777777770000000000000000
00000000111111111111111111111111000000007171111111111717dddccccdccccddddddddccccdccccdddcccccccccccccccccccccccc0000000000000000
00700700177177177177771771771771000000007171111111111717dddccccdccccdcddddcdccccdccccdddc77c77c77c7777c77c77c77c0000000000000000
00077000111111111111111111111111000000007111111111111117ddddddddddddddddddddddddddddddddcccccccccccccccccccccccc0000000000000000
00077000111111111111111111111111000000007171111111111717dccccdccccdccccddccccdccccdccccdcccccccccccccccccccccccc0000000000000000
00700700111111111111111111111111000000007171111111111717dccccdccccdccccddccccdccccdccccdcccccccccccccccccccccccc0000000000000000
00000000111111111111111111111111000000007111111111111117ddddddddddddddddddddddddddddddddcccccccccccccccccccccccc0000000000000000
00000000111111111111111111111111000000007171111111111717ccdccccdccccdccccccdccccdccccdcccccccccccccccccccccccccc0000000000000000
dddddddd111171111111111111117111111111117171111111111717ccdccccdccccdccccccdccccdccccdcc7000000011117111111111111111711111111111
dddddddd111188881111111111118888111111117111111111111117dddddddddddddddddddddddddddddddd7070000011118888111111111111888811111111
dddddddd111118778111111111111877811111117171111111111717dccccdccccdccccddccccdccccdccccd7070000015511877811111111155187781111111
dddddddd155517ff71111111155117ff711111117171111111111717dccccdccccdccccddccccdccccdccccd70000000566510f0711111111566570f01111111
dddddddd56665f0f07111111566550f0f71111117171111111111717dddddddddddddddddddddddddddddddd7070000056651ffff711111115665ffff7111111
dddddddd566657ff78811111566557ff788111117171111111111717dddccccdccccdcddddcdccccdccccddd70700000566557ff78811111156657ff78811111
dddddddd566658778888111156655877888811117111111111111117dddccccdccccddddddddccccdccccddd7000000015558877888811111155587788881111
dddddddd155588778888811115588877888881117171111111111717dddddddddddddddddddddddddddddddd707000001ff888778888811118ff887788888111
111111111fff8878888881111ff88878888881117171111111111717dddddddddddddddddddddddddddddddd7070000018888878888881111f88887888888111
11111111168888878888611116888887888861117111111111111117dddccccdccccddddddddccccdccccddd7000000016888887888861111688888788886111
11111111186888878886811118688887888681117171111111111717dddcccc9ccccdcddddcdcccc9ccccddd7070000018688887888681111868888788868111
11111111188668878668811118866878866881117171111111111717ddddddd99dddddddddddddd99ddddddd7070000018866878866881111886688786688111
11111111117886696887111111788669688711117111111111111117dccccd999cdccccddccccdc999dccccd7070000011788669688711111178866968871111
11111111117788788877111111778878887711117171111111111717dccccd9999dccccddccccd9999dccccd7070000011778878887711111177887888771111
11111111118877777788111111887777778811117171111111111717dddddd9aa9dddddddddddd9aa9dddddd7000000011887777778811111188777777881111
11111111118111111118111111811111111811117111111111111117ccdcc99aa99cdccccccdc99aa99ccdcc7070000011811111111811111181111111181111
00000000144444444444444444444441d77777777777777d00000000ccdcc9aaaa9cdccccccdc9aaaa9ccdcc7070000000003300000000000000000000000000
000000001444444444444444444444417cccccccccccccc700000000ddddd99aa99dddddddddd99aa99ddddd7000000000033330000000000000000000000000
000000001444444444444444444444417c7c77c77c77c7c700000000dccccd9999dccccddccccd9999dccccd7070000000013130000000000000000000000000
000000001444444444444444444444417cccccccccccccc700000000dccccdc55cdccccddccccdc55cdccccd7070000000033330000000000000000000000000
000000001111111111111111111111117c7cccccccccc7c700000000dddddddddddddddddddddddddddddddd7000000000003330000000000000000000000000
000000001771771771777717717717717c7cccccccccc7c700000000dddccccdccccdcddddcdccccdccccddd7070000000003030000000000000000000000000
000000001111111111111111111111117cccccccccccccc700000000dddccccdccccddddddddccccdccccddd7070000000003030000000000000000000000000
000000007777777777777777777777777c7cccccccccc7c700000000dddddddddddddddddddddddddddddddd7000000000003030000000000000000000000000
11117111111111111111711111111111111111111111111111131111111311111113111111111111111111111111111111111111111111111111111111111111
11118888111111111111888811111111111555555555551111133111111331111113311111111111111111144444444444444444411111114444444444444444
11111877811111111155187781111111111555555555555111333311113333111133331111131111111111144444444444444444411111114444444444444444
15515fff71111111155557fff1111111111555555555555111737311117373111173731111131111111111144444444444444444411111114444444444444444
566550f0f711111115665f0f07111111111555555555555111333311113333111133331111133111111111111111111111111111111111111111111111111111
56655fff78811111156657ff78811111115551111111111111188811111888111118881111333311111114444444444444444444444111114444444444444444
56658877888811111566587788881111155511111111111111388831113888111118883111737311111114444444444444444444444111114444444444444444
15588877888881111855887788888111115111111111111111131311111313311133131111333311111114444444444444444444444111114444444444444444
18888878888881111f88887888888111111111111111111111131311111313111113131103300000111111111111111111111111111111111111111111111111
16888887888861111688888788886111111111111111111111111111111111111111111133330000111444444444444444444444444441114444444444444444
18688887888681111868888788868111111111111111111111111111111111111111111173730000111444444444444444444444444441114444444444444444
18866878866881111886688786688111111111111111111111111111111111111111111133330000111444444444444444444444444441114444444444444444
11788669688711111178866968871111111111111111111111111111111111111111111108880000111111111111111111111111111111111111111111111111
11778878887711111177887888771111111111111111111111111111111111111111111108883000144444444444444444444444444444414444444444444444
11887777778811111188777777881111111111111111111111111111111111111111111133030000144444444444444444444444444444414444444444444444
11811111111811111181111111181111111111111111111111111111111111111111111103030000144444444444444444444444444444414444444444444444
__gff__
00010101000402000000000101010000000000000004020000000004000000000f0000000004020000000004000000000008080805030000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000004a4b4e4f4e4f4f4f4e4f4e4f4e4f4e4f4c4d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000005a5b5e5f5e5f5f5f5e5f5e5f5e5f5e5f5c5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00004a4b4e4f4e4f4e4f4e4f4e4f4e4f4e4f4e4f4c4d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00005a5b5e5f5e5f5e5f5e5f5e5f5e5f5e5f5e5f5c5d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0020313232323232323232323232323232323232323320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006101007080708101010070807081010100708070805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016101017181718101010171817181010101718171815000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016100708292a070810090a2728070810070827280915000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016101718393a171810191a3738171810171837381915000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0016101007080708101010070807081010100708070815000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00161010171817181010101718171810340c0c35171815000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00261010101010101010101010101034340c0c35351025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0020010202020202020202020202020202020202020320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000186502d6503065031650326503265031650306502c650276501e650156500f6500b650086500665004650036500165001650186001660001600006000010000100000000000000000000000000000000
000100000f650166501965020650256502865028650216501a6501465012650166501b6501c6501c6501565013650136500000000000000000000000000000000000000000000000000000000000000000000000
000100002165021650206501f6501d6501965014650106500c6500965006650056500365002650016500165001650016500000000000000000000000000000000000000000000000000000000000000000000000
01180000300503000030053300502f0002d0002f050280002f0532f0502d000280002d050000002f0502d05000000280500000000000000000000000000000002d050000002f0532d05000000280500000000000
01180000000002b05000000000002d050000002f0532d05000000290500000000000000000000026000000002605000000280500000000000290502b050000002d0502b000000002b05026050000002805029050
011800002b0002b050000000000000000000000000000000000002d0002d0502b0002d0002b0502d0502b0002b0502d0502d0002b0502d05000000000002805000000280501c6001c60018600186000000000000
000200000a6400d6400e6400e6400e6400d6400a64009640086400864009640096400b6400d6400e6400f6400f6400e6400c6400a64008640076400664007640086400b6400d6400d6400b6400a6400a6400b640
00010000207502175021750207501e7501b750167500f750097500675003750017500270001700017000170001700017000170001700017000170002700017000170000000000000000000000000000000000000
__music__
00 03424344
00 04424344
02 05424344

