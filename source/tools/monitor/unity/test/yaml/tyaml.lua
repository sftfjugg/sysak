---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/25 9:03 AM
---

-- refer to https://www.runoob.com/w3cnote/yaml-intro.html

local lyaml = require "lyaml"
local serpent = require("serpent")

local f = io.open("descr.yaml","r")
local s = f:read("*all")
f:close()

local tDescr = lyaml.load(s)
print(serpent.block(tDescr))
