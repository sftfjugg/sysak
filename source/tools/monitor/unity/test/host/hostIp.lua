---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/10 12:16 AM
---

local socket = require("socket")

local function getAdd(hostName)
    local _, resolved = socket.dns.toip(hostName)
    local listTab = {}
    for _, v in pairs(resolved.ip) do
        table.insert(listTab, v)
    end
    return listTab
end

print(unpack(getAdd("localhost")))
print(socket.dns.gethostname())
print(unpack(getAdd(socket.dns.gethostname())))