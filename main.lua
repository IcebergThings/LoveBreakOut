local screen_width = 400
local screen_height = 500
local radius = 10
local pad_radius = 45

local scalex = 1
local scaley = 1

local total_bricks_x = 10
local total_bricks_y = 10
local brick_width = screen_width / total_bricks_x
local brick_height = screen_height / 2 / total_bricks_y

local particles = require "particles"

function get_time_scale(dt)
  return dt * 60.0
end

-- main program
function init()
  -- scaling
  mobile = love.system.getOS() == 'iOS' or love.system.getOS() == 'Android'
  scalex = love.graphics.getWidth() / 400
  scaley = love.graphics.getHeight() / 500

  screen_width = 400 * scalex
  screen_height = 500 * scaley
  radius = 10 * scalex
  pad_radius = 45 * scalex

  total_bricks_x = 10
  total_bricks_y = 10
  brick_width = screen_width / total_bricks_x
  brick_height = screen_height / 2 / total_bricks_y

  score = 0
  score_animate = 0

  xb, yb, x0, vxb, vyb, vp = screen_width / 2, screen_height * 0.66, screen_width / 2, 4 * scalex, -4 * scalex, 0
  dead = false
  hit_power = 2
  hardness,hardness_animation = 4, 0
  time = 0
  shakeMagnitude = 0.0

  paused = false

  -- create brick map
  --  value 0..4, 0 is knocked out, 1~4 is different points
  map = {}
  for i=0,total_bricks_x-1 do
    map[i] = {}
    for j=0,total_bricks_y-1 do
      map[i][j] = love.math.random(1,4)
    end
  end
  for j=0,12 do
    map[love.math.random(0,total_bricks_x-1)][love.math.random(0,total_bricks_y-1)] = 5
  end
end

function change_hardness(h)
  hardness_animation = 255
  hardness = hardness + h
end

function love.load()
  love.window.setMode(screen_width, screen_height, {resizable = false, msaa = 4})

  -- load blocky font and use "nearest" to make it super blocky
  font = love.graphics.newImageFont("blockfont.png",
      " abcdefghijklmnopqrstuvwxyz" ..
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
      "123456789.,!?-+/():;%&`'*#=[]\"")
  font:setFilter("nearest", "nearest")
  love.graphics.setFont(font)

  particles_hit = particles.new(84, 255, 221, 255, 6 * scalex)
  particles_brick = particles.new(80, 115, 240, 200, 5 * scalex)

  init()
end

-- Key release
function love.keypressed(key, unicode)
  if not dead then
    if key == "escape" then
      paused = not paused
    end
  end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  if dead then
    init()
  end
end

-- Increase the size of the rectangle every frame.
function love.update(dt)
  -- Reject extreme case (lower than 5fps), prevent bugs
  if dt > 0.2 then
    return
  end

  local sqrt = math.sqrt
  local ts = get_time_scale(dt)
  time = time + dt

  if (not dead) and (not love.window.hasFocus()) then
    paused = true
  end

  if not paused then
    particles_hit.update(ts)
    particles_brick.update(ts)

    shakeMagnitude = shakeMagnitude * 0.7

    if not dead then
      -- Reflect velocity on edge
      if (xb <= radius) or (xb >= screen_width - radius) then
        xb = math.min(math.max(xb, radius), screen_width - radius)
        vxb = -vxb
        hit_power = 2
      end
      if (yb <= radius) or (yb >= screen_height - radius) then
        yb = math.min(math.max(yb, radius), screen_height - radius)
        vyb = -vyb
        hit_power = 2
      end
      -- Bounce back from pad
      radius_diff = sqrt((xb - x0) * (xb - x0) + (yb - screen_height - 10 * scalex) * (yb - screen_height - 10 * scalex)) - pad_radius - radius
      if radius_diff <= 0 then
        local mag = sqrt(vxb * vxb + vyb * vyb)
        xb = xb + radius_diff * vxb / mag
        yb = yb + radius_diff * vyb / mag

        local nx = xb - x0
        local ny = yb - screen_height - 10 * scalex
        nx = nx / sqrt(nx * nx + ny * ny)
        ny = ny / sqrt(nx * nx + ny * ny)

        local incident_angle = nx * vxb + ny * vyb
        vxb = vxb - 2 * incident_angle * nx
        vyb = vyb - 2 * incident_angle * ny

        vxb = vxb / sqrt(vxb * vxb + vyb * vyb) * mag
        vyb = vyb / sqrt(vxb * vxb + vyb * vyb) * mag

        change_hardness(1)
      end
      -- Death check
      if yb >= screen_height - radius then
        particles_hit.emit(xb,yb,-vxb,vyb,30, sqrt(vxb*vxb + vyb*vyb), 15)
        change_hardness(-3)
        if hardness <= 0 then
          dead = true
          paused = false
        end
      end
      -- Update position using velocity
      xb = xb + vxb * ts
      yb = yb + vyb * ts

      particles_jet = math.floor(sqrt(vxb * vxb + vyb * vyb) * 0.1 + math.sin(time * 60.0) * 0.5 + 0.5)
      particles_hit.emit(xb,yb,-vxb * 0.1,-vyb * 0.1,20, sqrt(vxb*vxb + vyb*vyb) * 0.3, particles_jet)

      -- Check block knocked
      -- This is very crude, but it works
      for i=0,total_bricks_x-1 do
        for j=0,total_bricks_y-1 do
          if map[i][j] > 0 then
            local xbrick = i * brick_width
            local ybrick = j * brick_height
            -- collide on y (horizontal face)
            if (xb > xbrick) and (xb < xbrick + brick_width) and (math.abs(yb - ybrick) < radius or math.abs(yb - ybrick - brick_height) < radius) then
              score = score + map[i][j]
              if map[i][j] == 5 then
                map[i][j] = 0
                vxb = vxb * 0.85
                vyb = vyb * 0.85
              else
                map[i][j] = math.max(map[i][j] - hit_power, 0)
                vxb = vxb * 1.01
                vyb = vyb * 1.01
              end
              hit_power = hit_power + 1
              shakeMagnitude = hit_power / 2
              score_animate = 255

              particles_brick.emit(xb,yb,-vxb,-vyb,30, sqrt(vxb*vxb + vyb*vyb), 15)
              -- reflect
              vyb = -vyb
            end
            -- collide on x (verticle surface)
            if (yb > ybrick) and (yb < ybrick + brick_height) and (math.abs(xb - xbrick) < radius or math.abs(xb - xbrick - brick_width) < radius) then
              score = score + map[i][j]
              if map[i][j] == 5 then
                map[i][j] = 0
                vxb = vxb * 0.85
                vyb = vyb * 0.85
              else
                map[i][j] = math.max(map[i][j] - hit_power, 0)
                vxb = vxb * 1.01
                vyb = vyb * 1.01
              end
              hit_power = hit_power + 1
              shakeMagnitude = hit_power / 2
              score_animate = 255
              particles_brick.emit(xb,yb,-vxb,-vyb,30, sqrt(vxb*vxb + vyb*vyb), 15)
              vxb = -vxb
            end
          end
        end
      end

      -- Keyboard control the pad
      --  detect touch screen
      local touches = love.touch.getTouches()
      local left,touch = false, false
      for i, id in ipairs(touches) do
        local x, y = love.touch.getPosition(id)
        left = x < screen_width / 2
        touch = true
      end

      if love.keyboard.isDown("left") or (touch and left) then
        vp = math.max(vp - 1.75 * scalex, -7.5 * scalex)
      elseif love.keyboard.isDown("right") or (touch and not left) then
        vp = math.min(vp + 1.75 * scalex, 7.5 * scalex)
      else
        vp = vp * 0.7
      end
      x0 = x0 + vp * ts;
      -- Limit the pad to edge
      x0 = math.min(math.max(x0, -5), screen_width + 5)

      -- Decrease
      score_animate = math.max(score_animate - 4, 0)
      hardness_animation = math.max(hardness_animation - 8, 0)
    else
      -- restart
      if love.keyboard.isDown("r") or love.keyboard.isDown("R") then
        init()
      end
    end

  end
end

function love.draw()
  local gprint = love.graphics.print

  love.graphics.clear(8, 25, 22)

  -- draw FPS
  love.graphics.setColor(255, 255, 255)
  gprint("FPS " .. love.timer.getFPS(), screen_width - 56, screen_height - 18)

  -- shake screen effect
  if shakeMagnitude > 0.1 then
    local dx = love.math.random(-shakeMagnitude, shakeMagnitude) * scalex
    local dy = love.math.random(-shakeMagnitude, shakeMagnitude) * scalex
    love.graphics.translate(dx, dy)
  end

  -- Draw a coloured rectangle.
  love.graphics.setColor(255, 84, 101)
  love.graphics.circle("fill", x0, screen_height + 10, pad_radius, 32)

  -- draw map
  for i=0,total_bricks_x-1 do
    for j=0,total_bricks_y-1 do
      if map[i][j] > 0 then
        val = map[i][j]
        if val == 5 then
          rand = (i + j * total_bricks_x) * 16.0
          love.graphics.setColor((math.sin(time * 3.0 + rand) * 0.4 + 0.6) * 255,(math.cos(time * 3.0 + rand) * 0.4 + 0.6) * 255,255)
        else
          love.graphics.setColor(80 * (1 - val * 0.05), 115 * (1 - val * 0.05), 240 * (1 - val * 0.05))
        end
        love.graphics.rectangle("fill", i * brick_width, j * brick_height, brick_width, brick_height)
      end
    end
  end

  -- draw ball
  love.graphics.setColor(84, 255, 221)
  love.graphics.circle("fill", xb, yb, radius, 16)

  particles_hit.draw()
  particles_brick.draw()

  if paused then
    love.graphics.setColor((math.sin(time * 3.5) * 0.4 + 0.6) * 255,255,(math.cos(time * 3.5) * 0.4 + 0.6) * 255)
    scale = (2.0 * (math.sin(time * 10.0) * 0.05 + 1.0)) * scalex
    gprint("Paused. ESC to cancel", 10 * scalex, 10 * scalex + 40 * scale, 0, scale, scale)
  end

  if dead then
    love.graphics.setColor(255, 84, 60, 255)
    scale = (math.sin(time * 10.0) * 0.1 + 1.0) * scalex
    gprint("Boom, you are DEAD", 10 * scalex, 10 * scalex, 0, 2 * scale, 2 * scale)
    if mobile then
      gprint("Touch anyplace to restart", 10 * scalex, 10 * scalex + 40 * scale, 0, scale, scale)
    else
      gprint("Press R or touch anyplace to restart", 10 * scalex, 10 * scalex + 40 * scale, 0, scale, scale)
    end

    -- draw score total
    love.graphics.setColor(255, 255, 255, 255)
    score_line = "Score " .. score
    gprint(score_line, screen_width / 2 - string.len(score_line) * 19 * scale, 200 * scalex, 0, 4 * scale, 4 * scale)
  else
    -- draw score
    love.graphics.setColor(255, 255, 255, score_animate)
    gprint(score, 10 * scalex, 10 * scalex, 0, 4 * scalex, 4 * scalex)
    love.graphics.setColor(255, 255, 255, hardness_animation)
    gprint("Hardness " .. hardness, 10 * scalex, 60 * scalex, 0, 2 * scalex, 2 * scalex)
  end
end
