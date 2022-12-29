---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/25 11:19 AM
---

local pystring = require("pystring")
require("class")
local ChttpHtml = require("httpHtml")

local CurlExportHtml = class("CurlExportHtml", ChttpHtml)

function CurlExportHtml:_init_(frame, export)
    ChttpHtml._init_(self)
    self._export = export

    self._urlCb["/export"] = function(tReq) return self:show(tReq)  end
    self:_install(frame)
end

function CurlExportHtml:show(tReq)
    local res = {title="Beaver Exporter"}
    local content = self._export:export()
    local contents = {
        "<pre style=\"word-wrap: break-word; white-space: pre-wrap;\">",
        content,
        '</pre>'
    }
    res.content = pystring:join("\n", contents)
    return res
end

return CurlExportHtml