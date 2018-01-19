particles = {}

function particles.new(r,g,b,a,size)

  local self = {}

  self.r = r or 255
  self.g = g or 255
  self.b = b or 255
  self.a = a or 255
  self.size = size
  self.particles = {}

  local random = love.math.random

  self.emit_single = function(x,y,vx,vy,l)
    table.insert(self.particles, {x=x,y=y,size=0.5+random(),vx=vx,vy=vy,life=l})
  end

  self.emit = function(x,y,vx,vy,l,r,c)
    for i=1,c do
      self.emit_single(x,y,vx + r * (random() - 0.5),vy + r * (random() - 0.5),l)
    end
  end

  self.update = function(ts)
    for i,p in ipairs(self.particles) do
      p.life = p.life - 1
      if p.life <= 0 then
        table.remove(self.particles, i)
      else
        p.x = p.x + p.vx * ts
        p.y = p.y + p.vy * ts
      end
    end
  end

  self.draw = function()
    local rect = love.graphics.rectangle
    love.graphics.setColor(self.r, self.g, self.b, self.a)
    for i,p in ipairs(self.particles) do
      rect("fill", p.x - 2, p.y - 2, p.size * self.size, p.size * self.size)
    end
  end

  return self
end

return particles
