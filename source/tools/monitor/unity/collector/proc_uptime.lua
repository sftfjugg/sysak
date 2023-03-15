---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/3/1 3:13 PM
---

require("common.class")
local utsname = require("posix.sys.utsname")
local CvProc = require("collector.vproc")

local CprocUptime = class("procUptime", CvProc)

function CprocUptime:_init_(proto, pffi, mnt, pFile)
    CvProc._init_(self, proto, pffi, mnt, pFile or "proc/uptime")
    local distro, s, errno = utsname.uname()
    if distro then
        self._labels = {
            {name = "sysname", index = distro.sysname},
            {name = "nodename", index = distro.nodename},
            {name = "release", index = distro.release},
            {name = "version", index = distro.version},
            {name = "machine", index = distro.machine},
        }
    else
        error(string.format("read uname get %s, errno %d"), s, errno)
    end
    self._release = mnt .. "etc/system-release"
    self._counter = 60 * 60
end

local function readNum(pFile)
    local f = io.open(pFile,"r")
    local res1, res2 = -1, -1
    if f then
        res1, res2 = f:read("*n"), f:read("*n")
        f:close()
    end
    return res1, res2
end

local function readUname()
    local distro, s, errno = utsname.uname()
    if distro then
        return {
            {name = "sysname", index = distro.sysname},
            {name = "nodename", index = distro.nodename},
            {name = "release", index = distro.release},
            {name = "version", index = distro.version},
            {name = "machine", index = distro.machine},
        }
    else
        error(string.format("read uname get %s, errno %d"), s, errno)
    end
end

local function readRelease(pFile)
    local f = io.open(pFile)
    local res = "unknown"
    if f then
        res = f:read()
        f:close()
    end
    return res
end

function CprocUptime:proc(elapsed, lines)
    CvProc.proc(self)
    local uptime, idletime = readNum(self.pFile)
    local vs = {
        {name = "uptime", value = uptime},
        {name = "idletime", value = idletime},
        {name = "stamp", value = os.time()},
    }
    self:appendLine(self:_packProto("uptime", nil, vs))

    local totalTime = elapsed * self._counter
    if totalTime >= 10 * 60 then   -- report by hour
        local dummyValue = {{name = "dummy", value=1.0}}
        local labels = readUname()
        self:appendLine(self:_packProto("uname", labels, dummyValue))
        local releaseInfo = {{name = "release", index = readRelease(self._release)}}
        self:appendLine(self:_packProto("system_release", releaseInfo, dummyValue))
        self._counter = 0
    else
        self._counter = self._counter + 1
    end
    self:push(lines)
end

return CprocUptime
