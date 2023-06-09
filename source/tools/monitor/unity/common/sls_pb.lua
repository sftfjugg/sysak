-- Generated By protoc-gen-lua Do not Edit
local protobuf = require "protobuf"
module('sls_pb')


local LOG = protobuf.Descriptor();
local LOG_CONTENT = protobuf.Descriptor();
local LOG_CONTENT_KEY_FIELD = protobuf.FieldDescriptor();
local LOG_CONTENT_VALUE_FIELD = protobuf.FieldDescriptor();
local LOG_TIME_FIELD = protobuf.FieldDescriptor();
local LOG_CONTENTS_FIELD = protobuf.FieldDescriptor();
local LOGTAG = protobuf.Descriptor();
local LOGTAG_KEY_FIELD = protobuf.FieldDescriptor();
local LOGTAG_VALUE_FIELD = protobuf.FieldDescriptor();
local LOGGROUP = protobuf.Descriptor();
local LOGGROUP_LOGS_FIELD = protobuf.FieldDescriptor();
local LOGGROUP_RESERVED_FIELD = protobuf.FieldDescriptor();
local LOGGROUP_TOPIC_FIELD = protobuf.FieldDescriptor();
local LOGGROUP_SOURCE_FIELD = protobuf.FieldDescriptor();
local LOGGROUP_LOGTAGS_FIELD = protobuf.FieldDescriptor();
local LOGGROUPLIST = protobuf.Descriptor();
local LOGGROUPLIST_LOGGROUPLIST_FIELD = protobuf.FieldDescriptor();

LOG_CONTENT_KEY_FIELD.name = "Key"
LOG_CONTENT_KEY_FIELD.full_name = ".Log.Content.Key"
LOG_CONTENT_KEY_FIELD.number = 1
LOG_CONTENT_KEY_FIELD.index = 0
LOG_CONTENT_KEY_FIELD.label = 2
LOG_CONTENT_KEY_FIELD.has_default_value = false
LOG_CONTENT_KEY_FIELD.default_value = ""
LOG_CONTENT_KEY_FIELD.type = 9
LOG_CONTENT_KEY_FIELD.cpp_type = 9

LOG_CONTENT_VALUE_FIELD.name = "Value"
LOG_CONTENT_VALUE_FIELD.full_name = ".Log.Content.Value"
LOG_CONTENT_VALUE_FIELD.number = 2
LOG_CONTENT_VALUE_FIELD.index = 1
LOG_CONTENT_VALUE_FIELD.label = 2
LOG_CONTENT_VALUE_FIELD.has_default_value = false
LOG_CONTENT_VALUE_FIELD.default_value = ""
LOG_CONTENT_VALUE_FIELD.type = 9
LOG_CONTENT_VALUE_FIELD.cpp_type = 9

LOG_CONTENT.name = "Content"
LOG_CONTENT.full_name = ".Log.Content"
LOG_CONTENT.nested_types = {}
LOG_CONTENT.enum_types = {}
LOG_CONTENT.fields = {LOG_CONTENT_KEY_FIELD, LOG_CONTENT_VALUE_FIELD}
LOG_CONTENT.is_extendable = false
LOG_CONTENT.extensions = {}
LOG_CONTENT.containing_type = LOG
LOG_TIME_FIELD.name = "Time"
LOG_TIME_FIELD.full_name = ".Log.Time"
LOG_TIME_FIELD.number = 1
LOG_TIME_FIELD.index = 0
LOG_TIME_FIELD.label = 2
LOG_TIME_FIELD.has_default_value = false
LOG_TIME_FIELD.default_value = 0
LOG_TIME_FIELD.type = 13
LOG_TIME_FIELD.cpp_type = 3

LOG_CONTENTS_FIELD.name = "Contents"
LOG_CONTENTS_FIELD.full_name = ".Log.Contents"
LOG_CONTENTS_FIELD.number = 2
LOG_CONTENTS_FIELD.index = 1
LOG_CONTENTS_FIELD.label = 3
LOG_CONTENTS_FIELD.has_default_value = false
LOG_CONTENTS_FIELD.default_value = {}
LOG_CONTENTS_FIELD.message_type = LOG_CONTENT
LOG_CONTENTS_FIELD.type = 11
LOG_CONTENTS_FIELD.cpp_type = 10

LOG.name = "Log"
LOG.full_name = ".Log"
LOG.nested_types = {LOG_CONTENT}
LOG.enum_types = {}
LOG.fields = {LOG_TIME_FIELD, LOG_CONTENTS_FIELD}
LOG.is_extendable = false
LOG.extensions = {}
LOGTAG_KEY_FIELD.name = "Key"
LOGTAG_KEY_FIELD.full_name = ".LogTag.Key"
LOGTAG_KEY_FIELD.number = 1
LOGTAG_KEY_FIELD.index = 0
LOGTAG_KEY_FIELD.label = 2
LOGTAG_KEY_FIELD.has_default_value = false
LOGTAG_KEY_FIELD.default_value = ""
LOGTAG_KEY_FIELD.type = 9
LOGTAG_KEY_FIELD.cpp_type = 9

LOGTAG_VALUE_FIELD.name = "Value"
LOGTAG_VALUE_FIELD.full_name = ".LogTag.Value"
LOGTAG_VALUE_FIELD.number = 2
LOGTAG_VALUE_FIELD.index = 1
LOGTAG_VALUE_FIELD.label = 2
LOGTAG_VALUE_FIELD.has_default_value = false
LOGTAG_VALUE_FIELD.default_value = ""
LOGTAG_VALUE_FIELD.type = 9
LOGTAG_VALUE_FIELD.cpp_type = 9

LOGTAG.name = "LogTag"
LOGTAG.full_name = ".LogTag"
LOGTAG.nested_types = {}
LOGTAG.enum_types = {}
LOGTAG.fields = {LOGTAG_KEY_FIELD, LOGTAG_VALUE_FIELD}
LOGTAG.is_extendable = false
LOGTAG.extensions = {}
LOGGROUP_LOGS_FIELD.name = "Logs"
LOGGROUP_LOGS_FIELD.full_name = ".LogGroup.Logs"
LOGGROUP_LOGS_FIELD.number = 1
LOGGROUP_LOGS_FIELD.index = 0
LOGGROUP_LOGS_FIELD.label = 3
LOGGROUP_LOGS_FIELD.has_default_value = false
LOGGROUP_LOGS_FIELD.default_value = {}
LOGGROUP_LOGS_FIELD.message_type = LOG
LOGGROUP_LOGS_FIELD.type = 11
LOGGROUP_LOGS_FIELD.cpp_type = 10

LOGGROUP_RESERVED_FIELD.name = "Reserved"
LOGGROUP_RESERVED_FIELD.full_name = ".LogGroup.Reserved"
LOGGROUP_RESERVED_FIELD.number = 2
LOGGROUP_RESERVED_FIELD.index = 1
LOGGROUP_RESERVED_FIELD.label = 1
LOGGROUP_RESERVED_FIELD.has_default_value = false
LOGGROUP_RESERVED_FIELD.default_value = ""
LOGGROUP_RESERVED_FIELD.type = 9
LOGGROUP_RESERVED_FIELD.cpp_type = 9

LOGGROUP_TOPIC_FIELD.name = "Topic"
LOGGROUP_TOPIC_FIELD.full_name = ".LogGroup.Topic"
LOGGROUP_TOPIC_FIELD.number = 3
LOGGROUP_TOPIC_FIELD.index = 2
LOGGROUP_TOPIC_FIELD.label = 1
LOGGROUP_TOPIC_FIELD.has_default_value = false
LOGGROUP_TOPIC_FIELD.default_value = ""
LOGGROUP_TOPIC_FIELD.type = 9
LOGGROUP_TOPIC_FIELD.cpp_type = 9

LOGGROUP_SOURCE_FIELD.name = "Source"
LOGGROUP_SOURCE_FIELD.full_name = ".LogGroup.Source"
LOGGROUP_SOURCE_FIELD.number = 4
LOGGROUP_SOURCE_FIELD.index = 3
LOGGROUP_SOURCE_FIELD.label = 1
LOGGROUP_SOURCE_FIELD.has_default_value = false
LOGGROUP_SOURCE_FIELD.default_value = ""
LOGGROUP_SOURCE_FIELD.type = 9
LOGGROUP_SOURCE_FIELD.cpp_type = 9

LOGGROUP_LOGTAGS_FIELD.name = "LogTags"
LOGGROUP_LOGTAGS_FIELD.full_name = ".LogGroup.LogTags"
LOGGROUP_LOGTAGS_FIELD.number = 6
LOGGROUP_LOGTAGS_FIELD.index = 4
LOGGROUP_LOGTAGS_FIELD.label = 3
LOGGROUP_LOGTAGS_FIELD.has_default_value = false
LOGGROUP_LOGTAGS_FIELD.default_value = {}
LOGGROUP_LOGTAGS_FIELD.message_type = LOGTAG
LOGGROUP_LOGTAGS_FIELD.type = 11
LOGGROUP_LOGTAGS_FIELD.cpp_type = 10

LOGGROUP.name = "LogGroup"
LOGGROUP.full_name = ".LogGroup"
LOGGROUP.nested_types = {}
LOGGROUP.enum_types = {}
LOGGROUP.fields = {LOGGROUP_LOGS_FIELD, LOGGROUP_RESERVED_FIELD, LOGGROUP_TOPIC_FIELD, LOGGROUP_SOURCE_FIELD, LOGGROUP_LOGTAGS_FIELD}
LOGGROUP.is_extendable = false
LOGGROUP.extensions = {}
LOGGROUPLIST_LOGGROUPLIST_FIELD.name = "logGroupList"
LOGGROUPLIST_LOGGROUPLIST_FIELD.full_name = ".LogGroupList.logGroupList"
LOGGROUPLIST_LOGGROUPLIST_FIELD.number = 1
LOGGROUPLIST_LOGGROUPLIST_FIELD.index = 0
LOGGROUPLIST_LOGGROUPLIST_FIELD.label = 3
LOGGROUPLIST_LOGGROUPLIST_FIELD.has_default_value = false
LOGGROUPLIST_LOGGROUPLIST_FIELD.default_value = {}
LOGGROUPLIST_LOGGROUPLIST_FIELD.message_type = LOGGROUP
LOGGROUPLIST_LOGGROUPLIST_FIELD.type = 11
LOGGROUPLIST_LOGGROUPLIST_FIELD.cpp_type = 10

LOGGROUPLIST.name = "LogGroupList"
LOGGROUPLIST.full_name = ".LogGroupList"
LOGGROUPLIST.nested_types = {}
LOGGROUPLIST.enum_types = {}
LOGGROUPLIST.fields = {LOGGROUPLIST_LOGGROUPLIST_FIELD}
LOGGROUPLIST.is_extendable = false
LOGGROUPLIST.extensions = {}

Log = protobuf.Message(LOG)
Log.Content = protobuf.Message(LOG_CONTENT)
LogGroup = protobuf.Message(LOGGROUP)
LogGroupList = protobuf.Message(LOGGROUPLIST)
LogTag = protobuf.Message(LOGTAG)