---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/16 11:40 PM
---

require("common.class")
local CkvProc = require("collector.kvProc")

local CprocVmstat = class("proc_vmstat", CkvProc)

function CprocVmstat:_init_(proto, pffi, pFile)
    CkvProc._init_(self, proto, pffi, pFile or "/proc/vmstat", "vmstat")
end

return CprocVmstat