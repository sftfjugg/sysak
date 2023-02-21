---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/2/3 2:14 PM
---

require("common.class")
local system = require("common.system")

local CslsProto = class("CslsProto")

function CslsProto:_init_()
    self._pb = require("sls_pb")
end

function CslsProto:pack(lines)
    local logList = self._pb.LogGroupList()
    for _, line in ipairs(lines.logGroupList) do
        local log = logList.logGroupList:add()

        if line.Reserved then
            log.Reserved = line.Reserved
        end
        if line.Topic then
            log.Topic = line.Topic
        end
        if line.Source then
            log.Source = line.Source
        end

        if line.Logs then
            for _, l_log in ipairs(line.Logs) do
                local cell = log.Logs:add()
                cell.Time = l_log.Time
                for _, l_con in ipairs(l_log.Contents) do
                    local con = cell.Contents:add()
                    con.Key = l_con.Key
                    con.Value = l_con.Value
                end
            end
        end

        if line.LogTags then
            for _, l_tag in ipairs(line.LogTags) do
                local tag = log.LogTags:add()
                tag.Key = l_tag.Key
                tag.Value = l_tag.Value
            end
        end
    end
    return logList:SerializeToString()
end

return CslsProto