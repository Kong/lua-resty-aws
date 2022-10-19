local json_encode = require("cjson.safe").new().encode

local protocols = {
  ec2 = true,
  json = true,
  query = true,
  ["rest-xml"] = true,
  ["rest-json"] = true,
}



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
        if data[name] then
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

  local request = {
    path =  (operation.http or {}).requestUri or "",
    method = (operation.http or {}).method,
    query = {},
    headers = {},
    body = {},
  }
  if config.signingName or config.targetPrefix then
    request.headers["X-Amz-Target"] = (config.signingName or config.targetPrefix) .. "." .. operation.name
  end
  if config.protocol == "query" then
    request.query["Action"] = operation.name
    request.query["Version"] = config.apiVersion
  end


  -- inject parameters in the right places; path/query/header/body
  -- this assumes they all live on the top-level of the structure, is this correct??
  for name, member_config in pairs(operation.input.members) do
    local param_value = params[name]
    -- TODO: date-time value should be properly formatted???
    if param_value ~= nil then

      -- a parameter value is provided
      local location = member_config.location
      local locationName = member_config.locationName
      -- print(name," = ", param_value, ": ",location, " (", locationName,")")

      if location == "uri" then
        local place_holder = "{" .. locationName .. "%+?}"
        request.path = request.path:gsub(place_holder, param_value)

      elseif location == "querystring" then
        request.query[locationName] = param_value

      elseif location == "header" then
        request.headers[locationName] = param_value

      else
        if config.protocol == "query" then
          -- no location specified, but protocol is query, so it goes into query
          request.query[name] = param_value
        else
          -- nowhere else to go, so put it in the body (for json and xml)
          request.body[name] = param_value
        end
      end
    end
  end

  -- format the body
  if not next(request.body) then
    -- No body values left, remove table
    request.body = nil
  else
    -- encode the body
    if config.protocol == "ec2" then
      error("protocol 'ec2' not implemented yet")

    elseif config.protocol == "rest-xml" then
      local xml_data = {
        '<?xml version="1.0" encoding="UTF-8"?>',
      }

      -- encode rest of the body data here
      poor_mans_xml_encoding(xml_data, operation.input, "input", request.body)

      -- TODO: untested, assuming "application/xml" as the default type here???
      request.headers["Content-Type"] = request.headers["Content-Type"] or "application/xml"
      request.body = table.concat(xml_data, "\n")


    else
      -- assuming remaining protocols "rest-json", "json", "query" to be safe to json encode
      local version = config.jsonVersion or '1.0'
      request.headers["Content-Type"] = request.headers["Content-Type"] or "application/x-amz-json-" .. version
      request.body = json_encode(request.body)
    end
    request.headers["Content-Length"] = #request.body
  end

  return request
end


return build_request
