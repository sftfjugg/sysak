---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/21 2:39 PM
---

-- refer to https://blog.csdn.net/zx_emily/article/details/83024065

require("common.class")
local ChttpComm = require("httplib.httpComm")
local pystring = require("common.pystring")
local system = require("common.system")
local Cframe = class("frame", ChttpComm)

function Cframe:_init_()
    ChttpComm._init_(self)
    self._objs = {}
    self._obj_res = {}
end

local function waitDataRest(fread, rest, tReq)
    local len = 0
    local tStream = {tReq.data}
    local c = #tStream
    while len < rest do
        local s = fread()
        if s then
            len = len + #s
            c = c + 1
            tStream[c] = s
        else
            return -1
        end
    end
    tReq.data = pystring:join("", tStream)
    return 0
end

local function waitHttpRest(fread, tReq)
    if tReq.header["content-length"] then
        local lenData = #tReq.data
        local lenInfo = tonumber(tReq.header["content-length"])

        local rest = lenInfo - lenData
        if rest > 10 * 1024 * 1024 then  -- limit max data len
            return -1
        end

        if waitDataRest(fread, rest, tReq) < 0 then
            return -2
        end
    end
    return 0
end

local function waitHttpHead(fread)
    local stream = ""
    while true do
        local s = fread()
        if s then
            stream = stream .. s
            if string.find(stream, "\r\n\r\n") then
                return stream
            end
        else
            return nil
        end
    end
end

function Cframe:parse(fread, stream)
    local tStatus = pystring:split(stream, "\r\n", 1)
    if #tStatus < 2 then
        print("bad stream format.")
        return nil
    end

    local stat, heads = unpack(tStatus)
    local tStat = pystring:split(stat, " ")
    if #tStat < 3 then
        print("bad stat: "..stat)
        return nil
    end

    local method, path, vers = unpack(tStat)
    local tReq = self:parsePath(path)
    tReq.method = method
    tReq.vers = vers

    local tHead = pystring:split(heads, "\r\n\r\n", 1)
    if #tHead < 2 then
        print("bad head: " .. heads)
        return nil
    end
    local headers, data = unpack(tHead)
    local tHeader = pystring:split(headers, "\r\n")
    local header = {}
    for _, s in ipairs(tHeader) do
        local tKv = pystring:split(s, ":", 1)
        if #tKv < 2 then
            print("bad head kv value: " .. s)
            return nil
        end
        local k, v = unpack(tKv)
        k = string.lower(k)
        header[k] = pystring:lstrip(v)
    end
    tReq.header = header
    tReq.data = data
    if waitHttpRest(fread, tReq) < 0 then
        return nil
    end
    return tReq
end

function Cframe:echo404()
    local stat = self:packStat(404)
    local tHead = {
        ["Content-Type"] = "text/plain",
    }
    local body = "Oops! The page may have flown to Mars!!!\n"
    local headers = self:packHeaders(tHead, #body)
    local tHttp = {stat, headers, body}
    return pystring:join("\r\n", tHttp)
end

function Cframe:findObjRes(path)
    for k, v in pairs(self._obj_res) do
        if string.find(path, k) then
            return v
        end
    end
end

function Cframe:proc(fread)
    local stream = waitHttpHead(fread)
    if stream == nil then   -- read return stream or error code or nil
        return nil
    end

    local tReq = self:parse(fread, stream)
    if tReq then
        if self._objs[tReq.path] then
            local obj = self._objs[tReq.path]
            local res, keep = obj:call(tReq)
            return res, keep
        end

        local obj = self:findObjRes(tReq.path)
        if obj then
            local res, keep = obj:calls(tReq)
            return res, keep
        end

        return self:echo404(), false
    end
end

function Cframe:register(path, obj)
    assert(self._objs[path] == nil, "the " .. path .. " is already registered.")
    self._objs[path] = obj
end

function Cframe:registerRe(path, obj)
    assert(self._obj_res[path] == nil, "the " .. path .. " is already registered.")
    self._obj_res[path] = obj
end

return Cframe
