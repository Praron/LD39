--[[
    Records a user's microphone and echos it back to them.

    This uses the included QueueableSource object, which may still have issues.
]]

-- Alias love-microphone as microphone
local microphone = require("love-microphone")
local device, source

function peakAmplitude(sounddata)
    local peak_amp = -math.huge
    for t = 0,sounddata:getSampleCount()-1 do
        local amp = math.abs(sounddata:getSample(t)) -- |s(t)|
        peak_amp = math.max(peak_amp, amp)
    end
    return peak_amp
end

function love.load()
    -- Report the name of the microphone we're going to use
    print("Opening microphone:", microphone.getDefaultDeviceName())

    -- Open the default microphone device with default quality and 100ms of latency.
    device = microphone.openDevice(nil, nil, 0.1)

    -- Create a new QueueableSource to echo our audio
    source = microphone.newQueueableSource()

    -- Register our local callback
    device:setDataCallback(function(device, data)
        source:queue(data)
        print(peakAmplitude(data))
        source:play()
    end)

    -- Start recording
    device:start()
end

-- Add microphone polling to our update loop
function love.update()
    device:poll()
end