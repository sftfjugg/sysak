---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/26 4:02 PM
---

package.path = package.path .. ";../common/?.lua;"
package.path = package.path .. ";../tsdb/?.lua;"
package.path = package.path .. ";../tsdb/native/?.lua;"

local CfoxRecv = require("foxRecv")
local unistd = require("posix.unistd")
--local proto = require("protoData")
--local system = require("system")


local fox = CfoxRecv.new()

function init(tid)
    print(string.format("hello beeQ, pid: %d, tid: %d", unistd.getpid(), tid))
    return 0
end

function proc(stream)
    fox:write(stream)
    collectgarbage("collect")
    return 0
end