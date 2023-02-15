---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/7 11:40 PM
---

package.path = package.path .. ";../../?.lua;"
local unistd = require("posix.unistd")
local socket = require("socket")
local system = require("common.system")

local pipe = "/tmp/udp"
if not unistd.access(pipe) then
    print("host not listen.")
end

socket.unix = require("socket.unix")
local s = socket.unix.udp()
s:connect(pipe)

s:send("hello.")
s:close()

pipe = "/tmp/udp2"
if not unistd.access(pipe) then
    print("hosts not listen.")
end

socket.unix = require("socket.unix")
s = socket.unix.udp()
s:connect(pipe)

s:send("hello pipe2.")
s:close()
