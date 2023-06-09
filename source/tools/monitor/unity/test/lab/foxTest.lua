---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/31 4:52 PM
---

package.path = package.path .. ";../../common/?.lua;"
package.path = package.path .. ";../../tsdb/?.lua;"
package.path = package.path .. ";./native/?.lua;"

local system = require("system")

local CfoxTSDB = require("foxTSDB")

local fox = CfoxTSDB.new()

local line = {
    lines = {
        {
            line = "metric1",
            ls = {
                { name = "title", index = "hello" }
            },
            vs = {
                { name = "value", value = 3.3 },
                { name = "cut", value = 3.4 }
            }
        },
        {
            line = "metric2",
            vs = {
                { name = "value", value = 3.3 },
                { name = "cut", value = 3.4 }
            },
            log = {
                { name = "hello", log = "world." },
            }
        },
    }
}

function test()

    local s1 = "2022-12-17 11:13:00"

    local foxTime = fox:str2date(s1)
    assert(foxTime.year == 2022 - 1900)
    assert(foxTime.mon == 12 - 1)
    assert(foxTime.mday == 17)
    assert(foxTime.hour == 11)
    assert(foxTime.min == 13)
    assert(foxTime.sec == 0)

    local sCheck = fox:date2str(foxTime)
    assert(s1 == sCheck)

    line.lines[1].vs[1].value = line.lines[1].vs[1].value + 1
    line.lines[2].vs[2].value = line.lines[2].vs[2].value + 3
    local res = fox:packLine(line)
    assert(string.len(res) > 0)

    local ret = fox:setupWrite()
    assert(ret == 0)
    --fox:write(res)
    print("write.")
end

print("load ok.")
