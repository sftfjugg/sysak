---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/13 7:26 PM
---

local bit = require("bit")
local fcntl = require("posix.fcntl")
local poll = require("posix.poll")
local unistd = require("posix.unistd")
local socket = require("posix.sys.socket")
local system = require("common.system")
require("common.class")

local CpoBeaver = class("poBeaver")

function CpoBeaver:_init_(port, ip, backlog)
    port = port or 8398
    self._server = self:_install_fd(port, ip, backlog)

    self._fds = {}
    self._cos = {}

    self:_install_ev(self._server)
end

function CpoBeaver:_del_()
    for fd in pairs(self._fds) do
        unistd.close(fd)
    end
end

local function posixError(msg, err, errno)
    local s = msg .. string.format(": %s, errno: %d", err, errno)
    error(s)
end

function CpoBeaver:_install_ev(fd)
    self._fds[fd] = {events={IN=true, HUP=true, ERR=true, NVAL=true}}
end

function CpoBeaver:_install_fd(port, ip, backlog)
    ip = ip or "0.0.0.0"
    backlog = backlog or 100

    local fd, res, err, errno
    fd, err, errno = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
    if fd then  -- for socket
        res, err, errno = socket.bind(fd, {family=socket.AF_INET, addr=ip, port=port})
        if res then  -- for bind
            res, err, errno = socket.listen(fd, backlog)
            if res then -- for listen
                return fd
            else
                posixError("socket listen failed", err, errno)
            end
        else   -- for bind failed
            unistd.close(fd)
            posixError("socket bind failed", err, errno)
        end
    else  -- socket failed
        posixError("create socket failed", err, errno)
    end
end

local function fdNonBlocking(fd)
    local res, err, errno
    local flag, err, errno = fcntl.fcntl(fd, fcntl.F_GETFL)
    if flag then
        res, err, errno = fcntl.fcntl(fd, fcntl.F_SETFL, bit.bor(flag, fcntl.O_NONBLOCK))
        if res then
            return 0
        else
            posixError("fcntl set failed", err, errno)
        end
    else
        posixError("fcntl get failed", err, errno)
    end
end


function CpoBeaver:read(fd, maxLen)
    maxLen = maxLen or 1 * 1024 * 1024  -- signal conversation accept 1M stream max
    local function readFd()
        local e = coroutine.yield()
        if e.HUP or e.ERR or e.NVAL then
            return nil
        elseif e.IN then
            local s, err, errno
            s, err, errno = socket.recv(fd, maxLen)
            if s then
                maxLen = maxLen - #s
                return s
            else
                posixError("socket recv error", err, errno)
            end
        else
            print(system:dump(e))
        end
        return nil
    end
    return readFd
end

function CpoBeaver:co_exit(fd)
    unistd.close(fd)
    self._cos[fd] = nil
    self._fds[fd] = nil
end

function CpoBeaver:co_add(fd)
    self:_install_ev(fd)
    local co = coroutine.create(function(o, fd)  self._proc(o, fd) end)
    self._cos[fd] = co
    coroutine.resume(co, self, fd)
end

function CpoBeaver:_readStream(fd)
    local sockRead = self:read(fd)
    local res = ""
    while true do
        local s = sockRead()
        if s then
            if #s > 0 then
                res = res .. s
                if string.find(res, "\r\n") then
                    return res
                end
            else
                return nil
            end
        else
            return nil
        end
    end
end

function CpoBeaver:_proc(fd)
    --print("open " .. fd)
    while true do
        local s = self:_readStream(fd)
        if s then
            socket.send(fd, "echo: " .. s)
        else
            --print("exit" .. fd)
            self:co_exit(fd)
            break
        end
    end
end

function CpoBeaver:checks(num)
    local fds = {}
    local cnt = 0
    local newEv = nil

    for fd, es in pairs(self._fds) do
        local e = es.revents
        if e.IN or e.HUP or e.ERR or e.NVAL then
            if fd == self._server then
                newEv = e
            else
                fds[fd] = e
            end
            cnt = cnt + 1
            if cnt >= num then
                break
            end
        end
    end
    return newEv, fds
end

function CpoBeaver:poll()
    local res, err, errno

    while true do
        res, err, errno = poll.poll(self._fds, 5 * 1000 * 1000)
        if res > 0 then
            local newEv, fds = self:checks(res)
            if newEv then  -- accept
                res = self:accept(self._server, newEv)
                if not res then  -- accept corrupt.
                    return nil
                end
            end

            for fd, e in pairs(fds) do   -- fd read.
                local co = self._cos[fd]
                if co then
                    coroutine.resume(co, e)
                end
            end
        elseif not res then -- for poll failed.
            posixError("poll failed.", err, errno)
        end
    end
end

function CpoBeaver:accept(fd, e)
    if e.HUP or e.ERR then
        return nil
    elseif e.IN then
        local nfd, err, errno = socket.accept(fd)
        if nfd then
            fdNonBlocking(nfd)
            self:co_add(nfd)
        else
            posixError("accept new socket failed", err, errno)
        end
    end
    return 0
end

return CpoBeaver
