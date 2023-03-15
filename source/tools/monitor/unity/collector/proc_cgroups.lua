---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/3/8 2:32 PM
---

require("common.class")
local pystring = require("common.pystring")
local CvProc = require("collector.vproc")

local Ccgroups = class("cgroups", CvProc)

function Ccgroups:_init_(proto, pffi, mnt, pFile)
    CvProc._init_(self, proto, pffi, mnt, pFile or "proc/cgroups")
end

function Ccgroups:proc(elapsed, lines)
    local c = 0
    CvProc.proc(self)
    local values = {}
    local ls = {
        name = "type",
        index = "num_cgroups",
    }

    for line in io.lines(self.pFile) do
        if c > 0 then
            local cell = pystring:split(line)
            values[c - 1] = {
                name = cell[1],
                value = tonumber(cell[3])
            }
        end
        c = c + 1
    end
    self:appendLine(self:_packProto("cgroups", {ls}, values))
    self:push(lines)
end

return Ccgroups