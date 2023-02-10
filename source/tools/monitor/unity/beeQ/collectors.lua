---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/26 11:26 PM
---
package.path = package.path .. ";../?.lua;"

local Cloop = require("collector.loop")
local system = require("common.system")

workLoop = nil

local function setupFreq(fYaml)
    fYaml = fYaml or "../collector/plugin.yaml"
    local conf = system:parseYaml(fYaml)
    if conf then
        local ret = tonumber(conf.config.freq)
        if ret > 5 then
            return conf.config.freq
        else
            return 5
        end
    else
        error("load yaml file failed.")
        return -1
    end
end

function init(que, proto_q, t)
    local work = Cloop.new(que, proto_q)
    workLoop = work
    return setupFreq()
end

function work(t)
    workLoop:work(t)
    return 0
end
