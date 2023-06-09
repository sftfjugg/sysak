---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/21 7:56 PM
---

package.path = package.path .. ";../../common/?.lua;"
local pystring = require("pystring")
local url = require("socket.url")
local serpent = require("serpent")

local function parseParam(param)
    local tParam = pystring:split(param, "&")
    local res = {}
    for i, s in ipairs(tParam) do
        local kv = pystring:split(s, "=")
        if #kv ~= 2 then
            print("bad param " .. s)
            return nil
        end
        local k = url.unescape(kv[1])
        local v = url.unescape(kv[2])
        res[k] = v
    end
    return res
end

local function parseParams(tUrl)
    if tUrl.query then
        tUrl.queries = parseParam(tUrl.query)
    end
    if tUrl.params then
        tUrl.paramses = parseParam(tUrl.params)
    end
    return tUrl
end

local path = "/cgilua/index.lua?a=2&b=%3D%3D#there"
local res = url.parse(path)
res = parseParams(res)
print(serpent.block(res))
path = "/pub/virus.exe;type=i&hello=world"
res = url.parse(path)
res = parseParams(res)
print(serpent.block(res))
