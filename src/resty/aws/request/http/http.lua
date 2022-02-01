-- load a version of resty-http using luasocket as a fallback
-- this enables using the SDK in the "init" phase where cosockets
-- are unavailable.
--
-- NOTE: the socket compatibility is not sturdy enough to have the http-client
-- make multiple requests over the same connection. So after each request create
-- a new http client and do not re-use it.

local http do
  -- store old values
  local old_tcp = ngx.socket.tcp
  local old_http_client = package.loaded["resty.http"]
  local socket = require "resty.aws.request.http.socket"
  -- patch/remove existing stuff
  package.loaded["resty.http"] = nil
  ngx.socket.tcp = socket.tcp  -- luacheck: ignore
  -- load http, upon requiring it will cache the TCP function
  http = require "resty.http"
  -- restore original versions
  ngx.socket.tcp = old_tcp  -- luacheck: ignore
  package.loaded["resty.http"] = old_http_client
end

return http
