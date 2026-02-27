local GameScene = require("scene.game_scene")

local scene

function love.load()
  scene = GameScene.new()
  scene:load()
end

function love.update(dt)
  scene:update(dt)
end

function love.draw()
  scene:draw()
end

function love.mousepressed(x, y, button)
  scene:mousepressed(x, y, button)
end

function love.keypressed(key)
  scene:keypressed(key)
end

function love.textinput(text)
  if scene.textinput then
    scene:textinput(text)
  end
end
