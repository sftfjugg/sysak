---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/1/29 6:07 PM
---

require("common.class")
local CvProc = require("collector.vproc")

local CprocStatm = class("procStatm", CvProc)

function CprocStatm:_init_(proto, pffi, mnt, pFile)
    CvProc._init_(self, proto, pffi, mnt, pFile or nil)
end

function CprocStatm:proc(elapsed, lines)
    CvProc.proc(self)
    local heads = {"size", "resident", "shared", "text", "lib", "data", "dt"}
    for line in io.lines("/proc/self/statm") do
        local vs = {}
        local data = self._ffi.new("var_long_t")
        assert(self._cffi.var_input_long(self._ffi.string(line), data) == 0)
        assert(data.no == 7)
        for i, k in ipairs(heads) do
            local cell = {
                name = k,
                value = tonumber(data.value[i - 1]),
            }
            table.insert(vs, cell)
        end
        self:appendLine(self:_packProto("self_statm", nil, vs))
    end

    return self:push(lines)
end

return CprocStatm
