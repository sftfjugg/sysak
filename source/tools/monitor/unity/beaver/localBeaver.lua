---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/14 3:14 PM
---

local unistd = require("posix.unistd")
local socket = require("posix.sys.socket")
local system = require("common.system")
require("common.class")

local CLocalBeaver = class("poBeaver")

local function setupServer(fYaml)
    local res = system:parseYaml(fYaml)
    local config = res.config
    local port = config["port"] or 8400
    local ip = config["bind_addr"] or "0.0.0.0"
    local backlog = config["backlog"] or 32
    local unix_socket = config["unix_socket"]
    return port, ip, backlog,unix_socket
end

function CLocalBeaver:_init_(frame, fYaml)
    local port, ip, backlog, unix_socket = setupServer(fYaml)
    if not unix_socket then
        self._bfd = self:_install_fd(port, ip, backlog)
    else
        self._bfd = self:_install_fd_unisock(backlog, unix_socket)
    end
    self._efd = self:_installFFI()

    self._cos = {}
    self._last = os.time()
    self._tmos = {}

    self._once = true
    self._frame = frame
end

function CLocalBeaver:_del_()
    for fd in pairs(self._cos) do
        socket.shutdown(fd, socket.SHUT_RDWR)
        local res = self._cffi.del_fd(self._efd, fd)
        print("close fd: " .. fd)
        assert(res >= 0)
    end

    if self._efd then
        self._cffi.deinit(self._efd)
    end
    if self._bfd then
        unistd.close(self._bfd)
    end
end

function CLocalBeaver:_installTmo(fd)
    self._tmos[fd] = os.time()
end

function CLocalBeaver:_checkTmo()
    local now = os.time()
    if now - self._last >= 30 then
        -- ! coroutine will del self._tmos cell in loop, so create a mirror table for safety
        local tmos = system:dictCopy(self._tmos)
        for fd, t in pairs(tmos) do
            if now - t >= 10 * 60 then
                local e = self._ffi.new("native_event_t")
                e.ev_close = 1
                e.fd = fd
                local co = self._cos[fd]
                print("close " .. fd)
                coroutine.resume(co, e)
            end
        end
        self._last = now
    end
end

function CLocalBeaver:_installFFI()
    local ffi = require("beaver.native.beavercffi")

    self._ffi = ffi.ffi
    self._cffi = ffi.cffi

    local efd = self._cffi.init(self._bfd)
    assert(efd > 0)
    return efd
end

local function localBind(fd, tPort)
    local try = 0
    local res, err, errno

    -- can reuse for time wait socket.
    res, err, errno = socket.setsockopt(fd, socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    if not res then
        system:posixError("set sock opt failed.");
    end

    while try < 120 do
        res, err, errno = socket.bind(fd, tPort)
        if res then
            return 0
        elseif errno == 98 then  -- port  already in use? try 30s;
            unistd.sleep(1)
            try = try + 1
        else
            break
        end
    end
    system:posixError(string.format("bind port %d failed.", tPort.port), err, errno)
end

function CLocalBeaver:_install_fd_unisock(backlog,unix_socket)
    local fd, res, err, errno
    unistd.unlink(unix_socket)
    fd, err, errno = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM, 0)
    if fd then  -- for socket
        local tPort = {family=socket.AF_UNIX, path=unix_socket}
        local r, msg = pcall(localBind, fd, tPort)
        if r then
            res, err, errno = socket.listen(fd, backlog)
            if res then -- for listen
                return fd
            else
                unistd.close(fd)
                system:posixError("socket listen failed", err, errno)
            end
        else
            print(msg)
            unistd.close(fd)
            os.exit(1)
        end
    else  -- socket failed
        system:posixError("create socket failed", err, errno)
    end
end

function CLocalBeaver:_install_fd(port, ip, backlog)
    local fd, res, err, errno
    fd, err, errno = socket.socket(socket.AF_INET, socket.SOCK_STREAM, 0)
    if fd then  -- for socket
        local tPort = {family=socket.AF_INET, addr=ip, port=port}
        local r, msg = pcall(localBind, fd, tPort)
        if r then
            res, err, errno = socket.listen(fd, backlog)
            if res then -- for listen
                return fd
            else
                unistd.close(fd)
                system:posixError("socket listen failed", err, errno)
            end
        else
            print(msg)
            unistd.close(fd)
            os.exit(1)
        end
    else  -- socket failed
        system:posixError("create socket failed", err, errno)
    end
end

function CLocalBeaver:read(fd, maxLen)
    maxLen = maxLen or 1 * 1024 * 1024  -- signal conversation accept 1M stream max
    local function readFd()
        local e = coroutine.yield()
        if e.ev_close > 0 then
            return nil
        elseif e.ev_in > 0 then
            local s, err, errno
            s, err, errno = socket.recv(fd, maxLen)
            if s then
                if #s > 0 then
                    maxLen = maxLen - #s
                    return s
                else
                    return nil
                end
            else
                system:posixError("socket recv error", err, errno)
            end
        else
            print(system:dump(e))
        end
        return nil
    end
    return readFd
end

function CLocalBeaver:write(fd, stream)
    local sent, err, errno
    local res

    sent, err, errno = socket.send(fd, stream)
    if sent then
        if sent < #stream then  -- send buffer may full
            res = self._cffi.mod_fd(self._efd, fd, 1)  -- epoll write ev
            assert(res == 0)

            while sent < #stream do
                local e = coroutine.yield()
                if e.ev_close > 0 then
                    return nil
                elseif e.ev_out then
                    stream = string.sub(stream, sent + 1)
                    sent, err, errno = socket.send(fd, stream)
                    if sent == nil then
                        if errno == 11 then  -- EAGAIN ?
                            goto continue
                        end
                        system:posixError("socket send error.", err, errno)
                        return nil
                    end
                else  -- need to read ? may something error or closed.
                    return nil
                end
                ::continue::
            end
            res = self._cffi.mod_fd(self._efd, fd, 0)  -- epoll read ev only
            assert(res == 0)
        end
        return 1
    else
        system:posixError("socket send error.", err, errno)
        return nil
    end
end

function CLocalBeaver:_proc(fd)
    local fread = self:read(fd)
    while true do
        local res, alive = self._frame:proc(fread)
        if res then
            local stat = self:write(fd, res)

            if not alive or not stat then
                self:co_exit(fd)
                break
            end
        else
            self:co_exit(fd)
            break
        end
    end
end

function CLocalBeaver:co_add(fd)
    local res = self._cffi.add_fd(self._efd, fd)
    assert(res >= 0)

    local co = coroutine.create(function(o, fd)  self._proc(o, fd) end)
    self._cos[fd] = co
    local res, msg = coroutine.resume(co, self, fd)
    assert(res, msg)
end

function CLocalBeaver:co_exit(fd)
    local res = self._cffi.del_fd(self._efd, fd)
    assert(res >= 0)

    self._cos[fd] = nil
    self._tmos[fd] = nil
end

function CLocalBeaver:accept(fd, e)
    if e.ev_close > 0 then
        error("should close bind fd.")
    else
        local nfd, err, errno = socket.accept(fd)
        if nfd then
            self:co_add(nfd)
            self:_installTmo(nfd)
        else
            system:posixError("accept new socket failed", err, errno)
        end
    end
end

function CLocalBeaver:_pollFd(bfd, nes)
    for i = 0, nes.num - 1 do
        local e = nes.evs[i];
        local fd = e.fd
        if fd == bfd then
            self:accept(fd, e)
        else
            local co = self._cos[fd]
            assert(co, string.format("fd: %d not setup.", fd))
            self:_installTmo(fd)
            local res, msg = coroutine.resume(co, e)
            assert(res, msg)
        end
    end
    self:_checkTmo()
end

function CLocalBeaver:_poll()
    local bfd = self._bfd
    local efd = self._efd
    while true do
        local nes = self._ffi.new("native_events_t")
        local res = self._cffi.poll_fds(efd, 10, nes)

        if res < 0 then
            return "end poll."
        end

        self:_pollFd(bfd, nes)
    end
end

function CLocalBeaver:poll()
    assert(self._once, "poll loop only run once time.")
    self._once = false

    local _, msg = pcall(self._poll, self)
    print(msg)

    return 0
end

return CLocalBeaver
