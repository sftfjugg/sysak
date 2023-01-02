---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/25 11:20 AM
---

local system = require("system")
local pystring = require("pystring")
local CfoxTSDB = require("foxTSDB")
require("class")

local Cexport = class("Cexport")

function Cexport:_init_(instance, fYaml)
    self._instance = instance
    fYaml = fYaml or "../beaver/export.yaml"
    local ms = self:_load(fYaml)
    self._tDescr = ms.metrics
    self._fox = CfoxTSDB.new()
    self._fox:_setupRead()
end

function Cexport:_load(fYaml)
    local lyaml = require("lyaml")
    local f = io.open(fYaml,"r")
    local s = f:read("*all")
    f:close()

    return lyaml.load(s)
end

local function qFormData(from, tData)
    local res = {}

    for _, line in ipairs(tData) do
        if from == line.title then
            table.insert(res, line)
        end
    end
    return res
end

local function packLine(title, ls, v)
    local tLs = {}
    for k, v in pairs(ls) do
        table.insert(tLs, string.format("%s=\"%s\"", k , v))
    end
    local lable = ""
    if #tLs then
        lable = pystring:join(",", tLs)
        lable = "{" .. lable .. "}"
    end
    return string.format("%s%s %.1f", title, lable, v)
end

function Cexport:export()
    local qs = {}
    self._fox:resize()
    self._fox:qlast(15, qs)
    local res = {}
    for _, line in ipairs(self._tDescr) do
        local from = line.from
        local tFroms = qFormData(from, qs)
        if #tFroms then
            local title = line.title
            local help = string.format("# HELP %s %s", title, line.help)
            table.insert(res, help)
            local sType = string.format("# TYPE %s %s", title, line.type)
            table.insert(res, sType)

            for _, tFrom in ipairs(tFroms) do
                local labels = system:deepcopy(tFrom.labels)
                if not labels then
                    labels = {}
                end
                labels.instance = self._instance
                for k, v in pairs(tFrom.values) do
                    labels[line.head] = k
                    table.insert(res, packLine(title, labels, v))
                end
            end
        end
    end
    local lines = pystring:join("\n", res)
    return lines
end

return Cexport
