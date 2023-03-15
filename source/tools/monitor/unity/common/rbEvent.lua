---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/3/15 1:21 AM
---

require("common.class")

local lrbtree = require("lrbtree")
local ptime = require("posix.time")

local CrbEvent = class("rbEvent")


local function rbCmp(node1, node2)
    return node1.t - node2.t
end

local function calcSleep(hope, now)
    if hope.tv_nsec >= now.tv_nsec then
        return {tv_sec  = hope.tv_sec - now.tv_sec,
                tv_nsec = hope.tv_nsec - now.tv_nsec}
    else
        return {tv_sec  = hope.tv_sec - now.tv_sec - 1,
                tv_nsec = 1e9 + hope.tv_nsec - now.tv_nsec}
    end
end

local function timeNsec()
    local tStart = ptime.clock_gettime(ptime.CLOCK_MONOTONIC)
    return tStart.tv_nsec
end

function CrbEvent:_init_()
    self._tree = lrbtree.new(rbCmp)
    self._nsec = timeNsec()
end

function CrbEvent:addEvent(e, period, start, loop)
    start = start or false
    loop = loop or -1   -- -1: 会永远增加下去，大于1 则会递减，减少0 不再使用

    if loop == 0 then
        return
    end

    local beg = os.time()
    if not start then
        beg = beg + period
        loop = loop - 1
    end
    local node = {
        e = e,
        t = beg,
        period = period,
        loop = loop,
    }
    self._tree:insert(node)
end

function CrbEvent:_proc(node)
    print(node.e)
    if node.loop ~= 0 then  -- add to tail.
        node.t = node.t + node.period
        self._tree:insert(node)
        if node.loop > 0 then
            node.loop = node.loop - 1
        end
    end
end

function CrbEvent:proc()
    local now
    local node
    local tStart, tHope
    local diff

    while true do
        tStart = ptime.clock_gettime(ptime.CLOCK_MONOTONIC)

        now = os.time()
        node = self._tree:first()
        if node == nil then  -- blank tree stop
            break
        end

        while node.t <= now do   -- 到了预期时间
            self._tree:delete(node)
            self:_proc(node)
            node = self._tree:first()
        end

        tHope = {tv_sec = tStart.tv_sec + node.t - now, tv_nsec = tStart.tv_sec}
        diff = calcSleep(tHope, tStart)
        local _, s, errno, _ = ptime.nanosleep(diff)
        if errno then   -- interrupt by signal
            print(string.format("new sleep stop. %d, %s", errno, s))
            return 0
        end
    end
end

return CrbEvent