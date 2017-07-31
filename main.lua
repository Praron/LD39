require('libs/autobatch')
local F = require('libs/moses')
local L = require('libs/lume')
local random
random = L.random
local Object = require('libs/classic')
local Timer = require('libs/timer')
local Input = require('libs/boipushy')
local GameState = require('libs/gamestate')
local ECS = require('libs/tiny_ecs')
local Vector = require('libs/vector')
local Bump = require('libs/bump')
local DebugGraph = require('libs/debug_graph')
local BumpDebug = require('libs/bump_debug')
local Observer = require('libs/talkback')
local Shake = require('libs/shack')
local Utils = require('libs/utils')
local Microphone = require('libs/love-microphone')
local Anim8 = require('libs/anim8')
local Talk = Observer.new()
local lg, lm, la
do
  local _obj_0 = love
  lg, lm, la = _obj_0.graphics, _obj_0.math, _obj_0.audio
end
setmetatable(_G, {
  __index = require('libs/cargo').init({
    dir = 'assets',
    processors = {
      ['images/'] = function(image, file_name)
        return image:setFilter('nearest')
      end
    }
  })
})
DEBUG = false
SCREEN_X0 = 0
SCREEN_Y0 = 0
SCREEN_W = 256
SCREEN_H = 256
GAME_RUNNING = false
SPLASH_SCREEN = 1
ZOOM_SCALE = 3
local WHITE = {
  255,
  255,
  255
}
local LIGHT_GRAY = {
  203,
  219,
  252
}
local LIGHT_BLUE = {
  95,
  205,
  228
}
local DEBUG_RED = {
  255,
  150,
  150
}
local GREEN = {
  106,
  190,
  48
}
local RED = {
  172,
  50,
  50
}
local DARK_BLUE = {
  34,
  32,
  52
}
local ORANGE = {
  223,
  113,
  38
}
local DARK_PINK = {
  217,
  87,
  99
}
local BLACK = {
  0,
  0,
  0
}
local tableToArray
tableToArray = function(t)
  local _accum_0 = { }
  local _len_0 = 1
  for k, v in pairs(t) do
    _accum_0[_len_0] = v
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
local getCenterPosition
getCenterPosition = function()
  return Vector(SCREEN_W / 2, SCREEN_H / 2)
end
local getMousePosition
getMousePosition = function()
  return Vector(love.mouse.getX() / ZOOM_SCALE, love.mouse.getY() / ZOOM_SCALE)
end
local setRandomVolume
setRandomVolume = function()
  la.setVolume(random(0.3, 1))
  if mute_sound then
    return la.setVolume(0)
  end
end
energy = 0
windmill_price = 10
human_price = 10
time_to_next_tax = 20
next_tax_time = 15
next_tax_cost = 2
windmill_count = 0
human_count = 0
game_over = false
mute_sound = false
current_sh_button = 's'
local Entity
Entity = function(components)
  for i = 1, #components do
    local component = components[i]
    components[component] = true
    components[i] = nil
  end
  components.new = function(self, t)
    if t == nil then
      t = { }
    end
    local entity = Utils.deepCopy(self)
    for k, v in pairs(t) do
      entity[k] = v
    end
    for i = 1, #t do
      local component = t[i]
      entity[component] = true
      entity[i] = nil
    end
    return entity
  end
  setmetatable(components, {
    __call = function(self, t)
      return self:new(t)
    end
  })
  components.timer = Timer()
  components.existing_time = 0
  components.getCenter = function(self)
    if self.bounding_box then
      return self.position + Vector(self.bounding_box.w / 2, self.bounding_box.h / 2)
    else
      return self.position:clone()
    end
  end
  return components
end
peak_amplitude = 0
local Windmill = Entity({
  'windmill',
  position = getCenterPosition(),
  blades_speed = 0,
  blades_rotation = 0,
  size = 32,
  draw = function(self)
    lg.setColor(WHITE)
    lg.polygon('fill', self.position.x, self.position.y, self.position.x - self.size / 10, self.position.y, self.position.x - self.size / 20, self.position.y - self.size, self.position.x + self.size / 20, self.position.y - self.size, self.position.x + self.size / 10, self.position.y)
    lg.circle('fill', self.position.x, self.position.y - self.size - 2, 2)
    for i = 1, 3 do
      local p1 = Vector(self.position.x, self.position.y - self.size - 2)
      local p2 = p1 + (Vector(self.size * 0.8, 0)):rotated((2 * math.pi / 3 * i + self.blades_rotation))
      local p3 = p1 + (Vector(self.size * 0.3, -5 * self.size / 32)):rotated((2 * math.pi / 3 * i + self.blades_rotation))
      lg.polygon('fill', p1.x, p1.y, p2.x, p2.y, p3.x, p3.y)
    end
  end
})
local ExplotionParticle = Entity({
  'particle',
  'die_on_stop',
  position = getCenterPosition(),
  velocity = Vector(100, 0),
  acceleration = -10,
  draw = function(self)
    lg.setColor(RED)
    return lg.circle('fill', self.position.x, self.position.y, 2)
  end
})
local Alien = Entity({
  'alien',
  position = Vector(SCREEN_W / 2 - images.alien:getWidth() / 3 / 2, -51),
  animation = {
    sheet = images.alien,
    number_of_frames = 3,
    duration = 100000000
  },
  draw = function(self)
    lg.setColor(WHITE)
    return self.animation.animation:draw(images.alien, self.position.x, self.position.y)
  end
})
local Ray = Entity({
  'ray',
  bounding_box = {
    w = images.ray:getWidth(),
    h = images.ray:getHeight()
  },
  position = getCenterPosition(),
  life_time = 2,
  draw = function(self)
    lg.setColor(WHITE)
    lg.draw(images.ray, self.position.x, self.position.y)
    return Shake:setShake(2)
  end
})
local addExplosion
addExplosion = function(world, position)
  Shake:setShake(20)
  for _ = 1, 16 do
    world:addEntity(ExplotionParticle({
      position = position,
      velocity = ExplotionParticle.velocity:rotated(random(2 * math.pi)) * random(1, 2)
    }))
  end
end
local Human = Entity({
  'human',
  position = getCenterPosition(),
  bounding_box = {
    w = images.human:getWidth() + 3,
    h = images.human:getHeight() + 3
  },
  velocity = Vector(32, 0),
  speed = 32,
  animation = {
    sheet = images.human_walk,
    number_of_frames = 7,
    duration = 0.1
  },
  draw = function(self)
    lg.setColor(WHITE)
    self.animation.animation:flipH(self.velocity.x < 0)
    return self.animation.animation:draw(images.human_walk, self.position.x, self.position.y)
  end,
  is_jumping = false,
  jump = function(self)
    self.is_jumping = true
    self.position.y = self.position.y - 3
    self.velocity.y = -200
    self.acceleration = Vector(0, 200)
    if (random(1)) < 0.3 then
      return self:say(L.randomChoice({
        'We-e-e!',
        'I have fear of heights!',
        'Humans looks like ant from there'
      }))
    end
  end,
  explode = function(self)
    self.died = true
  end,
  rotate = function(self)
    self.velocity.x = self.velocity.x * -1
    if (random(1)) < 0.4 then
      return self:say(L.randomChoice({
        'Stop clicking on me!',
        "Don't click on us",
        'Please, stop',
        "That's annoying"
      }))
    end
  end,
  say = function(self, text)
    setRandomVolume()
    la.play(sound.say)
    if self.text_to_say_time then
      self.text_to_say_timer:cancel()
    end
    self.text_to_say = text
    self.text_to_say_timer = self.timer:after(2, function()
      self.text_to_say = nil
      self.text_to_say_timer = nil
    end)
  end
})
local WindmillButton = Entity({
  'button',
  'windmill_button',
  position = Vector(10, ZOOM_SCALE * SCREEN_H - 150),
  bounding_box = {
    w = 300,
    h = 35
  },
  draw = function(self)
    local cache_font = lg.getFont()
    lg.setFont(lg.newFont(20))
    lg.setColor(DARK_BLUE)
    if energy >= windmill_price then
      lg.setColor(WHITE)
    end
    lg.setLineWidth(3)
    lg.rectangle('line', self.position.x, self.position.y, self.bounding_box.w, self.bounding_box.h)
    lg.setLineWidth(1)
    lg.print('[Z] Buy windmill (' .. windmill_price .. ' energy)', self.position.x + 5, self.position.y + 5)
    return lg.setFont(cache_font)
  end
})
local HumanlButton = Entity({
  'button',
  'human_button',
  position = Vector(10, ZOOM_SCALE * SCREEN_H - 100),
  bounding_box = {
    w = 300,
    h = 35
  },
  draw = function(self)
    local cache_font = lg.getFont()
    lg.setFont(lg.newFont(20))
    lg.setColor(DARK_BLUE)
    if energy >= human_price then
      lg.setColor(WHITE)
    end
    lg.setLineWidth(3)
    lg.rectangle('line', self.position.x, self.position.y, self.bounding_box.w, self.bounding_box.h)
    lg.print('[X] Buy human (' .. human_price .. ' energy)', self.position.x + 10, self.position.y + 5)
    return lg.setFont(cache_font)
  end
})
local systems = { }
local processingSystem, requireAll, requireAny
processingSystem, requireAll, requireAny = ECS.processingSystem, ECS.requireAll, ECS.requireAny
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('animation')
  _with_0.onAdd = function(self, e)
    local img = e.animation.sheet
    local grid = Anim8.newGrid(img:getWidth() / e.animation.number_of_frames, img:getHeight(), img:getWidth(), img:getHeight())
    e.animation.animation = Anim8.newAnimation((grid("1-" .. tostring(e.animation.number_of_frames), 1)), e.animation.duration)
  end
  _with_0.process = function(self, e, dt)
    return e.animation.animation:update(dt)
  end
  systems.animation_manager = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('blades_rotation')
  _with_0.process = function(self, e, dt)
    e.blades_speed = e.blades_speed + (peak_amplitude * dt * 5)
    e.blades_rotation = e.blades_rotation + e.blades_speed
    e.blades_speed = e.blades_speed - (e.blades_speed * dt)
    if e.blades_speed < 0.02 then
      e.blades_speed = 0
    end
    if e.blades_speed > 0.8 then
      setRandomVolume()
      return la.play(sound.wind)
    end
  end
  systems.blades_rotation = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('life_time')
  _with_0.process = function(self, e, dt)
    e.life_time = e.life_time - dt
    if e.life_time < 0 then
      return world:removeEntity(e)
    end
  end
  systems.life_time = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('position', 'velocity')
  _with_0.process = function(self, e, dt)
    e.position = e.position + (e.velocity * dt)
    if type(e.acceleration) == 'table' then
      e.velocity = e.velocity + (e.acceleration * dt)
    end
    if type(e.acceleration) == 'number' then
      e.velocity = e.velocity + (e.velocity * e.acceleration * dt)
    end
    if e.max_speed then
      return e.velocity:trimInplace(e.max_speed)
    end
  end
  systems.moving_system = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('human', 'position')
  _with_0.process = function(self, e)
    if e.position.x < 5 then
      e.velocity.x = e.speed
    end
    if e.position.x > SCREEN_W - 5 then
      e.velocity.x = -e.speed
    end
    if e.position.y > 160 then
      e.is_jumping = false
      e.position.y = 160
      e.acceleration = nil
      e.velocity.y = 0
    end
    if e.position.y < -40 then
      return e:explode()
    end
  end
  systems.human_moving_system = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('windmill')
  _with_0.process = function(self, e, dt)
    energy = energy + (e.blades_speed * dt)
  end
  systems.energy_manager = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = ECS.requireAll('die_on_stop', 'velocity')
  _with_0.process = function(self, e)
    if e.velocity:len2() < .1 then
      return self.world:removeEntity(e)
    end
  end
  systems.die_on_stop = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('position', 'bounding_box')
  _with_0.onAdd = function(self, e)
    return collider:add(e, e.position.x, e.position.y, e.bounding_box.w, e.bounding_box.h)
  end
  _with_0.onRemove = function(self, e)
    return collider:remove(e)
  end
  _with_0.process = function(self, e)
    return collider:update(e, e.position.x, e.position.y)
  end
  systems.collider = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('human')
  _with_0.process = function(self, e)
    local _list_0 = collider:getCollisions(e)
    for _index_0 = 1, #_list_0 do
      local c = _list_0[_index_0]
      if c.other.ray then
        e.acceleration = Vector(0, -100)
        if not e.raised then
          e:say(L.randomChoice({
            "Al Gore, you've doomed us all",
            "Oh no",
            "Yay, I will die!",
            ":c"
          }))
        end
        e.raised = true
      end
    end
  end
  systems.human_ray_collider = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAny('explode')
  _with_0.process = function(self, e)
    if e.died then
      addExplosion(self.world, e.position:clone():moveInplace(3, 3))
      self.world:removeEntity(e)
      if not e.raised then
        return addRandomHuman(self.world)
      end
    end
  end
  systems.died_manager = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('windmill')
  _with_0.onAdd = function()
    windmill_count = windmill_count + 1
  end
  _with_0.onRemove = function()
    windmill_count = windmill_count - 1
  end
  systems.windmill_count = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('human')
  _with_0.onAdd = function()
    human_count = human_count + 1
  end
  _with_0.onRemove = function()
    human_count = human_count - 1
    if human_count == 0 then
      game_over = true
    end
  end
  systems.human_count = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAny('alien')
  _with_0.process = function(self, e, dt)
    time_to_next_tax = time_to_next_tax - dt
    if time_to_next_tax < 0 and not game_over then
      time_to_next_tax = next_tax_time
      e.animation.animation:gotoFrame(1)
      e.timer:tween(1, e.position, {
        y = -16
      }, 'out-quad')
      setRandomVolume()
      la.play(sound.question)
      return e.timer:after(2, function()
        setRandomVolume()
        if energy >= next_tax_cost then
          energy = energy - next_tax_cost
          next_tax_cost = next_tax_cost * 1.5
          e.animation.animation:gotoFrame(2)
          la.play(sound.success)
        else
          la.play(sound.fail)
          e.animation.animation:gotoFrame(3)
          e.timer:after(2, function()
            addRandomRay(self.world)
            return la.play(sound.ray)
          end)
        end
        return e.timer:after(1, function()
          return e.timer:tween(1, e.position, {
            y = -50
          }, 'in-linear')
        end)
      end)
    end
  end
  systems.alien = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('say')
  _with_0.process = function(self, e, dt)
    if not e.time_to_next_phrase then
      e.time_to_next_phrase = random(5, 25)
    end
    e.time_to_next_phrase = e.time_to_next_phrase - dt
    if e.time_to_next_phrase < 0 then
      e.time_to_next_phrase = random(5, 25)
      return e:say(L.randomChoice({
        'I want a donut',
        'This party stinks',
        'Ludum Dare is cool!',
        "I don't want to die",
        ':D',
        'I am tired',
        '-1',
        'Oh no',
        "I'm a tiny human",
        'Our lives are just meaningless',
        'I like cats!',
        "Don't click on us, please",
        'I like green ice cream',
        'Very fun activity, yeah',
        'Rate us!',
        'Arrow is in my knee',
        "I don't sleep for 48 hours",
        "I don't believe in cheese",
        'The Earth is flat!',
        'MoonScript is very cool!',
        "We're so small",
        'LOVE is very cool!',
        'Mondays sucks',
        'Click me!',
        "Trust me, I'm a dolphin",
        "I'm a anime girl!",
        '!$%@}&#|*',
        "Our world doesn't real",
        "Mom, look at me, I'm in the game!",
        'I love Ludum Dare!',
        'Special for LD39',
        'Save us from existing',
        'This plot is stupid',
        'Longcat is long'
      }))
    end
  end
  systems.random_saying = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.filter = requireAll('timer')
  _with_0.process = function(self, e, dt)
    return e.timer:update(dt)
  end
  systems.timer_manager = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.draw_system = true
  _with_0.filter = requireAll('draw')
  _with_0.process = function(self, e)
    return e:draw()
  end
  systems.draw = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.draw_system = true
  _with_0.text_system = true
  _with_0.filter = requireAll('draw', 'button')
  _with_0.process = function(self, e)
    return e:draw()
  end
  systems.draw_buttons = _with_0
end
do
  local _with_0 = processingSystem()
  _with_0.draw_system = true
  _with_0.text_system = true
  _with_0.filter = requireAll('text_to_say')
  _with_0.process = function(self, e)
    if e.text_to_say then
      local cache_font = lg.getFont()
      lg.setFont(lg.newFont(24))
      lg.setColor(BLACK)
      lg.print(e.text_to_say, ZOOM_SCALE * (e.position.x - e.text_to_say:len() / 2 * 3), ZOOM_SCALE * (e.position.y - 10))
      return lg.setFont(cache_font)
    end
  end
  systems.text_bubbles = _with_0
end
local fps_graph, mem_graph, entity_graph, collider_graph
local intiDebugGraphs
intiDebugGraphs = function()
  fps_graph = DebugGraph:new('fps', 0, 0, 30, 50, 0.2, 'fps', lg.newFont(16))
  mem_graph = DebugGraph:new('mem', 0, 50, 30, 50, 0.2, 'mem', lg.newFont(16))
  entity_graph = DebugGraph:new('custom', 0, 100, 30, 50, 0.3, 'ent', lg.newFont(16))
end
local updateDebugGraphs
updateDebugGraphs = function(dt, world)
  fps_graph:update(dt)
  mem_graph:update(dt)
  entity_graph:update(dt, world:getEntityCount())
  entity_graph.label = 'Entities: ' .. world:getEntityCount()
  if input:pressed('toggle_debug') then
    DEBUG = L.toggle(DEBUG)
  end
  if input:pressed('collect_garbage') then
    return collectgarbage('collect')
  end
end
local drawDebugGraphs
drawDebugGraphs = function()
  lg.setColor(WHITE)
  fps_graph:draw()
  mem_graph:draw()
  return entity_graph:draw()
end
local drawColliderDebug
drawColliderDebug = function(collider)
  BumpDebug.draw(collider)
  lg.setColor(DEBUG_RED)
  local items = collider:getItems()
  local _list_0 = items
  for _index_0 = 1, #_list_0 do
    local i = _list_0[_index_0]
    lg.rectangle('line', collider:getRect(i))
  end
end
local initInput
initInput = function()
  local input
  do
    local _with_0 = Input()
    _with_0:bind('z', 'make_random_windmill')
    _with_0:bind('x', 'make_random_human')
    _with_0:bind('1', 'get_energy')
    _with_0:bind('mouse1', 'left_click')
    _with_0:bind('mouse2', 'right_click')
    _with_0:bind('f1', 'toggle_debug')
    _with_0:bind('f2', 'collect_garbage')
    _with_0:bind('escape', 'exit')
    _with_0:bind('m', 'toggle_mute')
    _with_0:bind('s', 's')
    _with_0:bind('h', 'h')
    _with_0:bind('space', 'next_screen')
    _with_0:bind('mouse1', 'next_screen')
    input = _with_0
  end
  return input
end
local getPeakAmplitude
getPeakAmplitude = function(data)
  local peak_amp = -math.huge
  for t = 0, data:getSampleCount() - 1 do
    local amp = math.abs(data:getSample(t))
    peak_amp = math.max(peak_amp, amp)
  end
  return peak_amp
end
local initMicrophone
initMicrophone = function()
  print('Opening microphone:', Microphone.getDefaultDeviceName())
  local device = Microphone.openDevice(nil, nil, 0.1)
  local source = Microphone.newQueueableSource()
  device:setDataCallback(function(device, data)
    peak_amplitude = getPeakAmplitude(data)
  end)
  device:start()
  return device, source
end
local addRandomWindmill
addRandomWindmill = function(world)
  local y = random(1, 25)
  local v = Vector((random(10, SCREEN_W - 10)), 170 - y)
  return world:addEntity(Windmill({
    position = v,
    size = 32 - y
  }))
end
addRandomRay = function(world)
  return world:addEntity(Ray({
    position = Vector((random(0, SCREEN_W - images.ray:getWidth())), 0)
  }))
end
addRandomHuman = function(world)
  local speed = random(20, 40)
  local sign = 0
  if (random(1)) > 0.5 then
    sign = 1
  else
    sign = -1
  end
  local h = world:addEntity(Human({
    position = (Vector((random(5, SCREEN_W - 5)), 160)),
    velocity = (Vector(sign * speed, 0)),
    speed = speed
  }))
  return h:say(L.randomChoice({
    '',
    'Hi',
    'Hello',
    'Hello!',
    'I am alive',
    'Yay!',
    'Hey',
    "What's up?"
  }))
end
local handleMouse
handleMouse = function(collider)
  if input:pressed('left_click') then
    local mouse_vector = getMousePosition()
    local humans = collider:queryPoint(mouse_vector.x, mouse_vector.y, function(entity)
      return entity.human
    end)
    if humans[1] then
      setRandomVolume()
    end
    if humans[1] then
      la.play(sound.click)
    end
    for _index_0 = 1, #humans do
      local human = humans[_index_0]
      if not human.is_jumping then
        local r = math.floor(random(10))
        if r == 0 then
          human:explode()
          la.play(sound.explosion)
        else
          if r < 6 then
            human:rotate()
          else
            local _ = la.play
            human:jump()
            la.play(sound.jump)
          end
        end
      end
    end
    local button = (collider:queryPoint(mouse_vector.x * ZOOM_SCALE, mouse_vector.y * ZOOM_SCALE, function(entity)
      return entity.button
    end))[1]
    if button then
      if button.windmill_button then
        buyWindmill(world)
      end
      if button.human_button then
        return buyHuman(world)
      end
    end
  end
end
love.load = function()
  global_timer = Timer()
  device, source = initMicrophone()
  world = ECS.world(Alien(), WindmillButton(), HumanlButton())
  addRandomWindmill(world)
  global_timer:every(0.2, (function()
    return addRandomHuman(world)
  end), 10)
  local addSystems
  addSystems = function(world, systems)
    for k, v in pairs(systems) do
      world:addSystem(v)
    end
  end
  addSystems(world, systems)
  collider = Bump.newWorld(64)
  input = initInput()
  return intiDebugGraphs()
end
buyWindmill = function(world)
  if energy >= windmill_price and not game_over then
    setRandomVolume()
    la.play(sound.button)
    addRandomWindmill(world)
    energy = energy - windmill_price
    windmill_price = windmill_price * 2
  end
end
buyHuman = function(world)
  if energy >= human_price and not game_over then
    setRandomVolume()
    la.play(sound.button)
    addRandomHuman(world)
    energy = energy - human_price
    human_price = human_price + 5
  end
end
love.update = function(dt)
  if GAME_RUNNING then
    world:update(dt, ECS.rejectAny('is_draw_system'))
    device:poll()
    global_timer:update(dt)
    handleMouse(collider)
    Shake:update(dt)
    if input:pressed('make_random_windmill') then
      buyWindmill(world)
    end
    if input:pressed('make_random_human') then
      buyHuman(world)
    end
    if (current_sh_button == 's') and input:pressed('s') then
      current_sh_button = 'h'
      energy = energy + (0.2 * windmill_count)
    end
    if (current_sh_button == 'h') and input:pressed('h') then
      current_sh_button = 's'
      energy = energy + (0.2 * windmill_count)
    end
    updateDebugGraphs(dt, world)
  else
    if input:pressed('next_screen') then
      SPLASH_SCREEN = SPLASH_SCREEN + 1
    end
    if SPLASH_SCREEN == 4 then
      GAME_RUNNING = true
    end
  end
  if input:pressed('toggle_mute') then
    mute_sound = L.toggle(mute_sound)
  end
  if input:pressed('exit') then
    return love.event.quit()
  end
end
local canvas = lg.newCanvas(SCREEN_W, SCREEN_H)
canvas:setFilter('nearest')
love.draw = function()
  lg.setCanvas(canvas)
  lg.clear()
  lg.setLineStyle('rough')
  lg.setBackgroundColor(WHITE)
  lg.setColor(WHITE)
  if GAME_RUNNING then
    lg.draw(images.background)
    Shake:apply()
    world:update(0, ECS.filter('!text_system&draw_system'))
    if DEBUG then
      drawColliderDebug(collider)
    end
  else
    if SPLASH_SCREEN == 1 then
      lg.draw(images.splash_1)
    end
    if SPLASH_SCREEN == 2 then
      lg.draw(images.splash_2)
    end
    if SPLASH_SCREEN == 3 then
      lg.draw(images.splash_3)
    end
  end
  lg.setCanvas()
  lg.setColor(WHITE)
  lg.draw(canvas, 0, 0, 0, ZOOM_SCALE, ZOOM_SCALE)
  if GAME_RUNNING then
    world:update(0, ECS.filter('text_system&draw_system'))
    local cache_font = lg.getFont()
    lg.setFont(lg.newFont(20))
    lg.setColor(WHITE)
    local line_y = ZOOM_SCALE * SCREEN_H - 250
    lg.print('Energy: ' .. (L.round(energy, 0.01)), 10, line_y)
    line_y = line_y + 30
    lg.print('Time to next tax pay: ' .. (L.round(time_to_next_tax, 0.1)) .. ' seconds', 10, line_y)
    line_y = line_y + 30
    lg.print('Next tax size: ' .. next_tax_cost .. ' energy', 10, line_y)
    line_y = line_y + 30
    if game_over then
      cache_font = lg.getFont()
      lg.setFont(lg.newFont(40))
      lg.print('GAME OVER', ZOOM_SCALE * SCREEN_W / 2 - 128, ZOOM_SCALE * SCREEN_H / 2 - 128)
      lg.setFont(cache_font)
    end
  end
  if DEBUG then
    return drawDebugGraphs()
  end
end
