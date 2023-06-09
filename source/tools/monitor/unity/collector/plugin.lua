---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/30 10:20 AM
---

require("common.class")
local system = require("common.system")
local Cplugin = class("plugin")

function Cplugin:_init_(proto, procffi, que, proto_q, fYaml)
    self._proto = proto

    local res = system:parseYaml(fYaml)
    self:setProcSys(procffi, res.config)

    self._sig_cffi = procffi["cffi"]
    self._sig_cffi.plugin_init()

    self._ffi = require("collector.native.plugincffi")
    self:setup(res.plugins, proto_q)
end

function Cplugin:_del_()
    self._sig_cffi.plugin_stop()
    for _, plugin in ipairs(self._plugins) do
        local cffi = plugin.cffi
        cffi.deinit()
    end
end

function Cplugin:setProcSys(procFFI, config)
    local proc = config["proc_path"] or "/"
    local sys = config["sys_path"] or "/"

    procFFI.cffi.set_unity_proc(procFFI.ffi.string(proc))
    procFFI.cffi.set_unity_sys(procFFI.ffi.string(sys))
end

function Cplugin:setup(plugins, proto_q)
    self._plugins = {}
    for _, plugin in ipairs(plugins) do
        local so = plugin.so
        if so then
            print(so)
            local cffi = self._ffi.load(so)
            local plugin = {
                so = plugin.so,
                cffi = cffi
            }
            cffi.init(proto_q);
            table.insert(self._plugins, plugin)
        end
    end
end

function Cplugin:load_label(unity_line, line)
    local c = #line.ls
    for i=0, 4 - 1 do
        local name = self._ffi.string(unity_line.indexs[i].name)
        local index = self._ffi.string(unity_line.indexs[i].index)

        if #name > 0 then
            c = c + 1
            line.ls[c] = {name = name, index = index}
        else
            return
        end
    end
end

function Cplugin:load_value(unity_line, line)
    local c = #line.vs
    for i=0, 32 - 1 do
        local name = self._ffi.string(unity_line.values[i].name)
        local value = unity_line.values[i].value

        if #name > 0 then
            c = c + 1
            line.vs[c] = {name = name, value = value}
        else
            return
        end
    end
end

function Cplugin:load_log(unity_line, line)
    local name = self._ffi.string(unity_line.logs[0].name)
    if #name > 0 then
        local log = self._ffi.string(unity_line.logs[0].log)
        self._ffi.C.free(unity_line.logs[0].log)   -- should free from strdup
        table.insert(line.log, {name = name, log = log})
    end
end

function Cplugin:_proc(unity_lines, lines)
    local c = #lines["lines"]
    for i=0, unity_lines.num - 1 do
        local unity_line = unity_lines.line[i]
        local line = {line = self._ffi.string(unity_line.table),
                      ls = {},
                      vs = {},
                      log = {}}

        self:load_label(unity_line, line)
        self:load_value(unity_line, line)
        self:load_log(unity_line, line)
        c = c + 1
        lines["lines"][c] = line
    end
end

function Cplugin:proc(t, lines)
    for _, plugin in ipairs(self._plugins) do
        local cffi = plugin.cffi
        local unity_lines = self._ffi.new("struct unity_lines")
        local res = cffi.call(t, unity_lines)
        if res == 0 then
            self:_proc(unity_lines, lines)
        end
        self._ffi.C.free(unity_lines.line)   -- should free memory.
    end
    return lines
end

return Cplugin
