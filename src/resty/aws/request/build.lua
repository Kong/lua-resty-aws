local json_encode = require("cjson.safe").new().encode

local protocols = {
  ec2 = true,
  json = true,
  query = true,
  ["rest-xml"] = true,
  ["rest-json"] = true,
}



-- emit (key, raw_value) pairs into `out` for a shape+data pair.
-- Used by the "ec2" and "query" wire protocols. flatten_lists=true forces
-- the flattened form (ec2 always flattens); query passes false and respects
-- shape.flattened on each list shape.
local function form_encode_recurse(out, shape, name, data, flatten_lists)
  if shape.type == "structure" then
    for member_name, member_shape in pairs(shape.members or {}) do
      if data[member_name] ~= nil then
        local seg = member_shape.locationName or member_name
        local sub = name and (name .. "." .. seg) or seg
        form_encode_recurse(out, member_shape, sub, data[member_name], flatten_lists)
      end
    end
  elseif shape.type == "list" then
    local member = shape.member or {}
    local flat = flatten_lists or shape.flattened
    local list_name
    if flat then
      if member.locationName then
        local prefix = name:match("(.+)%.[^.]+$")
        list_name = prefix and (prefix .. "." .. member.locationName) or member.locationName
      else
        list_name = name
      end
    else
      list_name = name .. "." .. (member.locationName or "member")
    end
    for i, item in ipairs(data) do
      form_encode_recurse(out, member, list_name .. "." .. i, item, flatten_lists)
    end
  elseif shape.type == "map" then
    local key_name = (shape.key   or {}).locationName or "key"
    local val_name = (shape.value or {}).locationName or "value"
    local i = 1
    for k, v in pairs(data) do
      out[#out+1] = { name .. ".entry." .. i .. "." .. key_name, tostring(k) }
      out[#out+1] = { name .. ".entry." .. i .. "." .. val_name, tostring(v) }
      i = i + 1
    end
  else
    out[#out+1] = { name, tostring(data) }
  end
end


local function poor_mans_xml_encoding(output, shape, shape_name, data, indent)
  local indent = indent or 0
  local prefix = string.rep("  ", indent)
  local element = shape.locationName or shape_name

  local xmlns = ""
  if (shape.xmlNamespace or {}).uri then
    xmlns = (' xmlns="%s"'):format(shape.xmlNamespace.uri)
  end
  if shape.type == "structure" or
     shape.type == "list" or
     shape.type == "map" then
    -- nested structures
    output[#output+1] = prefix .. '<' .. element .. xmlns .. ">"

    if shape.type == "structure" then
      for name, member in pairs(shape.members) do
        if data[name] ~= nil then
          poor_mans_xml_encoding(output, member, name, data[name], indent + 1)
        end
      end

    elseif shape.type == "list" then
      for i, member_data in ipairs(data or {}) do
        poor_mans_xml_encoding(output, shape.member, "unknown", member_data, indent + 1)
      end

    else -- shape.type == "map"
      error("protocol 'rest-xml' hasn't implemented the 'map' type")

    end

    output[#output+1] = prefix .. '</' .. element .. ">"
  else
    -- just a scalar value
    output[#output+1] = prefix .. '<' .. element .. xmlns .. ">" ..
                        tostring(data) .. '</' .. element .. ">"
  end
end

local ESCAPE_PATTERN = "[^!#$&'()*+,:;=?@[\\]A-Z\\d_.~%-]"
local ESCAPE_PATTERN_WITH_PATH = "[^!#$&'()*+,:;=?@[\\]A-Z\\d_.~%/-]"

local function percent_escape(m)
  return string.format("%%%02X", string.byte(m[0]))
end

local function escape_uri(uri, preserve_path)
  local pattern = preserve_path and ESCAPE_PATTERN_WITH_PATH or ESCAPE_PATTERN
  if ngx.re.find(uri, pattern, "joi") then
    return (ngx.re.gsub(uri, pattern, percent_escape, "joi"))
  end

  return uri
end

local function parse_query(q)
  local query_tbl = {}
  for k, v in q:gmatch('([^&=?]+)=?([^&=?]*)') do
    query_tbl[k] = v
  end
  return query_tbl
end

local function get_host_port(config)
  local endpoint = config.endpoint or config.globalEndpoint
  do
    local s, e = endpoint:find("://")
    local scheme = config.scheme
    if s then
      scheme = scheme or endpoint:sub(1, s-1):lower()
      -- the "globalSSL" one from the region_config_data file
      endpoint = endpoint:sub(e+1, -1)
    end

    scheme = scheme or "https"
    config.scheme = scheme

    if config.tls == nil then
      config.tls = scheme == "https"
    end
  end

  local tls = config.tls
  local port = config.port or (tls and 443 or 80)

  local host_header do -- If the "standard" port is not in use, the port should be added to the Host header
    local with_port
    if tls then
      with_port = port ~= 443
    else
      with_port = port ~= 80
    end
    if with_port then
      host_header = string.format("%s:%d", endpoint, port)
    else
      host_header = endpoint
    end
  end

  return endpoint, port, host_header
end

-- implement AWS api protocols.
-- returns a request table;
-- * method; the HTTP method to use
-- * path; possibly containing rendered values
-- * query; hash-table with query arguments
-- * body; string with formatted body
-- * headers; hash table with headers
--
-- Input parameters:
-- * operation table
-- * config: config table for instantiated service
-- * params: parameters for the call
local function build_request(operation, config, params)
  -- print(require("pl.pretty").write(config))
  -- print(require("pl.pretty").write(operation))
  if not protocols[config.protocol or ""] then
    error("Bad config, field protocol is invalid, got: '" .. tostring(config.protocol) .. "'")
  end

  local http = operation.http or {}
  local uri = http.requestUri or ""

  local host, port, host_header = get_host_port(config)

  local request = {
    path =  uri,
    method = http.method,
    query = {},
    headers = { ["Host"] = host_header, },
    host = host,
    port = port,
  }

  local body_tbl = {}

  if config.signingName or config.targetPrefix then
    request.headers["X-Amz-Target"] = (config.signingName or config.targetPrefix) .. "." .. operation.name
  end
  if config.protocol == "query" then
    request.query["Action"] = operation.name
    request.query["Version"] = config.apiVersion
  end


  -- inject parameters in the right places; path/query/header/body
  -- this assumes they all live on the top-level of the structure, is this correct??
  for name, member_config in pairs((operation.input or {}).members or {}) do
    local param_value = params[name]
    -- TODO: date-time value should be properly formatted???
    if param_value ~= nil then

      -- a parameter value is provided
      local location = member_config.location
      local locationName = member_config.locationName
      -- print(name," = ", param_value, ": ",location, " (", locationName,")")

      if location == "uri" then
        local place_holder = "{" .. locationName .. "(%+?)}"
        local _, _, has_plus = request.path:find(place_holder)
        local preserve_path = has_plus == "+"
        local replacement = escape_uri(param_value, preserve_path):gsub("%%", "%%%%")
        request.path = request.path:gsub(place_holder, replacement)

      elseif location == "querystring" then
        request.query[locationName] = param_value

      elseif location == "header" then
        request.headers[locationName] = param_value

      elseif location == "headers" then
        for k,v in pairs(param_value) do
          request.headers[locationName .. k] = v
        end

      elseif location == nil then
        if config.protocol == "query" then
          -- no location specified, but protocol is query, so it goes into query.
          -- Lists/structs/maps are recursively expanded into AWS query wire form
          -- (e.g. InstanceIds.member.1=...) so the HTTP client receives flat scalars.
          local out = {}
          form_encode_recurse(out, member_config,
                              member_config.locationName or name,
                              param_value, false)
          for _, kv in ipairs(out) do
            request.query[kv[1]] = kv[2]
          end
        else
          -- nowhere else to go, so put it in the body (for json and xml)
          body_tbl[name] = param_value
        end

      else
        error("Unknown location: " .. location)
      end
    end
  end

  local path, query = request.path:match("([^?]+)%??(.*)")
  request.path = path

  for k,v in pairs(parse_query(query)) do
    request.query[ngx.unescape_uri(k)] = ngx.unescape_uri(v)
  end

  local payload_member = operation.input and operation.input.payload
  if payload_member and body_tbl[payload_member] then
    local member_config = operation.input.members[payload_member]
    if member_config.type == "structure" then
      body_tbl = type(body_tbl[payload_member]) == "table" and body_tbl[payload_member] or body_tbl

    elseif body_tbl[payload_member] then
      request.body = body_tbl[payload_member]
      if member_config.type == "binary" and member_config.streaming == true then
        request.headers["Content-Type"] = "binary/octet-stream"
      end
      body_tbl[payload_member] = nil
    end
  end

  local table_empty = not next(body_tbl)
  -- already has a raw body, or no body at all
  if request.body then
    assert(table_empty, "raw body set while parameters need to be encoded in body")
    request.headers["Content-Length"] = #request.body
    return request
  end

  if table_empty then
    return request
  end

  -- format the body
  if config.protocol == "ec2" then
    -- EC2 wire protocol: POST body is application/x-www-form-urlencoded with
    -- Action+Version and all params (including nested structs and lists) folded
    -- in via the AWS flattened-list form: <member.locationName>.N=value.
    local out = {
      { "Action",  operation.name },
      { "Version", config.apiVersion },
    }
    for n, v in pairs(body_tbl) do
      local mc = operation.input.members[n]
      assert(mc, "no shape for body parameter '" .. n .. "'")
      form_encode_recurse(out, mc, mc.locationName or n, v, true)
    end
    local parts = {}
    for _, kv in ipairs(out) do
      parts[#parts+1] = escape_uri(kv[1]) .. "=" .. escape_uri(kv[2])
    end
    request.headers["Content-Type"] = request.headers["Content-Type"] or "application/x-www-form-urlencoded"
    request.body = table.concat(parts, "&")

  elseif config.protocol == "rest-xml" then
    local xml_data = {
      '<?xml version="1.0" encoding="UTF-8"?>',
    }

    -- encode rest of the body data here
    poor_mans_xml_encoding(xml_data, operation.input, "input", body_tbl)

    -- TODO: untested, assuming "application/xml" as the default type here???
    request.headers["Content-Type"] = request.headers["Content-Type"] or "application/xml"
    request.body = table.concat(xml_data, "\n")


  else
    -- assuming remaining protocols "rest-json", "json", "query" to be safe to json encode
    local version = config.jsonVersion or '1.0'
    request.headers["Content-Type"] = request.headers["Content-Type"] or "application/x-amz-json-" .. version
    request.body = json_encode(body_tbl)
  end
  request.headers["Content-Length"] = #request.body

  return request
end


return build_request
