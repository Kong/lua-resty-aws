local http = require "resty.luasocket.http"
local json_decode = require("cjson.safe").new().decode

-- TODO: retries and back-off: https://docs.aws.amazon.com/general/latest/gr/api-retries.html

-- implement AWS api protocols.
-- returns a response table;
-- * status: status code
-- * reason: status description
-- * headers: table with response headers
-- * body: string with the raw body
--
-- Input parameters:
-- * signed_request table
local function execute_request(signed_request)

  local httpc = http.new()
  httpc:set_timeout(60000)

  local ok, err = httpc:connect {
    host = signed_request.host,
    port = signed_request.port,
    scheme = signed_request.tls and "https" or "http",
    ssl_server_name = signed_request.host,
    ssl_verify = true,
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


  local body do
    if response.has_body then
      body, err = response:read_body()
      if not body then
        return nil, ("failed reading response body from '%s:%s': %s"):format(
                      tostring(signed_request.host),
                      tostring(signed_request.port),
                      tostring(err))
      end
    end
  end

  httpc:close()

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
    body = body
  }
end


return execute_request
