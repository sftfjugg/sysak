---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by liaozhaoyan.
--- DateTime: 2023/1/29 11:01 PM
---
-- should ln -s liblz4.so.1 liblz4.so at first


package.path = package.path .. ";../../common/?.lua;"

local lz4 = require("lz4")
local s = "hello lz4, hello lz4, hello lz4, hello lz4, hello lz4, hello lz4"
local cmp = lz4.compress(s)
print(#s, #cmp)
local data = "hello lz4"
local errmsg, compressed_data, decompressed_data
compressed_data, errmsg = lz4.compress(data)
decompressed_data, errmsg = lz4.decompress(compressed_data)
assert(decompressed_data == data)
print("lz4 test ok.")
