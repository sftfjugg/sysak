---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/24 9:06 PM
---

require("common.class")
local unistd = require("posix.unistd")
local ChttpHtml = require("httplib.httpHtml")

local CurlIndex = class("CurlIndex", ChttpHtml)

function CurlIndex:_init_(frame)
    ChttpHtml._init_(self)
    self._urlCb["/"] = function(tReq) return self:show(tReq)  end
    self._urlCb["/index"] = function(tReq) return self:show(tReq)  end
    self._urlCb["/index.html"] = function(tReq) return self:show(tReq)  end
    self:_install(frame)
end

function CurlIndex:show(tReq)
    local content1 = [[
## welcome to visit SysAk Agent

&emsp;this Agent provides web services for [SysAk](https://gitee.com/anolis/sysak).

## About this agent.

### SysAk

&emsp;[SysAk](https://gitee.com/anolis/sysak) (System Analyse Kit) is a system operation and maintenance SIG in the Anolis community, which provides a comprehensive system operation and maintenance tool set by abstracting the experience of millions of servers in the past, which can cover common operation and maintenance scenarios such as daily monitoring of the system, online problem diagnosis and system fault repair. In terms of the overall design of the tool, it strives to make the operation and maintenance work simple, so that system operation and maintenance personnel do not need to understand the kernel to find out the problem. Problem Discussion: 31987277(DingDing)

### Coolbpf

&emsp;[Coolbpf](https://gitee.com/anolis/coolbpf) is implemented based on CORE (Compile Once--Run Everywhere), which retains the advantages of low resource occupation and strong portability, and also integrates the characteristics of BCC dynamic compilation. Coolbpf uses the idea of remote compilation to push the user's BPF program to a remote server and return .o or .so, providing python/rust/c high-level language loading. Users only focus on their own function development, and do not care about the installation of underlying libraries and environment construction.

### export

&emsp; for [web browser](/export)

&emsp; for [promethues](/export/metrics)

### code test

    #include <stdio.h>
    int main()
    {
        // printf() 中字符串需要引号
        printf("Hello, World!");
        return 0;
    }

### Tips

&emsp;This page is rendered directly via markdown, for [guide](/guide)
]]
    local content2 = string.format("\n&emsp;thread id is:%d\n", unistd.getpid())
    local title = "welcome to visit SysAk Agent server."
    return {title=title, content=self:markdown(content1 .. content2)}
end

return CurlIndex
