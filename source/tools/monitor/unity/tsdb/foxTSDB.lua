---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/17 11:04 AM
---

require("common.class")

local system = require("common.system")
local snappy = require("snappy")
local pystring = require("common.pystring")
local CprotoData = require("common.protoData")
local foxFFI = require("tsdb.native.foxffi")

local CfoxTSDB = class("CfoxTSDB")

function CfoxTSDB:_init_()
    self.ffi = foxFFI.ffi
    self.cffi = foxFFI.cffi
    self._proto = CprotoData.new(nil)
    self._qBudget = 200
end

function CfoxTSDB:_del_()
    if self._man then
        self.cffi.fox_del_man(self._man)
    end
    self._man = nil
end

function CfoxTSDB:get_us()
    return self.cffi.get_us()
end

function CfoxTSDB:getDateFrom_us(us)
    local foxTime = self.ffi.new("struct foxDate")

    assert(self.cffi.get_date_from_us(us, foxTime) == 0)

    return foxTime
end

function CfoxTSDB:getDate()
    local foxTime = self.ffi.new("struct foxDate")

    assert(self.cffi.get_date(foxTime) == 0)

    return foxTime
end

function CfoxTSDB:makeStamp(foxTime)
    return self.cffi.make_stamp(foxTime)
end

function CfoxTSDB:date2str(date)
    local d = string.format("%04d-%02d-%02d", date.year + 1900, date.mon + 1, date.mday)
    local t = string.format("%02d:%02d:%02d", date.hour, date.min, date.sec)
    return d .. " " .. t
end

local function transDate(ds)
    local year, mon, mday = unpack(ds)
    return tonumber(year) - 1900, tonumber(mon) - 1, tonumber(mday)
end

local function transTime(ts)
    local hour, min, sec = unpack(ts)
    return tonumber(hour), tonumber(min), tonumber(sec)
end

function CfoxTSDB:str2date(s)
    local dt = pystring:split(s, " ", 1)
    local d, t = dt[1], dt[2]

    local ds = pystring:split(d, "-", 2)
    local ts = pystring:split(t, ":", 2)

    local foxTime = self.ffi.new("struct foxDate")
    foxTime.year, foxTime.mon, foxTime.mday = transDate(ds)
    foxTime.hour, foxTime.min, foxTime.sec  = transTime(ts)

    return foxTime
end

function CfoxTSDB:deltaSec(date)
    local delta = 0

    if date.sec then
        delta = delta + date.sec
    end
    if date.min then
        delta = delta + date.min * 60
    end
    if date.hour then
        delta = delta + date.hour * 60 * 60
    end
    if date.day then
        delta = delta + date.day * 24 * 60 * 60
    end
    return delta
end

function CfoxTSDB:moveSec(foxTime, off_sec)
    local us = self:makeStamp(foxTime) + off_sec * 1e6
    return self:getDateFrom_us(us)
end

function CfoxTSDB:movesSec(s, off_sec)
    local foxTime = self:str2date(s)
    return self:date2str(self:moveSec(foxTime, off_sec))
end

function CfoxTSDB:moveTime(foxTime, tTable)
    local sec = self:deltaSec(tTable)
    return self:moveSec(foxTime, sec)
end

function CfoxTSDB:movesTime(s, tTable)
    local foxTime = self:str2date(s)
    return self:date2str(self:moveTime(foxTime, tTable))
end

function CfoxTSDB:packLine(lines)
    return self._proto:encode(lines)
end

function CfoxTSDB:rotateDb()
    local dirent = require("posix.dirent")
    local unistd = require("posix.unistd")

    local usec = self._man.now
    local sec = 7 * 24 * 60 * 60

    local foxTime = self:getDateFrom_us(usec - sec * 1e6)
    local level = foxTime.year * 10000 + foxTime.mon * 100 + foxTime.mday

    local ok, files = pcall(dirent.files, './')
    if not ok then
        return
    end

    for f in files do
        if string.match(f,"^%d%d%d%d%d%d%d%d%.fox$") then
            local sf = string.sub(f, 1, 8)
            local num = tonumber(sf)
            if num < level then
                print("delete " .. "./" .. f)
                pcall(unistd.unlink, "./" .. f)
            end
            --pcall(unistd.unlink, "../" .. f)
        end
    end
end

function CfoxTSDB:setupWrite()
    assert(self._man == nil, "one fox object should have only one manager.")
    self._man = self.ffi.new("struct fox_manager")
    local date = self:getDate()
    local us = self:get_us()
    local ret = self.cffi.fox_setup_write(self._man, date, us)
    assert(ret == 0)
    return ret
end

function CfoxTSDB:write(buff)
    assert(self._man ~= nil, "this fox object show setup for read or write, you should call setupWrite after new")
    local now = self:get_us()
    local date = self:getDateFrom_us(now)
    local stream = snappy.compress(buff)
    print("write for time: ", now)
    assert(self.cffi.fox_write(self._man, date, now, self.ffi.string(stream, #stream), #stream) == 0)
    if self._man.new_day > 0 then
        self:rotateDb()
    end
    --assert(self.cffi.fox_write(self._man, date, now, self.ffi.string(buff), #buff) == 0)
end

function CfoxTSDB:_setupRead(us)
    assert(self._man == nil, "one fox object should have only one manager.")
    self._man = self.ffi.new("struct fox_manager")
    us = us or (self:get_us() - 15e6)
    local date = self:getDateFrom_us(us)
    local res = self.cffi.fox_setup_read(self._man, date, us)
    assert(res >= 0, string.format("setup read return %d.", res))
    if res > 0 then
        self.cffi.fox_del_man(self._man)
        self._man = nil
    end
    return res
end

function CfoxTSDB:curMove(us)
    assert(self._man)
    local ret = self.cffi.fox_cur_move(self._man, us)
    assert(ret >= 0, string.format("cur move bad ret: %d", ret))
    return self._man.pos
end

function CfoxTSDB:resize()
    assert(self._man)
    local ret = self.cffi.fox_read_resize(self._man)
    assert(ret >= 0, string.format("resize bad ret: %d", ret))
end

function CfoxTSDB:loadData(stop_us)
    local stop = false

    local function fLoad()
        if stop then
            return nil
        end

        local data = self.ffi.new("char* [1]")
        local us = self.ffi.new("fox_time_t [1]")
        local ret = self.cffi.fox_read(self._man, stop_us, data, us)
        assert(ret >= 0)
        if ret > 0 then
            local stream = self.ffi.string(data[0], ret)
            local ustr = snappy.decompress(stream)
            local line = self._proto:decode(ustr)
            self.cffi.fox_free_buffer(data)

            if self._man.fsize == self._man.pos then  -- this means cursor is at the end of file.
                stop = true
            end
            line['time'] = tonumber(us[0])
            return line
        end
        return nil
    end
    return fLoad
end

function CfoxTSDB:query(start, stop, ms)  -- start stop should at the same mday
    assert(stop > start)
    local dStart = self:getDateFrom_us(start)
    local dStop = self:getDateFrom_us(stop)

    assert(self.cffi.check_foxdate(dStart, dStop) == 1)  -- check date
    assert(self._man)

    self:curMove(start)    -- moveto position

    for line in self:loadData(stop) do
        local time = line.time
        for _, v in ipairs(line.lines) do
            local tCell = {time = time, title = v.line}

            local labels = {}
            if v.ls then
                for _, vlabel in ipairs(v.ls) do
                    labels[vlabel.name] = vlabel.index
                end
            end
            tCell.labels = labels

            local values = {}
            if v.vs then
                for _, vvalue in ipairs(v.vs) do
                    values[vvalue.name] = vvalue.value
                end
            end
            tCell.values = values

            table.insert(ms, tCell)
        end
    end
    return ms
end

function CfoxTSDB:qlast(last, ms)
    local now = self:get_us()
    local date = self:getDateFrom_us(now)
    local beg = now - last * 1e6;

    if self._man then   -- has setup
        if self.cffi.check_pman_date(self._man, date) == 1 then  -- at the same day
            return self:query(beg, now, ms)
        else
            self:_del_()   -- destroy old manager
            if self:_setupRead(now) ~= 0 then    -- try to create new
                return ms
            else
                return self:query(beg, now, ms)
            end
        end
    else
        if self:_setupRead(now) ~= 0 then    -- try to create new
            return ms
        else
            return self:query(beg, now, ms)
        end
    end
end

function CfoxTSDB:qDay(start, stop, ms, tbls, budget)
    if self._man then
        self:_del_()
    end

    if self:_setupRead(start) ~= 0 then
        return {}
    end

    budget = budget or self._qBudget
    self:curMove(start)
    local inc = false
    for line in self:loadData(stop) do
        inc = false
        local time = line.time
        for _, v in ipairs(line.lines) do
            local title = v.line
            if not tbls or system:valueIsIn(tbls, title) then
                local tCell = {time = string.format("%d", time), title = title}

                local labels = {}
                if v.ls then
                    for _, vlabel in ipairs(v.ls) do
                        labels[vlabel.name] = vlabel.index
                    end
                end
                tCell.labels = labels

                local values = {}
                if v.vs then
                    for _, vvalue in ipairs(v.vs) do
                        values[vvalue.name] = vvalue.value
                    end
                end
                tCell.values = values

                local logs = {}
                if v.log then
                    for _, log in ipairs(v.log) do
                        logs[log.name] = log.log
                    end
                end
                tCell.logs = logs

                table.insert(ms, tCell)
                inc = true
            end
        end

        if inc then
            budget = budget - 1
        end
        if budget == 0 then   -- max len
            break
        end
    end
    return ms
end

function CfoxTSDB:qDayTables(start, stop, tbls)
    if self._man then
        self:_del_()
    end

    if self:_setupRead(start) ~= 0 then
        return {}
    end

    self:curMove(start)
    for line in self:loadData(stop) do
        for _, v in ipairs(line.lines) do
            local title = v.line
            if not system:valueIsIn(tbls, title) then
                table.insert(tbls, title)
            end
        end
    end
    return tbls
end

function CfoxTSDB:qDate(dStart, dStop, tbls)
    local now = self:makeStamp(dStop)
    local beg = self:makeStamp(dStart)

    if now - beg > 24 * 60 * 60 * 1e6 then
        return {}
    end

    local ms = {}
    if self.cffi.check_foxdate(dStart, dStop) ~= 0 then
        self:qDay(beg, now, ms, tbls)
    else
        local beg1 = beg
        local beg2 = self.cffi.make_stamp(dStop)
        local now1 = beg2 - 1
        local now2 = now

        self:qDay(beg1, now1, ms, tbls)
        local budget = self._qBudget - #ms
        if budget > 0 then
            self:qDay(beg2, now2, ms, tbls, budget)
        end
    end
    return ms
end

function CfoxTSDB:qNow(sec, tbls)
    if sec > 24 * 60 * 60 then
        return {}
    end
    local now = self:get_us()
    local beg = now - sec * 1e6 + 1

    local dStart = self:getDateFrom_us(beg)
    local dStop = self:getDateFrom_us(now)

    local ms = {}
    if self.cffi.check_foxdate(dStart, dStop) ~= 0 then
        self:qDay(beg, now, ms, tbls)
    else
        local beg1 = beg
        local beg2 = self.cffi.make_stamp(dStop)
        local now1 = beg2 - 1
        local now2 = now

        self:qDay(beg1, now1, ms, tbls)
        local budget = self._qBudget - #ms
        if budget > 0 then
            self:qDay(beg2, now2, ms, tbls, budget)
        end
    end
    return ms
end

function CfoxTSDB:qTabelNow(sec)
    if sec > 24 * 60 * 60 then
        return {}
    end
    local now = self:get_us()
    local beg = now - sec * 1e6 + 1

    local dStart = self:getDateFrom_us(beg)
    local dStop = self:getDateFrom_us(now)

    local tbls = {}
    if self.cffi.check_foxdate(dStart, dStop) ~= 0 then
        self:qDayTables(beg, now, tbls)
    else
        local beg1 = beg
        local beg2 = self.cffi.make_stamp(dStop)
        local now1 = beg2 - 1
        local now2 = now

        self:qDayTables(beg1, now1, tbls)
        self:qDayTables(beg2, now2, tbls)
    end
    return tbls
end

return CfoxTSDB
