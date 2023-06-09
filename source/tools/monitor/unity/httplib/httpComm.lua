---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/19 10:46 PM
---

require("common.class")
local pystring = require("common.pystring")
local sockerUrl = require("socket.url")

local ChttpComm = class("httplib.httpComm")

local cjson = require("cjson.safe")
local json = cjson.new()

local function codeTable()
    return {
        [100] = "Continue",
        [200] = "Ok",
        [201] = "Created",
        [202] = "Accepted",
        [204] = "No Content",
        [206] = "Partial Content",
        [301] = "Moved Permanently",
        [302] = "Found",
        [304] = "Not Modified",
        [400] = "Bad Request",
        [401] = "Unauthorized",
        [403] = "Forbidden",
        [404] = "Not Found",
        [418] = "I'm a teapot",
        [500] = "Internal Server Error",
        [501] = "Not Implemented"
    }
end

function ChttpComm:jencode(t)
    return json.encode(t)
end

function ChttpComm:jdecode(s)
    return json.decode(s)
end

local function parseParam(param)
    local tParam = pystring:split(param, "&")
    local res = {}
    for _, s in ipairs(tParam) do
        local kv = pystring:split(s, "=")
        if #kv ~= 2 then
            print("bad param " .. s)
            return nil
        end
        local k = sockerUrl.unescape(kv[1])
        local v = sockerUrl.unescape(kv[2])
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

function ChttpComm:parsePath(path)
    local res = sockerUrl.parse(path)
    return parseParams(res)
end

local function originHeader()
    return {
        server = "beaver/0.0.2",
        date = os.date("%a, %d %b %Y %H:%M:%S %Z", os.time()),
    }
end

function ChttpComm:packHeaders(headTable, len) -- just for http out.
    local lines = {}
    if not headTable["Content-Length"] then
        headTable["Content-Length"] = len
    end
    local origin = originHeader()

    local c = 0
    for k, v in pairs(origin) do
        c = c + 1
        lines[c] = table.concat({k, v}, ": ")
    end

    for k, v in pairs(headTable) do
        c = c + 1
        lines[c] = table.concat({k, v}, ": ")
    end
    return pystring:join("\r\n", lines) .. "\r\n"
end

local codeStrTable = codeTable()
function ChttpComm:packStat(code)
    local t = {"HTTP/1.1", code, codeStrTable[code]}
    return pystring:join(" ", t)
end

return ChttpComm
