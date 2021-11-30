local cjson = require "cjson"
local validate -- forward declaration

--[[
====================================================
   List of properties, and for each the combinations in which it occurs
====================================================
box (140)
        [box,t(integer)] (16)
        [box,t(double)] (6)
        [t(long),box,min] (3)
        [max,t(integer),box,min] (78)
        [box,t(float)] (1)
        [max,box,t(integer)] (2)
        [t(integer),box,min] (5)
        [box,t(long)] (5)
        [box,t(boolean)] (18)
        [max,t(double),box,min] (1)
        [max,t(long),box,min] (5)
deprecated (16)
        [t(structure),members,deprecated] (5)
        [deprecatedMessage,t(structure),members,deprecated] (2)
        [required,t(structure),deprecated,members] (2)
        [t(integer),deprecated] (1)
        [member,deprecated,t(list)] (1)
        [deprecatedMessage,enum,t(string),deprecated] (2)
        [deprecatedMessage,t(string),deprecated] (1)
        [t(string),deprecated] (2)
deprecatedMessage (5)
        [deprecatedMessage,t(structure),members,deprecated] (2)
        [deprecatedMessage,enum,t(string),deprecated] (2)
        [deprecatedMessage,t(string),deprecated] (1)
description (1)
        [t(blob),streaming,description] (1)
enum (3211)
        [t(string),enum] (3174)
        [t(string),sensitive,enum] (2)
        [max,pattern,t(string),enum,min] (2)
        [max,pattern,enum,t(string)] (3)
        [deprecatedMessage,enum,t(string),deprecated] (2)
        [max,enum,t(string)] (3)
        [max,enum,t(string),min] (25)
error (163)
        [exception,t(structure),error,fault,members] (3)
        [exception,t(structure),error,required,members] (12)
        [exception,error,required,t(structure),fault,members] (1)
        [exception,t(structure),error,members] (147)
event (5)
        [t(structure),members,event] (5)
eventstream (1)
        [t(structure),members,eventstream] (1)
exception (214)
        [exception,t(structure),error,fault,members] (3)
        [exception,fault,t(structure),members] (6)
        [exception,t(structure),error,required,members] (12)
        [exception,error,required,t(structure),fault,members] (1)
        [exception,t(structure),members] (45)
        [exception,t(structure),error,members] (147)
fault (10)
        [exception,t(structure),error,fault,members] (3)
        [exception,fault,t(structure),members] (6)
        [exception,error,required,t(structure),fault,members] (1)
flattened (56)
        [value,flattened,t(map),key] (2)
        [value,flattened,t(map),locationName,key] (3)
        [member,flattened,t(list)] (51)
key (379)
        [value,t(map),min,key] (1)
        [value,t(map),max,key] (26)
        [value,flattened,t(map),key] (2)
        [value,flattened,t(map),locationName,key] (3)
        [value,t(map),key] (278)
        [value,key,t(map),max,min] (60)
        [value,max,key,t(map),sensitive,min] (1)
        [value,t(map),sensitive,key] (8)
locationName (10)
        [locationName,required,t(structure),members] (4)
        [max,locationName,t(list),member] (1)
        [t(structure),locationName,members] (1)
        [value,flattened,t(map),locationName,key] (3)
        [member,locationName,t(list)] (1)
max (4808)
        [max,t(string),min] (1069)
        [max,t(blob),min] (18)
        [max,sensitive,t(string)] (12)
        [max,t(list),member,sensitive,min] (1)
        [max,t(integer),min] (577)
        [max,t(string),pattern] (333)
        [max,t(integer),box,min] (78)
        [max,locationName,t(list),member] (1)
        [max,member,t(list)] (180)
        [max,pattern,t(string),enum,min] (2)
        [max,pattern,enum,t(string)] (3)
        [max,t(list),member,min] (672)
        [value,t(map),max,key] (26)
        [max,t(blob)] (3)
        [max,t(integer)] (3)
        [max,sensitive,t(blob)] (3)
        [max,t(float),min] (10)
        [max,box,t(integer)] (2)
        [max,enum,t(string)] (3)
        [max,t(string)] (323)
        [max,t(string),sensitive,min] (37)
        [max,t(blob),sensitive,min] (4)
        [max,pattern,sensitive,t(string)] (14)
        [value,key,t(map),max,min] (60)
        [max,t(double),min] (11)
        [max,t(double)] (2)
        [max,pattern,t(string),min] (1247)
        [max,t(long),min] (34)
        [max,pattern,t(string),sensitive,min] (48)
        [value,max,key,t(map),sensitive,min] (1)
        [max,t(double),box,min] (1)
        [max,enum,t(string),min] (25)
        [max,t(long),box,min] (5)
member (4920)
        [max,t(list),member,sensitive,min] (1)
        [max,locationName,t(list),member] (1)
        [max,member,t(list)] (180)
        [member,sensitive,t(list)] (5)
        [max,t(list),member,min] (672)
        [member,min,t(list)] (96)
        [member,deprecated,t(list)] (1)
        [t(list),member] (3912)
        [member,flattened,t(list)] (51)
        [member,locationName,t(list)] (1)
members (22158)
        [required,payload,t(structure),members] (263)
        [locationName,required,t(structure),members] (4)
        [exception,t(structure),error,fault,members] (3)
        [t(structure),members,event] (5)
        [t(structure),members,deprecated] (5)
        [deprecatedMessage,t(structure),members,deprecated] (2)
        [required,t(structure),deprecated,members] (2)
        [t(structure),members,wrapper] (75)
        [exception,fault,t(structure),members] (6)
        [t(structure),locationName,members] (1)
        [xmlOrder,required,t(structure),members] (2)
        [t(structure),members,xmlOrder] (5)
        [exception,t(structure),error,required,members] (12)
        [t(structure),members] (12175)
        [required,members,t(structure)] (9304)
        [t(structure),sensitive,members] (17)
        [required,xmlNamespace,t(structure),members] (1)
        [t(structure),required,sensitive,members] (7)
        [exception,error,required,t(structure),fault,members] (1)
        [exception,t(structure),members] (45)
        [t(structure),members,eventstream] (1)
        [payload,t(structure),members] (75)
        [exception,t(structure),error,members] (147)
min (4294)
        [max,t(string),min] (1069)
        [max,t(blob),min] (18)
        [max,t(list),member,sensitive,min] (1)
        [max,t(integer),min] (577)
        [t(long),box,min] (3)
        [max,t(integer),box,min] (78)
        [t(float),min] (1)
        [max,pattern,t(string),enum,min] (2)
        [t(string),pattern,sensitive,min] (1)
        [max,t(list),member,min] (672)
        [member,min,t(list)] (96)
        [t(double),min] (8)
        [value,t(map),min,key] (1)
        [max,t(float),min] (10)
        [t(integer),box,min] (5)
        [t(string),min] (68)
        [t(string),min,pattern] (21)
        [t(integer),min] (142)
        [max,t(string),sensitive,min] (37)
        [max,t(blob),sensitive,min] (4)
        [t(string),sensitive,min] (7)
        [value,key,t(map),max,min] (60)
        [max,t(double),min] (11)
        [t(long),min] (41)
        [max,pattern,t(string),min] (1247)
        [max,t(long),min] (34)
        [max,pattern,t(string),sensitive,min] (48)
        [value,max,key,t(map),sensitive,min] (1)
        [max,t(double),box,min] (1)
        [max,enum,t(string),min] (25)
        [max,t(long),box,min] (5)
pattern (2094)
        [t(string),sensitive,pattern] (7)
        [max,t(string),pattern] (333)
        [t(string),pattern] (418)
        [max,pattern,t(string),enum,min] (2)
        [t(string),pattern,sensitive,min] (1)
        [max,pattern,enum,t(string)] (3)
        [t(string),min,pattern] (21)
        [max,pattern,sensitive,t(string)] (14)
        [max,pattern,t(string),min] (1247)
        [max,pattern,t(string),sensitive,min] (48)
payload (338)
        [required,payload,t(structure),members] (263)
        [payload,t(structure),members] (75)
required (9596)
        [required,payload,t(structure),members] (263)
        [locationName,required,t(structure),members] (4)
        [required,t(structure),deprecated,members] (2)
        [xmlOrder,required,t(structure),members] (2)
        [exception,t(structure),error,required,members] (12)
        [required,members,t(structure)] (9304)
        [required,xmlNamespace,t(structure),members] (1)
        [t(structure),required,sensitive,members] (7)
        [exception,error,required,t(structure),fault,members] (1)
sensitive (199)
        [t(string),sensitive,pattern] (7)
        [max,sensitive,t(string)] (12)
        [max,t(list),member,sensitive,min] (1)
        [t(string),sensitive,enum] (2)
        [t(string),pattern,sensitive,min] (1)
        [member,sensitive,t(list)] (5)
        [t(blob),sensitive,streaming] (1)
        [max,sensitive,t(blob)] (3)
        [t(string),sensitive] (20)
        [t(structure),sensitive,members] (17)
        [t(structure),required,sensitive,members] (7)
        [max,t(string),sensitive,min] (37)
        [max,t(blob),sensitive,min] (4)
        [max,pattern,sensitive,t(string)] (14)
        [t(string),sensitive,min] (7)
        [max,pattern,t(string),sensitive,min] (48)
        [value,max,key,t(map),sensitive,min] (1)
        [value,t(map),sensitive,key] (8)
        [t(blob),sensitive] (4)
streaming (12)
        [t(blob),streaming] (10)
        [t(blob),streaming,description] (1)
        [t(blob),sensitive,streaming] (1)
t(blob) (86)
        [max,t(blob),min] (18)
        [t(blob),streaming] (10)
        [t(blob),streaming,description] (1)
        [t(blob),sensitive,streaming] (1)
        [max,t(blob)] (3)
        [max,sensitive,t(blob)] (3)
        [max,t(blob),sensitive,min] (4)
        [t(blob)] (42)
        [t(blob),sensitive] (4)
t(boolean) (451)
        [t(boolean)] (433)
        [box,t(boolean)] (18)
t(double) (131)
        [box,t(double)] (6)
        [t(double),min] (8)
        [t(double)] (103)
        [max,t(double),min] (11)
        [max,t(double)] (2)
        [max,t(double),box,min] (1)
t(float) (28)
        [t(float),min] (1)
        [t(float)] (16)
        [box,t(float)] (1)
        [max,t(float),min] (10)
t(integer) (1148)
        [box,t(integer)] (16)
        [max,t(integer),min] (577)
        [max,t(integer),box,min] (78)
        [t(integer)] (324)
        [t(integer),deprecated] (1)
        [max,t(integer)] (3)
        [max,box,t(integer)] (2)
        [t(integer),box,min] (5)
        [t(integer),min] (142)
t(list) (4920)
        [max,t(list),member,sensitive,min] (1)
        [max,locationName,t(list),member] (1)
        [max,member,t(list)] (180)
        [member,sensitive,t(list)] (5)
        [max,t(list),member,min] (672)
        [member,min,t(list)] (96)
        [member,deprecated,t(list)] (1)
        [t(list),member] (3912)
        [member,flattened,t(list)] (51)
        [member,locationName,t(list)] (1)
t(long) (247)
        [t(long),box,min] (3)
        [t(long)] (159)
        [box,t(long)] (5)
        [t(long),min] (41)
        [max,t(long),min] (34)
        [max,t(long),box,min] (5)
t(map) (379)
        [value,t(map),min,key] (1)
        [value,t(map),max,key] (26)
        [value,flattened,t(map),key] (2)
        [value,flattened,t(map),locationName,key] (3)
        [value,t(map),key] (278)
        [value,key,t(map),max,min] (60)
        [value,max,key,t(map),sensitive,min] (1)
        [value,t(map),sensitive,key] (8)
t(string) (8783)
        [t(string),enum] (3174)
        [t(string),sensitive,pattern] (7)
        [max,t(string),min] (1069)
        [max,sensitive,t(string)] (12)
        [max,t(string),pattern] (333)
        [t(string),sensitive,enum] (2)
        [t(string),pattern] (418)
        [max,pattern,t(string),enum,min] (2)
        [t(string),pattern,sensitive,min] (1)
        [max,pattern,enum,t(string)] (3)
        [deprecatedMessage,enum,t(string),deprecated] (2)
        [deprecatedMessage,t(string),deprecated] (1)
        [t(string),sensitive] (20)
        [t(string),min] (68)
        [t(string),deprecated] (2)
        [max,enum,t(string)] (3)
        [max,t(string)] (323)
        [t(string),min,pattern] (21)
        [t(string)] (1944)
        [max,t(string),sensitive,min] (37)
        [max,pattern,sensitive,t(string)] (14)
        [t(string),sensitive,min] (7)
        [max,pattern,t(string),min] (1247)
        [max,pattern,t(string),sensitive,min] (48)
        [max,enum,t(string),min] (25)
t(structure) (22158)
        [required,payload,t(structure),members] (263)
        [locationName,required,t(structure),members] (4)
        [exception,t(structure),error,fault,members] (3)
        [t(structure),members,event] (5)
        [t(structure),members,deprecated] (5)
        [deprecatedMessage,t(structure),members,deprecated] (2)
        [required,t(structure),deprecated,members] (2)
        [t(structure),members,wrapper] (75)
        [exception,fault,t(structure),members] (6)
        [t(structure),locationName,members] (1)
        [xmlOrder,required,t(structure),members] (2)
        [t(structure),members,xmlOrder] (5)
        [exception,t(structure),error,required,members] (12)
        [t(structure),members] (12175)
        [required,members,t(structure)] (9304)
        [t(structure),sensitive,members] (17)
        [required,xmlNamespace,t(structure),members] (1)
        [t(structure),required,sensitive,members] (7)
        [exception,error,required,t(structure),fault,members] (1)
        [exception,t(structure),members] (45)
        [t(structure),members,eventstream] (1)
        [payload,t(structure),members] (75)
        [exception,t(structure),error,members] (147)
t(timestamp) (313)
        [timestampFormat,t(timestamp)] (20)
        [t(timestamp)] (293)
timestampFormat (20)
        [timestampFormat,t(timestamp)] (20)
value (379)
        [value,t(map),min,key] (1)
        [value,t(map),max,key] (26)
        [value,flattened,t(map),key] (2)
        [value,flattened,t(map),locationName,key] (3)
        [value,t(map),key] (278)
        [value,key,t(map),max,min] (60)
        [value,max,key,t(map),sensitive,min] (1)
        [value,t(map),sensitive,key] (8)
wrapper (75)
        [t(structure),members,wrapper] (75)
xmlNamespace (1)
        [required,xmlNamespace,t(structure),members] (1)
xmlOrder (7)
        [xmlOrder,required,t(structure),members] (2)
        [t(structure),members,xmlOrder] (5)
====================================================
   List of types
====================================================
list (4920)
double (131)
structure (22158)
blob (86)
float (28)
long (247)
string (8783)
integer (1148)
boolean (451)
timestamp (313)
map (379)
====================================================
]]
-- validation
local validators do
  local always_pass = function() return true end
  local ops_mt = {
    __index = function(self, key)
      error("don't know how to validate operator '"..key.."' of type '"..tostring(self.__type).."'", 2)
    end
  }


  local string_checks = setmetatable({
    __type = "string",
    min = function(value, min, id)
      if #value >= min then return true end
      return nil, (id and id .. ": " or "") .. "minimum length of " .. min
    end,
    max = function(value, max, id)
      if #value <= max then return true end
      return nil, (id and id .. ": " or "") .. "maximum length of " .. max
    end,
    pattern = function(value, pattern, id)
      return true  -- disabled since the JavaScript Regex patterns are incompatible
      -- if ngx.re.match(value, pattern, "jo") then return true end
      -- return nil, (id and id .. ": " or "") .. "value should match pattern: "..pattern
    end,
    enum = function(value, enums, id)
      for _, enum in ipairs(enums) do
        if enum == value then return true end
      end
      return nil, (id and id .. ": " or "") .. "value '" .. tostring(value) ..
                  "' is not allowed, it should be any of: '" ..
                  table.concat(enums, "', '") .. "'"
    end,
    type = always_pass,
    deprecatedMessage = always_pass,
    deprecated = always_pass,
    sensitive = always_pass,
    streaming = always_pass,  -- for type 'blob'
    description = always_pass,  -- for type 'blob'
  },ops_mt)


  local integer_checks = setmetatable({
    __type = "integer",
    min = function(value, min, id)
      if value >= min then return true end
      return nil, (id and id .. ": " or "") .. "minimum of " .. min .. ", got " .. value
    end,
    max = function(value, max, id)
      if value <= max then return true end
      return nil, (id and id .. ": " or "") .. "maximum of " .. max .. ", got " .. value
    end,
    type = always_pass,
    deprecated = always_pass,
    box = always_pass,
  },ops_mt)


  local list_checks do
    local function get_length(t)  -- gets length of an array (with holes)
      local size = 0
      for k,v in pairs(t) do
        if type(k) ~= "number" then
          return nil, "list contains non-numeric indices"
        end
        if k > size then size = k end
      end
      return size
    end

    list_checks = setmetatable({
      __type = "list",
      -- assume json notation, so array with holes is allowed...
      make_json_array = function(value)
        -- we're most likely json-ifying a list like this, so attachj the array
        -- metatable if not already exists
        if not getmetatable(value) then
          setmetatable({}, cjson.array_mt)
        end
      end,
      min = function(value, min, id)
        local l, err = get_length(value)
        if not l then return nil, (id and id .. ": " or "") .. err end
        if l >= min then return true end
        return nil, (id and id .. ": " or "") .. "minimum list length of " .. min
      end,
      max = function(value, max, id)
        local l, err = get_length(value)
        if not l then return nil, (id and id .. ": " or "") .. err end
        if l <= max then return true end
        return nil, (id and id .. ": " or "") .. "maximum list length of " .. max
      end,
      member = function(value, shape, id)
        local l, err = get_length(value)
        if not l then return nil, (id and id .. ": " or "") .. err end
        for i = 1, l do
          local member = value[i]
          if member then
            local ok, err = validate(member, shape, "["..i.."]")
            if not ok then
              return nil, (id or "") .. err
            end
          end
        end
        return true
      end,
      type = always_pass,
      deprecated = always_pass,
      locationName = always_pass,
      sensitive = always_pass,
      box = always_pass,
    },ops_mt)
  end


  local map_checks do
    local function get_size(t)  -- gets length of an array (with holes)
      local size = 0
      for k,v in pairs(t) do size = size + 1 end
      return size
    end

    map_checks = setmetatable({
      __type = "map",
      min = function(value, min, id)
        local l = get_size(value)
        if l >= min then return true end
        return nil, (id and id .. ": " or "") .. "minimum map size of " .. min
      end,
      max = function(value, max, id)
        local l = get_size(value)
        if l <= max then return true end
        return nil, (id and id .. ": " or "") .. "maximum map size of " .. max
      end,
      key = function(value, shape, id)
        for key, value in pairs(value) do
          local ok, err = validate(key, shape)
          if not ok then
            return nil, (id and id .. "." .. tostring(key) or tostring(key)) .. ": the key ('" .. tostring(key) .. "') failed validation: " .. err
          end
        end
        return true
      end,
      value = function(value, shape, id)
        for key, value in pairs(value) do
          local ok, err = validate(value, shape, key)
          if not ok then
            return nil, (id and id .. "." or "") .. err
          end
        end
        return true
      end,
      type = always_pass,
      locationName = always_pass,
      sensitive = always_pass,
    },ops_mt)
  end


  local structure_checks = setmetatable({
    __type = "structure",
    required = function(value, list, id)
      for _, key in ipairs(list) do
        if value[key] == nil then
          return nil, (id and id .. "." or "") .. key .. " is required but missing"
        end
      end
      return true
    end,
    members = function(value, members, id)
      for key, shape in pairs(members) do
        if value[key] ~= nil then
          local ok, err = validate(value[key], shape, key)
          if not ok then
            return nil, (id and id .. "." or "") .. err
          end
        end
      end
      return true
    end,
    type = always_pass,
    deprecatedMessage = always_pass,
    deprecated = always_pass,
    sensitive = always_pass,
  },ops_mt)




  validators = setmetatable({
    string = function(value, shape, id)
      if type(value) ~= "string" then
        return nil, (id and id .. ": " or "") .. "expected a string value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = string_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    blob = function(value, shape, id)  -- reuses string checks
      if type(value) ~= "string" then
        return nil, (id and id .. ": " or "") .. "expected a string (blob) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = string_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    integer = function(value, shape, id)
      if type(value) ~= "number" then
        return nil, (id and id .. ": " or "") .. "expected a number (integer) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = integer_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    long = function(value, shape, id) -- reuses integer checks
      if type(value) ~= "number" then
        return nil, (id and id .. ": " or "") .. "expected a number (long) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = integer_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    float = function(value, shape, id) -- reuses integer checks
      if type(value) ~= "number" then
        return nil, (id and id .. ": " or "") .. "expected a number (float) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = integer_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    double = function(value, shape, id) -- reuses integer checks
      if type(value) ~= "number" then
        return nil, (id and id .. ": " or "") .. "expected a number (double) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = integer_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    boolean = function(value, shape, id)
      if type(value) ~= "boolean" then
        return nil, (id and id .. ": " or "") .. "expected a boolean value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      return true
    end,

    list = function(value, shape, id)
      if type(value) ~= "table" then
        return nil, (id and id .. ": " or "") .. "expected a table (list) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = list_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    map = function(value, shape, id)
      if type(value) ~= "table" then
        return nil, (id and id .. ": " or "") .. "expected a table (map) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = map_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    structure = function(value, shape, id)
      if type(value) ~= "table" then
        return nil, (id and id .. ": " or "") .. "expected a table (structure) value, got '" .. tostring(value) .. "' ("..type(value)..")"
      end
      for check, check_value in pairs(shape) do
        local ok, err = structure_checks[check](value, check_value, id)
        if not ok then
          return nil, err
        end
      end
      return true
    end,

    -- timestamp = function(value, shape)

    -- timestampFormat = function(value, shape)

    -- wrapper = function(value, shape)

    -- xmlNamespace = function(value, shape)

    -- xmlOrder = function(value, shape)

  },{
    __index = function(self, key)
      error("don't know how to validate type '"..tostring(key).."'", 2)
    end
  })
end

--- validate a data structure.
-- @param value the value to validate
-- @param shape the shape object to validate against
-- @param id (string) field name to construct a nested name for error messages
function validate(value, shape, id)
  return validators[shape.type](value, shape, id)
end

return validate
