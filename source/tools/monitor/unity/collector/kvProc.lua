---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/16 11:30 PM
---

local system = require("common.system")
require("common.class")
local CvProc = require("collector.vproc")

local CkvProc = class("kvProc", CvProc)

function CkvProc:_init_(proto, pffi, pFile, tName)
    CvProc._init_(self, proto, pffi, pFile)
    self._protoTable = {
        line = tName,
        ls = nil,
        vs = {}
    }
end

function CkvProc:checkTitle(title)
    local res = string.gsub(title, ":", "")
    res = string.gsub(res, "%)", "")
    res = string.gsub(res, "%(", "_")
    return res
end

function CkvProc:readKV(line)
    local data = self._ffi.new("var_kvs_t")
    assert(self._cffi.var_input_kvs(self._ffi.string(line), data) == 0)
    assert(data.no >= 1)

    local name = self._ffi.string(data.s)
    name = self:checkTitle(name)
    local value = tonumber(data.value[0])

    local cell = {name=name, value=value}
    table.insert(self._protoTable["vs"], cell)
end

function CkvProc:proc(elapsed, lines)
    self._protoTable.vs = {}
    CvProc.proc(self)
    for line in io.lines(self.pFile) do
        self:readKV(line)
    end
    self:appendLine(self._protoTable)
    return self:push(lines)
end

return CkvProc