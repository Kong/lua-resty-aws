local http = require "resty.luasocket.http"

local json_safe = require("cjson.safe").new()
json_safe.decode_array_with_array_mt(true)
local json_decode = json_safe.decode

-- TODO: retries and back-off: https://docs.aws.amazon.com/general/latest/gr/api-retries.html

-- implement AWS api protocols.
-- returns a response table;
-- * status: status code
-- * reason: status description
-- * headers: table with response headers
-- * body: string with the raw body
-- * body_reader: if resposne mimetype is eventstream, returns the stream reader handle
--
-- Input parameters:
-- * signed_request table
local function execute_request(signed_request)

  local httpc = http.new()
  httpc:set_timeout(signed_request.timeout or 60000)

  local ok, err = httpc:connect {
    host = signed_request.host,
    port = signed_request.port,
    scheme = signed_request.tls and "https" or "http",
    ssl_server_name = signed_request.host,
    ssl_verify = signed_request.ssl_verify,
    proxy_opts = signed_request.proxy_opts,
  }
  if not ok then
    return nil, ("failed to connect to '%s://%s:%s': %s"):format(
                  signed_request.tls and "https" or "http",
                  tostring(signed_request.host),
                  tostring(signed_request.port),
                  tostring(err))
  end

  local response, err = httpc:request({
    path = signed_request.path,
    method = signed_request.method,
    headers = signed_request.headers,
    query = signed_request.query,
    body = signed_request.body,
  })
  if not response then
    return nil, ("failed sending request to '%s:%s': %s"):format(
                  tostring(signed_request.host),
                  tostring(signed_request.port),
                  tostring(err))
  end

  local body, body_reader

  if response.headers["application/vnd.amazon.eventstream"] then
    body_reader = response.body_reader
  else
    local this_body do
      if response.has_body then
        this_body, err = response:read_body()
        if not this_body then
          return nil, ("failed reading response body from '%s:%s': %s"):format(
                        tostring(signed_request.host),
                        tostring(signed_request.port),
                        tostring(err))
        end

        body = this_body
      end
    end
  end

  if signed_request.keepalive_idle_timeout then
    httpc:set_keepalive(signed_request.keepalive_idle_timeout)
  else
    httpc:close()
  end

  local ct = response.headers["Content-Type"]
  if (ct and ct:lower():match("application/.*json")) then
    -- json body, let's decode
    local ok = json_decode(body)
    if ok then
      body = ok
    end
  end

  return {
    status = response.status,
    reason = response.reason,
    headers = response.headers,
    body = body,
    body_reader = body_reader,
  }
end


return execute_request
