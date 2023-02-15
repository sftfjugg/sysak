---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/1/12 2:53 PM
---

package.path = package.path .. ";../?.lua;"

local CprotoQueue = require("beeQ.proto_queue")

local workLoop = nil

function init(que, tid)
    print("local proto que setup for ", tid)
    local work = CprotoQueue.new(que)
    workLoop = work
    return 0
end

function que()
    return workLoop:que()
end

function send(num, pline)
    local ret = workLoop:send(num, pline)
    collectgarbage("collect")
    return ret
end
