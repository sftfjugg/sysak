---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/17 11:04 AM
---

require("class")
local system = require("system")
local snappy = require("snappy")
local pystring = require("pystring")
local CprotoData = require("protoData")
local foxFFI = require("foxffi")

local CfoxTSDB = class("CfoxTSDB")

function CfoxTSDB:_init_()
    self.ffi = foxFFI.ffi
    self.cffi = foxFFI.cffi
    self._proto = CprotoData.new(nil)
    print("this is a test module.")
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
    assert(self.cffi.fox_write(self._man, date, now, self.ffi.string(stream, #stream), #stream) == 0)
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
                print("end of file.")
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

            local logs = {}
            if v.vlog then
                for _, vlog in ipairs(v.log) do
                    logs[vlog.name] = vlog.log
                end
            end
            tCell.logs = logs

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
        if self.cffi.check_pman_date(self._man, date) then  -- at the same day
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

return CfoxTSDB
