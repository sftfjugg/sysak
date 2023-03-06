---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/27 11:41 PM
---

require("common.class")
local system = require("common.system")
local CfoxTSDB = require("tsdb.foxTSDB")
local ChttpHtml = require("httplib.httpHtml")

local CbaseQuery = class("baseQuery", ChttpHtml)

function CbaseQuery:_init_(frame, fYaml)
    ChttpHtml._init_(self)
    self._urlCb["/query/base"] = function(tReq) return self:base(tReq) end
    self._urlCb["/query/baseQ"] = function(tReq) return self:baseQ(tReq) end
    self._fox = CfoxTSDB.new(fYaml)
    self:_install(frame)
end

local function packForm1(forms)
    forms[1] = '<form action="/query/baseQ" method="GET">'
end

local function packForm2(forms)
    table.insert(forms, '<input type="submit" value="提交">\n</form>')
end

local function packTimeFormat(forms, session)
    session.gmt = session.gmt or "0"
    table.insert(forms, '<label>时间格式:</label>')
    if session.gmt == '1' then
        table.insert(forms, '<input type="radio" name="gmt" id="" value="1" checked>GMT 时间')
        table.insert(forms, '<input type="radio" name="gmt" id="" value="0">本地时间')
    else
        table.insert(forms, '<input type="radio" name="gmt" id="" value="1">GMT 时间')
        table.insert(forms, '<input type="radio" name="gmt" id="" value="0" checked>本地时间')
    end
    table.insert(forms, '<br>')
end

local formTableHead = [[
        <label>表选择：</label>
        <select id="selTable" name="selTable">
]]
local formTableEnd = [[
</select>
<br>
]]
local function packTables(forms, session, tables)
    session.selTable = session.selTable or tables[1]
    table.insert(forms, formTableHead)
    local len = #forms
    for i, tbl in ipairs(tables) do
        if tbl == session.selTable then
            forms[i + len] = string.format('<option value="%s" selected="selected">%s</option>', tbl, tbl)
        else
            forms[i + len] = string.format('<option value="%s">%s</option>', tbl, tbl)
        end
    end
    table.insert(forms, formTableEnd)
end

local formTLHead = [[
<label>查询时长：</label>
<select id="tables" name="timeLen">
]]
local formTLEnd = [[
</select>
<br>
]]
local formTLIndex = {'5', '10', '20', '30', '60', '120', '240', '720', '1440'}
local formTLKV = {
    ["5"] = "5m", ["10"] = "10m", ["20"] = "20m", ["30"] = "30m", ["60"] = "1h",
    ["120"] = "2h", ["240"] = "4h", ["720"] = "6h", ["1440"] = "24h",
}
local function packTimeLen(forms, session)
    session.timeLen = session.timeLen or "30"
    table.insert(forms, formTLHead)
    for _, k in ipairs(formTLIndex) do
        if k == session.timeLen then
            table.insert(forms, string.format('<option value="%s" selected="selected">%s</option>', k, formTLKV[k]))
        else
            table.insert(forms, string.format('<option value="%s">%s</option>', k, formTLKV[k]))
        end
    end
    table.insert(forms, formTLEnd)
end

local function packForm(session, tables)
    local forms = {}
    packForm1(forms)
    packTimeFormat(forms, session)
    packTables(forms, session, tables)
    packTimeLen(forms, session)
    packForm2(forms)
    return table.concat(forms, "\n")
end

function CbaseQuery:qTables(session, fresh)
    fresh = fresh or false
    local t = session.qlast or 4 * 60
    if session.tables == nil or fresh then
        session.tables = self._fox:qTabelNow(t * 60)
    end
end

function CbaseQuery:base(tReq)
    local res = {title="Beaver Query"}
    self:qTables(tReq.session)
    res.content = packForm(tReq.session, tReq.session.tables)
    return res
end

function CbaseQuery:setSession(queries, session)
    if queries.selTable then
        session.selTable = queries.selTable
        session.gmt = queries.gmt
        session.timeLen = queries.timeLen
    end
end

local function escape(s)
    if type(s) == "string" then
        s = system:escHtml(s)
        return system:escMd(s)
    end
    return "None"
end
local function packDataHead(res, labels, values, logs)
    local heads = system:listMerge({"time"}, labels, values, logs)
    local show_head = {}
    for i, v in ipairs(heads) do
        show_head[i] = escape(v)
    end
    table.insert(res, table.concat({"| ", table.concat(show_head, " | "), " |"}))

    local aligns = {}
    table.insert(aligns, "---:")   -- for time align left
    for _, _ in ipairs(labels) do
        table.insert(aligns, ":---")   -- for labels align right
    end
    for _, _ in ipairs(values) do
        table.insert(aligns, ":---:")   -- for values align center
    end
    for _, _ in ipairs(logs) do
        table.insert(aligns, ":---")   -- for values align right
    end
    table.insert(res, table.concat({"| ", table.concat(aligns, " | "), " |"}))
end


local function packDataBody(res, fmt, ms, labels, values, logs)
    local len = #res
    for i, m in ipairs(ms) do
        local datas = {}
        local ii = 1
        if fmt then
            datas[ii] = os.date("!%x %X", tonumber(m.time) / 1000000)
        else
            datas[ii] = os.date("%x %X", tonumber(m.time) / 1000000)
        end
        ii = ii + 1

        for _, k in ipairs(labels) do
            datas[ii] = escape(m.labels[k])
            ii = ii + 1
        end
        for _, k in ipairs(values) do
            local v = m.values[k]
            if v then
                datas[ii] = string.format("%7.2f", m.values[k])
            else
                datas[ii] = "None"
            end
            ii = ii + 1
        end
        for _, k in ipairs(logs) do
            datas[ii] = escape(m.logs[k])
            ii = ii + 1
        end
        local data = table.concat({"| ", table.concat(datas, " | "), " |"})
        res[len + i] = data
    end
end

local function packDataTabel(res, ms, tFmt)
    if #ms > 0 then
        local fmt = false
        if tFmt == "1" then
            fmt = true
        end

        local labels, values, logs = {}, {}, {}
        for k, _ in pairs(ms[1].labels) do
            table.insert(labels, k)
        end
        for k, _ in pairs(ms[1].values) do
            table.insert(values, k)
        end
        for k, _ in pairs(ms[1].logs) do
            table.insert(logs, k)
        end
        packDataHead(res, labels, values, logs)
        packDataBody(res, fmt, ms, labels, values, logs)
    end
end

function CbaseQuery:baseQ(tReq)
    local res = {title="Beaver Query"}
    local contents = {}
    local session = tReq.session

    if tReq.queries then
        self:setSession(tReq.queries, session)
    end

    if session.selTable == nil then
        contents[1] = "查询表未设置，将跳转会设置页面."
        contents[2] = '<meta http-equiv="refresh" content="3;url=/query/base" >'
        res.content = table.concat(contents, "\n")
        return res
    end

    local ms = self._fox:qNow(tonumber(session.timeLen) * 60,
                            {session.selTable})
    table.insert(contents, "# 反馈输入\n")
    table.insert(contents, "* 表名: " .. system:escMd(session.selTable))
    table.insert(contents, "* 时间戳: " .. session.gmt)
    table.insert(contents, "* 时长: " .. session.timeLen)
    table.insert(contents, "\n")

    table.insert(contents, "# 显示表格\n")

    packDataTabel(contents, ms, session.gmt)

    table.insert(contents, "[返回](/query/base)")
    table.insert(contents, "[刷新](/query/baseQ)")

    res.content = self:markdown(table.concat(contents, "\n"))
    return res
end

return CbaseQuery
