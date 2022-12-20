---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/19 4:40 PM
---

require("class")
local ChttpComm = require("httpComm")
local ChttpCli = class("httpCli", ChttpComm)

function ChttpCli:_init_()
    ChttpComm._init_(self)
    self._http = require("socket.http")
    self._ltn12 = require("ltn12")
end

function ChttpCli:get(Url)
    local t = {}
    local res, code, head= self._http.request{
        url=Url,
        sink = self._ltn12.sink.table(t)
    }
    local body = table.concat(t)
    return {
        res = res,
        code = code,
        head = head,
        body = body
    }
end

function ChttpCli:post(Url, reqs, header)
    local headers = header or { Connection = 'close' }
    local source = self._ltn12.source.string(reqs)
    local t = {}
    local res, code, head = self._http.request{
        url = Url,
        method = "POST",
        headers = headers,
        source = source,
        sink = self._ltn12.sink.table(t)
    }
    local body = table.concat(t)
    return {
        res = res,
        code = code,
        head = head,
        body = body
    }
end

function ChttpCli:postTable(Url, t)
    local req = self:jencode(t)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = #req,
    }
    return self:post(Url, req, headers)
end

return ChttpCli
