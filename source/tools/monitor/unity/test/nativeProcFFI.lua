---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2022/12/16 9:42 PM
---

package.path = package.path .. ";../common/?.lua;"
package.path = package.path .. ";../collector/native/?.lua;"

local procFFI = require("procffi")

print("test for var_input_long")
local line = " 300    400 0 "
local data = procFFI.ffi.new("var_long_t")
assert(procFFI.cffi.var_input_long(procFFI.ffi.string(line), data) == 0)
assert(data.no == 3)
assert(data.value[0] == 300)
assert(data.value[1] == 400)
assert(data.value[2] == 0)
assert(procFFI.cffi.var_input_long(procFFI.ffi.string(""), data) == 0)
line = "0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9"
data = procFFI.ffi.new("var_long_t")
assert(procFFI.cffi.var_input_long(procFFI.ffi.string(line), data) == 0)
assert(data.no == 64)
assert(data.value[0] == 0)
assert(data.value[10] == 0)

print("test for var_input_kvs")
local line = " cpu  12110452 0 13242501 191691355 604 0 566813 0   0 0"
local data = procFFI.ffi.new("var_kvs_t")
assert(procFFI.cffi.var_input_kvs(procFFI.ffi.string(line), data) == 0)
assert(procFFI.ffi.string(data.s) == "cpu")
assert(data.no == 10)
assert(data.value[0]== 12110452)
assert(data.value[1]== 0)
assert(data.value[3]== 191691355)
line = "0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9"
data = procFFI.ffi.new("var_kvs_t")
assert(procFFI.cffi.var_input_kvs(procFFI.ffi.string(line), data) == 0)
assert(procFFI.ffi.string(data.s) == "0")
assert(data.no == 64)
assert(data.value[0] == 1)
assert(data.value[10] == 1)

print("test for var_input_string")
local line = "Ip: Forwarding DefaultTTL InReceives InHdrErrors InAddrErrors ForwDatagrams InUnknownProtos InDiscards InDelivers OutRequests OutDiscards OutNoRoutes ReasmTimeout ReasmReqds ReasmOKs ReasmFails FragOKs FragFails FragCreates"
local data = procFFI.ffi.new("var_string_t")
assert(procFFI.cffi.var_input_string(procFFI.ffi.string(line), data) == 0)
assert(data.no == 20)
assert(procFFI.ffi.string(data.s[0]) == "Ip:")
assert(procFFI.ffi.string(data.s[1]) == "Forwarding")
assert(procFFI.ffi.string(data.s[3]) == "InReceives")
assert(procFFI.ffi.string(data.s[19]) == "FragCreates")
line = "0123456789012345678901234567890123456789 123"   -- for long line.
data = procFFI.ffi.new("var_string_t")
assert(procFFI.cffi.var_input_string(procFFI.ffi.string(line), data) == 0)
assert(data.no == 2)
assert(procFFI.ffi.string(data.s[0]) == "0123456789012345678901234567890")
assert(procFFI.ffi.string(data.s[1]) == "123")

line = "0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9"
data = procFFI.ffi.new("var_string_t")
assert(procFFI.cffi.var_input_string(procFFI.ffi.string(line), data) == 0)
assert(data.no == 64)
assert(procFFI.ffi.string(data.s[0]) == "0")
assert(procFFI.ffi.string(data.s[10]) == "0")

print("test ok.")