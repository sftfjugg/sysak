---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/14 3:27 PM
---
--- export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:./native/
package.path = package.path .. ";../../../?.lua;"

local CLocalBeaver = require("localBeaver")

local bserver = CLocalBeaver.new()
bserver:poll()