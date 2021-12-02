-- signature module for "not signing"


-- config to contain:
-- config.endpoint: hostname to connect to
--
-- tbl to contain:
-- tbl.domain: optional, defaults to "amazon.com"
-- tbl.region: amazon region identifier, eg. "us-east-1"
-- tbl.service: amazon service targetted, eg. "lambda"
-- tbl.method: GET/POST/etc
-- tbl.path: path to invoke, defaults to 'canonicalURI' if given, or otherwise "/"
-- tbl.query: string with the query parameters, defaults to 'canonical_querystring'
-- tbl.canonical_querystring: if given will be used and override 'query'
-- tbl.headers: table of headers for the request
--    note: for headers "Host" and "Authorization"; they will be used if
--          provided, and not be overridden by the generated ones
-- tbl.body: string, defaults to ""
-- tbl.tls: defaults to true (if nil)
-- tbl.port: defaults to 443 or 80 depending on 'tls'
-- tbl.global_endpoint: if true, then use "us-east-1" as signing region and different
--     hostname template: see https://github.com/aws/aws-sdk-js/blob/ae07e498e77000e55da70b20996dc8fd2f8b3051/lib/region_config_data.json
local function prepare_request(config, request_data)
  local tls = config.tls
  local host = config.endpoint
  do
    local s, e = host:find("://")
    if s then
      -- the "globalSSL" one from the region_config_data file
      local scheme = host:sub(1, s-1):lower()
      host = host:sub(e+1, -1)
      if config.tls == nil then
        config.tls = scheme == "https"
      end
    end
  end

  if tls == nil then
    tls = true
  end

  local port = config.port or (tls and 443 or 80)
  local timestamp = ngx.time()
  local req_date = os.date("!%Y%m%dT%H%M%SZ", timestamp)

  local host_header do -- If the "standard" port is not in use, the port should be added to the Host header
    local with_port
    if tls then
      with_port = port ~= 443
    else
      with_port = port ~= 80
    end
    if with_port then
      host_header = string.format("%s:%d", host, port)
    else
      host_header = host
    end
  end

  local headers = {
    ["X-Amz-Date"] = req_date,
    ["Host"] = host_header,
  }
  for k, v in pairs(request_data.headers or {}) do
    headers[k] = v
  end

  return {
    --url = url,                      -- "https://lambda.us-east-1.amazon.com:443/some/path?query1=val1"
    host = host,                      -- "lambda.us-east-1.amazon.com"
    port = port,                      -- 443
    tls = tls,                        -- true
    path = request_data.path,         -- "/some/path"
    method = request_data.method,     -- "GET"
    query = request_data.query,       -- "query1=val1"
    headers = headers,                -- table
    body = request_data.body,         -- string
    --target = target,                -- "/some/path?query1=val1"
  }
end

return prepare_request
