---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/21 11:44 AM
---

package.path = package.path .. ";../?.lua;"

local Cframe = require("beaver.frame")
local CurlApi = require("beaver.url_api")
local CurlRpc = require("beaver.url_rpc")
local CurlIndex = require("beaver.index")
local Cexport = require("beaver.export")
local CurlGuide = require("beaver.url_guide")
local CurlExportHtml = require("beaver.url_export_html")
local CurlExportRaw = require("beaver.url_export_raw")
local CLocalBeaver = require("beaver.localBeaver")

local lb = nil

function init(fYaml)
    fYaml = fYaml or "../collector/plugin.yaml"
    print(fYaml)
    local web = Cframe.new()

    CurlIndex.new(web)
    CurlApi.new(web)
    CurlRpc.new(web)
    CurlGuide.new(web)

    local Cidentity = require("beaver.identity")
    local inst = Cidentity.new(fYaml)
    local export = Cexport.new(inst:id(), fYaml)
    CurlExportHtml.new(web, export)
    CurlExportRaw.new(web, export)

    lb = CLocalBeaver.new(web, fYaml)
    return 0
end

function echo()
    lb:poll()
    return 0
end
