---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/16 10:39 PM
---

require("class")
local CprotoData = require("protoData")
local procffi = require("procffi")

local CprocStat = require("proc_stat")
local CprocMeminfo = require("proc_meminfo")
local CprocVmstat = require("proc_vmstat")
local CprocNetdev = require("proc_netdev")
local CprocDiskstats = require("proc_diskstats")

local Cplugin = require("plugin")

local Cloop = class("loop")

function Cloop:_init_(que, proto_q)
    self._proto = CprotoData.new(que)
    self._procs = {
        CprocStat.new(self._proto, procffi),
        CprocMeminfo.new(self._proto, procffi),
        CprocVmstat.new(self._proto, procffi),
        CprocNetdev.new(self._proto, procffi),
        CprocDiskstats.new(self._proto, procffi),
    }
    self._plugin = Cplugin.new(self._proto, que, proto_q)
end

function Cloop:work(t)
    local lines = self._proto:protoTable()
    for k, obj in pairs(self._procs) do
        lines = obj:proc(t, lines)
    end
    lines = self._plugin:proc(t, lines)
    print(#lines.lines)
    local bytes = self._proto:encode(lines)
    self._proto:que(bytes)
end

return Cloop