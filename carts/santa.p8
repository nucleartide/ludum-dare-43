pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--
-- game loop.
--

do
  function _update60()
  end

  function _draw()
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

-- λ update :: Message -> Game -> Game
function update(msg, game)
  return {}
end

-- λ draw :: Game -> IO ()
function draw()
end
