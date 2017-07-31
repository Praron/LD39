require 'libs/autobatch'
F = require 'libs/moses'  -- F for Functional
L = require 'libs/lume'  -- L for Lume
import random from L
Object = require 'libs/classic'
Timer = require 'libs/timer'
Input = require 'libs/boipushy'
GameState = require 'libs/gamestate'
ECS = require 'libs/tiny_ecs'
Vector = require 'libs/vector'
Bump = require 'libs/bump'
DebugGraph = require 'libs/debug_graph'
BumpDebug = require 'libs/bump_debug'
Observer = require 'libs/talkback'
Shake = require 'libs/shack'
Utils = require 'libs/utils'
Microphone = require 'libs/love-microphone'
Anim8 = require 'libs/anim8'

Talk = Observer.new!

{graphics: lg, math: lm, audio: la} = love

setmetatable _G, __index: require('libs/cargo').init
    dir: 'assets'
    processors:
        ['images/']: (image, file_name) ->
            image\setFilter 'nearest'

export DEBUG = false

export SCREEN_X0 = 0
export SCREEN_Y0 = 0
export SCREEN_W = 256
export SCREEN_H = 256
export GAME_RUNNING = false
export SPLASH_SCREEN = 1

export ZOOM_SCALE = 3

WHITE = {255, 255, 255}
LIGHT_GRAY = {203, 219, 252}
LIGHT_BLUE = {95, 205, 228}
DEBUG_RED = {255, 150, 150}
GREEN = {106, 190, 48}
RED = {172, 50, 50}
DARK_BLUE = {34, 32, 52}
ORANGE = {223, 113, 38}
DARK_PINK = {217, 87, 99}
BLACK = {0, 0, 0}

tableToArray = (t) -> [v for k, v in pairs t]

getCenterPosition = -> Vector SCREEN_W / 2, SCREEN_H / 2

getMousePosition = -> Vector love.mouse.getX! / ZOOM_SCALE, love.mouse.getY! / ZOOM_SCALE

setRandomVolume = ->
    la.setVolume random 0.3, 1
    la.setVolume 0 if mute_sound

export energy = 0
export windmill_price = 10
export human_price = 10
export time_to_next_tax = 20
export next_tax_time = 15
export next_tax_cost = 2
export windmill_count = 0
export human_count = 0
export game_over = false
export mute_sound = false

export current_sh_button = 's'

Entity = (components) ->
    for i = 1, #components
        component = components[i]
        components[component] = true
        components[i] = nil

    components.new = (t = {}) =>
        entity = Utils.deepCopy @
        entity[k] = v for k, v in pairs t

        for i = 1, #t
            component = t[i]
            entity[component] = true
            entity[i] = nil

        return entity
    setmetatable components, __call: (t) => @\new t

    components.timer = Timer!
    components.existing_time = 0

    components.getCenter = =>
        if @bounding_box then return @position + Vector @bounding_box.w / 2, @bounding_box.h / 2
        else return @position\clone!

    return components

export peak_amplitude = 0
Windmill = Entity {
    'windmill'
    position: getCenterPosition!
    blades_speed: 0
    blades_rotation: 0
    size: 32
    draw: =>
        lg.setColor WHITE
        lg.polygon 'fill', @position.x, @position.y,
                           @position.x - @size / 10, @position.y,
                           @position.x - @size / 20, @position.y - @size,
                           @position.x + @size / 20, @position.y - @size,
                           @position.x + @size / 10, @position.y
        lg.circle 'fill', @position.x, @position.y - @size - 2, 2

        for i = 1, 3
            p1 = Vector @position.x, @position.y - @size - 2
            p2 = p1 + (Vector @size * 0.8, 0)\rotated (2 * math.pi / 3 * i + @blades_rotation)
            p3 = p1 + (Vector @size * 0.3, -5 * @size / 32)\rotated (2 * math.pi / 3 * i + @blades_rotation)
            lg.polygon 'fill', p1.x, p1.y, p2.x, p2.y, p3.x, p3.y
}

ExplotionParticle = Entity {
    'particle'
    'die_on_stop'
    position: getCenterPosition!
    velocity: Vector 100, 0
    acceleration: -10
    draw: =>
        lg.setColor RED
        lg.circle 'fill', @position.x, @position.y, 2
}

Alien = Entity {
    'alien'
    position: Vector SCREEN_W / 2 - images.alien\getWidth! / 3 / 2, -51
    animation: {sheet: images.alien, number_of_frames: 3, duration: 100000000}
    draw: =>
        lg.setColor WHITE
        @animation.animation\draw images.alien, @position.x, @position.y
}


Ray = Entity {
    'ray'
    bounding_box: w: images.ray\getWidth!, h: images.ray\getHeight!
    position: getCenterPosition!
    life_time: 2
    draw: =>
        lg.setColor WHITE
        lg.draw images.ray, @position.x, @position.y
        Shake\setShake 2
}

addExplosion = (world, position) ->
    Shake\setShake 20
    for _ = 1, 16
        world\addEntity ExplotionParticle position: position, velocity: ExplotionParticle.velocity\rotated(random 2 * math.pi) * random 1, 2

Human = Entity {
    'human'
    position: getCenterPosition!
    bounding_box: w: images.human\getWidth! + 3, h: images.human\getHeight! + 3
    velocity: Vector 32, 0
    speed: 32
    animation: {sheet: images.human_walk, number_of_frames: 7, duration: 0.1}
    draw: =>
        lg.setColor WHITE
        @animation.animation\flipH @velocity.x < 0
        @animation.animation\draw images.human_walk, @position.x, @position.y
    is_jumping: false
    jump: =>
        @is_jumping = true
        @position.y -= 3
        @velocity.y = -200
        @acceleration = Vector 0, 200
        if (random 1) < 0.3 then @say L.randomChoice {'We-e-e!', 'I have fear of heights!', 'Humans looks like ant from there'}
    explode: =>
        @died = true
    rotate: =>
        @velocity.x *= -1
        if (random 1) < 0.4 then @say L.randomChoice {'Stop clicking on me!', "Don't click on us", 'Please, stop', "That's annoying"}
    say: (text) =>
        setRandomVolume!
        la.play sound.say
        @text_to_say_timer\cancel! if @text_to_say_time
        @text_to_say = text
        @text_to_say_timer = @timer\after 2, ->
            @text_to_say = nil
            @text_to_say_timer = nil
}

WindmillButton = Entity {
    'button'
    'windmill_button'
    position: Vector 10, ZOOM_SCALE * SCREEN_H - 150
    bounding_box: w: 300, h: 35
    draw: =>
        cache_font = lg.getFont!
        lg.setFont lg.newFont 20
        lg.setColor DARK_BLUE
        lg.setColor WHITE if energy >= windmill_price
        lg.setLineWidth 3
        lg.rectangle 'line', @position.x, @position.y, @bounding_box.w, @bounding_box.h
        lg.setLineWidth 1
        lg.print '[Z] Buy windmill (' .. windmill_price .. ' energy)', @position.x + 5, @position.y + 5
        lg.setFont cache_font
}

HumanlButton = Entity {
    'button'
    'human_button'
    position: Vector 10, ZOOM_SCALE * SCREEN_H - 100
    bounding_box: w: 300, h: 35
    draw: =>
        cache_font = lg.getFont!
        lg.setFont lg.newFont 20
        lg.setColor DARK_BLUE
        lg.setColor WHITE if energy >= human_price
        lg.setLineWidth 3
        lg.rectangle 'line', @position.x, @position.y, @bounding_box.w, @bounding_box.h
        lg.print '[X] Buy human (' .. human_price .. ' energy)', @position.x + 10, @position.y + 5
        lg.setFont cache_font
}


systems = {}
import processingSystem, requireAll, requireAny from ECS

systems.animation_manager = with processingSystem!
    .filter = requireAll 'animation'
    .onAdd = (e) =>
        img = e.animation.sheet
        grid = Anim8.newGrid img\getWidth! / e.animation.number_of_frames, img\getHeight!, img\getWidth!, img\getHeight!
        e.animation.animation = Anim8.newAnimation (grid "1-#{e.animation.number_of_frames}", 1), e.animation.duration
    .process = (e, dt) =>
        e.animation.animation\update dt

systems.blades_rotation = with processingSystem!
    .filter = requireAll 'blades_rotation'
    .process = (e, dt) =>
        e.blades_speed += peak_amplitude * dt * 5
        e.blades_rotation += e.blades_speed
        e.blades_speed -= e.blades_speed * dt
        e.blades_speed = 0 if e.blades_speed < 0.02
        if e.blades_speed > 0.8
            setRandomVolume!
            la.play sound.wind
        -- print e.blades_speed if e.blades_speed != 0

systems.life_time = with processingSystem!
    .filter = requireAll 'life_time'
    .process = (e, dt) =>
        e.life_time -= dt
        world\removeEntity e if e.life_time < 0

systems.moving_system = with processingSystem!
    .filter = requireAll 'position', 'velocity'
    .process = (e, dt) =>
        e.position += e.velocity * dt
        e.velocity += e.acceleration * dt if type(e.acceleration) == 'table'  -- If acceleration is a Vector
        e.velocity += e.velocity * e.acceleration * dt if type(e.acceleration) == 'number'
        e.velocity\trimInplace e.max_speed if e.max_speed

systems.human_moving_system = with processingSystem!
    .filter = requireAll 'human', 'position'
    .process = (e) =>
        if e.position.x < 5 then e.velocity.x = e.speed
        if e.position.x > SCREEN_W - 5 then e.velocity.x = -e.speed
        if e.position.y > 160
            e.is_jumping = false
            e.position.y = 160
            e.acceleration = nil
            e.velocity.y = 0
        if e.position.y < -40 then e\explode!

systems.energy_manager = with processingSystem!
    .filter = requireAll 'windmill'
    .process = (e, dt) =>
        energy += e.blades_speed * dt

systems.die_on_stop = with processingSystem!
    .filter = ECS.requireAll 'die_on_stop', 'velocity'
    .process = (e) => @world\removeEntity e if e.velocity\len2! < .1

systems.collider = with processingSystem!
    .filter = requireAll 'position', 'bounding_box'
    .onAdd = (e) => collider\add e, e.position.x, e.position.y, e.bounding_box.w, e.bounding_box.h
    .onRemove = (e) => collider\remove e
    .process = (e) => collider\update e, e.position.x, e.position.y

systems.human_ray_collider = with processingSystem!
    .filter = requireAll 'human'
    .process = (e) =>
        for c in *collider\getCollisions e
            if c.other.ray
                e.acceleration = Vector 0, -100
                if not e.raised
                    e\say L.randomChoice {"Al Gore, you've doomed us all", "Oh no", "Yay, I will die!", ":c"}
                e.raised = true

systems.died_manager = with processingSystem!
    .filter = requireAny 'explode'
    .process = (e) =>
        if e.died
            addExplosion @world, e.position\clone!\moveInplace 3, 3
            @world\removeEntity e
            addRandomHuman @world if not e.raised

systems.windmill_count = with processingSystem!
    .filter = requireAll 'windmill'
    .onAdd = -> windmill_count += 1
    .onRemove = -> windmill_count -= 1

systems.human_count = with processingSystem!
    .filter = requireAll 'human'
    .onAdd = -> human_count += 1
    .onRemove = ->
        human_count -= 1
        game_over = true if human_count == 0

systems.alien = with processingSystem!
    .filter = requireAny 'alien'
    .process = (e, dt) =>
        time_to_next_tax -= dt
        if time_to_next_tax < 0 and not game_over
            time_to_next_tax = next_tax_time
            e.animation.animation\gotoFrame 1
            e.timer\tween 1, e.position, {y: -16}, 'out-quad'
            setRandomVolume!
            la.play sound.question
            e.timer\after 2, ->
                setRandomVolume!
                if energy >= next_tax_cost
                    energy -= next_tax_cost
                    next_tax_cost *= 1.5
                    e.animation.animation\gotoFrame 2
                    la.play sound.success
                else
                    la.play sound.fail
                    e.animation.animation\gotoFrame 3
                    e.timer\after 2, ->
                        addRandomRay @world
                        la.play sound.ray
                e.timer\after 1, ->
                    e.timer\tween 1, e.position, {y: -50}, 'in-linear'




systems.random_saying = with processingSystem!
    .filter = requireAll 'say'
    .process = (e, dt) =>
        e.time_to_next_phrase = random 5, 25 if not e.time_to_next_phrase
        e.time_to_next_phrase -= dt
        if e.time_to_next_phrase < 0
            e.time_to_next_phrase = random 5, 25
            e\say L.randomChoice {'I want a donut', 'This party stinks', 'Ludum Dare is cool!', "I don't want to die", ':D', 'I am tired', '-1', 'Oh no', "I'm a tiny human",
                                  'Our lives are just meaningless', 'I like cats!', "Don't click on us, please", 'I like green ice cream', 'Very fun activity, yeah', 'Rate us!',
                                  'Arrow is in my knee', "I don't sleep for 48 hours", "I don't believe in cheese", 'The Earth is flat!', 'MoonScript is very cool!', "We're so small"
                                  'LOVE is very cool!', 'Mondays sucks', 'Click me!', "Trust me, I'm a dolphin", "I'm a anime girl!", '!$%@}&#|*', "Our world doesn't real",
                                  "Mom, look at me, I'm in the game!", 'I love Ludum Dare!', 'Special for LD39', 'Save us from existing', 'This plot is stupid', 'Longcat is long'}


systems.timer_manager = with processingSystem!
    .filter = requireAll 'timer'
    .process = (e, dt) => e.timer\update dt

systems.draw = with processingSystem!
    .draw_system = true
    .filter = requireAll 'draw'
    .process = (e) => e\draw!

systems.draw_buttons = with processingSystem!
    .draw_system = true
    .text_system = true
    .filter = requireAll 'draw', 'button'
    .process = (e) => e\draw!

systems.text_bubbles = with processingSystem!
    .draw_system = true
    .text_system = true
    .filter = requireAll 'text_to_say'
    .process = (e) =>
        if e.text_to_say
            cache_font = lg.getFont!
            lg.setFont lg.newFont 24
            lg.setColor BLACK
            lg.print e.text_to_say, ZOOM_SCALE * (e.position.x - e.text_to_say\len! / 2 * 3), ZOOM_SCALE * (e.position.y - 10)
            lg.setFont cache_font


local fps_graph, mem_graph, entity_graph, collider_graph

intiDebugGraphs = ->
    fps_graph = DebugGraph\new 'fps', 0, 0, 30, 50, 0.2, 'fps', lg.newFont(16)
    mem_graph = DebugGraph\new 'mem', 0, 50, 30, 50, 0.2, 'mem', lg.newFont(16)
    entity_graph = DebugGraph\new 'custom', 0, 100, 30, 50, 0.3, 'ent', lg.newFont(16)

updateDebugGraphs = (dt, world) ->
    fps_graph\update dt
    mem_graph\update dt
    entity_graph\update dt, world\getEntityCount!
    entity_graph.label = 'Entities: ' .. world\getEntityCount!

    if input\pressed 'toggle_debug' then DEBUG = L.toggle DEBUG
    if input\pressed 'collect_garbage' then collectgarbage 'collect'

drawDebugGraphs = ->
    lg.setColor WHITE
    fps_graph\draw!
    mem_graph\draw!
    entity_graph\draw!

drawColliderDebug = (collider) ->
    BumpDebug.draw collider
    lg.setColor DEBUG_RED
    items = collider\getItems!
    lg.rectangle 'line', collider\getRect i for i in *items


initInput = ->
    input = with Input!
        \bind 'z', 'make_random_windmill'
        \bind 'x', 'make_random_human'
        \bind '1', 'get_energy'
        \bind 'mouse1', 'left_click'
        \bind 'mouse2', 'right_click'
        \bind 'f1', 'toggle_debug'
        \bind 'f2', 'collect_garbage'
        \bind 'escape', 'exit'
        \bind 'm', 'toggle_mute'
        \bind 's', 's'
        \bind 'h', 'h'
        \bind 'space', 'next_screen'
        \bind 'mouse1', 'next_screen'
    return input


getPeakAmplitude = (data) ->
    peak_amp = -math.huge
    for t = 0, data\getSampleCount! - 1
        amp = math.abs data\getSample t
        peak_amp = math.max peak_amp, amp
    return peak_amp


initMicrophone = ->
    print 'Opening microphone:', Microphone.getDefaultDeviceName!
    device = Microphone.openDevice nil, nil, 0.1
    source = Microphone.newQueueableSource!
    device\setDataCallback (device, data) ->
        peak_amplitude = getPeakAmplitude data
        -- print peak_amplirude
    device\start!
    return device, source

addRandomWindmill = (world) ->
    y = random 1, 25
    v = Vector (random 10, SCREEN_W - 10), 170 - y
    world\addEntity Windmill position: v, size: 32 - y

export addRandomRay = (world) -> world\addEntity Ray position: Vector (random 0, SCREEN_W - images.ray\getWidth!), 0

export addRandomHuman = (world) ->
    speed = random 20, 40
    sign = 0
    if (random 1) > 0.5
        sign = 1
    else
        sign = -1
    h = world\addEntity Human position: (Vector (random 5, SCREEN_W - 5), 160), velocity: (Vector sign * speed, 0), speed: speed

    h\say L.randomChoice {'', 'Hi', 'Hello', 'Hello!', 'I am alive', 'Yay!', 'Hey', "What's up?"}

handleMouse = (collider) ->
    if input\pressed 'left_click'
        mouse_vector = getMousePosition!
        humans = collider\queryPoint mouse_vector.x, mouse_vector.y, (entity) -> entity.human
        setRandomVolume! if humans[1]
        la.play sound.click if humans[1]
        for human in *humans
            if not human.is_jumping
                r = math.floor random 10
                if r == 0
                    human\explode!
                    la.play sound.explosion
                else if r < 6
                    human\rotate!
                else
                    la.play
                    human\jump!
                    la.play sound.jump

        button = (collider\queryPoint mouse_vector.x * ZOOM_SCALE, mouse_vector.y * ZOOM_SCALE, (entity) -> entity.button)[1]
        if button
            if button.windmill_button
                buyWindmill world
            if button.human_button
                buyHuman world


love.load = ->
    export global_timer = Timer!

    export device, source = initMicrophone!

    export world = ECS.world Alien!, WindmillButton!, HumanlButton!
    addRandomWindmill world
    global_timer\every 0.2, (-> addRandomHuman world), 10
        
    addSystems = (world, systems) -> world\addSystem v for k, v in pairs systems
    addSystems world, systems

    export collider = Bump.newWorld 64

    export input = initInput!

    intiDebugGraphs!

export buyWindmill = (world) ->
    if energy >= windmill_price and not game_over
        setRandomVolume!
        la.play sound.button
        addRandomWindmill world
        energy -= windmill_price
        windmill_price *= 2

export buyHuman = (world) ->
    if energy >= human_price and not game_over
        setRandomVolume!
        la.play sound.button
        addRandomHuman world
        energy -= human_price
        human_price += 5

love.update = (dt) ->

    if GAME_RUNNING
        world\update dt, ECS.rejectAny 'is_draw_system'

        device\poll!

        global_timer\update dt

        handleMouse collider

        Shake\update dt

        buyWindmill world if input\pressed 'make_random_windmill'
        buyHuman world if input\pressed 'make_random_human'

        if (current_sh_button == 's') and input\pressed 's'
            current_sh_button = 'h'
            energy += 0.2 * windmill_count
        if (current_sh_button == 'h') and input\pressed 'h'
            current_sh_button = 's'
            energy += 0.2 * windmill_count

        updateDebugGraphs dt, world
    else
        SPLASH_SCREEN += 1 if input\pressed 'next_screen'
        GAME_RUNNING = true if SPLASH_SCREEN == 4

    if input\pressed 'toggle_mute' then mute_sound = L.toggle mute_sound
    if input\pressed 'exit' then love.event.quit!


canvas = lg.newCanvas(SCREEN_W, SCREEN_H)
canvas\setFilter 'nearest'
love.draw = ->
    lg.setCanvas canvas
    lg.clear!
    lg.setLineStyle 'rough'


    lg.setBackgroundColor WHITE
    lg.setColor WHITE
    if GAME_RUNNING
        lg.draw images.background

        Shake\apply!

        world\update 0, ECS.filter '!text_system&draw_system'

        drawColliderDebug collider if DEBUG
    else
        lg.draw images.splash_1 if SPLASH_SCREEN == 1
        lg.draw images.splash_2 if SPLASH_SCREEN == 2
        lg.draw images.splash_3 if SPLASH_SCREEN == 3

    lg.setCanvas!
    lg.setColor WHITE
    lg.draw canvas, 0, 0, 0, ZOOM_SCALE, ZOOM_SCALE

    if GAME_RUNNING
        world\update 0, ECS.filter 'text_system&draw_system'

        cache_font = lg.getFont!
        lg.setFont lg.newFont 20
        lg.setColor WHITE
        line_y = ZOOM_SCALE * SCREEN_H - 250
        lg.print 'Energy: ' .. (L.round energy, 0.01), 10, line_y
        line_y += 30
        lg.print 'Time to next tax pay: ' .. (L.round time_to_next_tax, 0.1) .. ' seconds', 10, line_y
        line_y += 30
        lg.print 'Next tax size: ' .. next_tax_cost .. ' energy', 10, line_y
        line_y += 30

        if game_over
            cache_font = lg.getFont!
            lg.setFont lg.newFont 40
            lg.print 'GAME OVER', ZOOM_SCALE * SCREEN_W / 2 - 128, ZOOM_SCALE * SCREEN_H / 2 - 128
            lg.setFont cache_font

    drawDebugGraphs! if DEBUG
