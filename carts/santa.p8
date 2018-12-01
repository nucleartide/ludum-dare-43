pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- santa's workshop
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
λλ ]]

function game()
  return {
    player = player(64, 64, 4, 4),
  }
end

-- λ game_update :: Message -> Game -> Game
-- λ game_update = undefined
function game_update(msg, g)
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
    width = w,
    height = h,
  }
end

-- player_update :: Message -> Player -> Player
function player_update(msg, p)
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
end
