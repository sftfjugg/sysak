---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/3/10 11:50 PM
---

package.path = package.path .. ";../../?.lua;"

local ChttpCli = require("httplib.httpCli")
local system = require("common.system")

local cli = ChttpCli.new()
local res = cli:get("http://127.0.0.1:10255/pods")
local obj = cli:jdecode(res.body)
print(system:dump(obj.items))
