--- RemoteCredentials class.
-- @classmod RemoteCredentials


-- This code is reverse engineered from the original AWS sdk. Specifically:
-- https://github.com/aws/aws-sdk-js/blob/c175cb2b89576f01c08ebf39b232584e4fa2c0e0/lib/credentials/remote_credentials.js

local log = ngx.log
local DEBUG = ngx.DEBUG

local DEFAULT_SERVICE_REQUEST_TIMEOUT = 5000

local url = require "socket.url"
local http = require "resty.luasocket.http"
local json = require "cjson"


local FullUri do
  -- construct the URL

  local function makeset(t)
    for i = 1, #t do
      t[t[i]] = true
    end
    return t
  end

  local global_config = require("resty.aws.config").global

  local ENV_RELATIVE_URI = global_config.AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
  local ENV_FULL_URI = global_config.AWS_CONTAINER_CREDENTIALS_FULL_URI
  local FULL_URI_UNRESTRICTED_PROTOCOLS = makeset { "https" }
  local FULL_URI_ALLOWED_PROTOCOLS = makeset { "http", "https" }
  local FULL_URI_ALLOWED_HOSTNAMES = makeset { "localhost", "127.0.0.1" }
  local RELATIVE_URI_HOST = '169.254.170.2'

  local function getFullUri()
    if ENV_RELATIVE_URI then
      return 'http://' .. RELATIVE_URI_HOST .. ENV_RELATIVE_URI

    elseif ENV_FULL_URI then
      local parsed_url = url.parse(ENV_FULL_URI)

      if not FULL_URI_ALLOWED_PROTOCOLS[parsed_url.scheme] then
        return nil, 'Unsupported protocol, must be one of '
                .. table.concat(FULL_URI_ALLOWED_PROTOCOLS, ',') .. '. Got: '
                .. parsed_url.scheme
      end

      if (not FULL_URI_UNRESTRICTED_PROTOCOLS[parsed_url.scheme]) and
          (not FULL_URI_ALLOWED_HOSTNAMES[parsed_url.host]) then
            return nil, 'Unsupported hostname: AWS.RemoteCredentials only supports '
                  .. table.concat(FULL_URI_ALLOWED_HOSTNAMES, ',') .. ' for '
                  .. parsed_url.scheme .. '; ' .. parsed_url.scheme .. '://'
                  .. parsed_url.host .. ' requested.'
      end

      return ENV_FULL_URI

    else
      return nil, 'Environment variable AWS_CONTAINER_CREDENTIALS_RELATIVE_URI or '
              .. 'AWS_CONTAINER_CREDENTIALS_FULL_URI must be set to use AWS.RemoteCredentials.'
    end
  end


  local err
  FullUri, err = getFullUri()
  if not FullUri then
    log(DEBUG, "Failed to construct RemoteCredentials url: ", err)

  else
    -- parse it and set a default port if omitted
    FullUri = url.parse(FullUri)
    FullUri.port = FullUri.port or
                    ({ http = 80, https = 443 })[FullUri.scheme]
  end
end



-- Create class
local Super = require "resty.aws.credentials.Credentials"
local RemoteCredentials = setmetatable({}, Super)
RemoteCredentials.__index = RemoteCredentials


--- Constructor, inherits from `Credentials`.
-- @function aws:RemoteCredentials
-- @param opt options table, no additional fields to the `Credentials` class.
function RemoteCredentials:new(opts)
  local self = Super:new(opts)  -- override 'self' to be the new object/class
  setmetatable(self, RemoteCredentials)

  return self
end

-- updates credentials.
-- @return success, or nil+err
function RemoteCredentials:refresh()
  if not FullUri then
    return nil, "No URI environment variables found for RemoteCredentials"
  end

  local client = http.new()
  client:set_timeout(DEFAULT_SERVICE_REQUEST_TIMEOUT)

  local ok, err = client:connect {
    scheme = FullUri.scheme,
    host = FullUri.host,
    port = FullUri.port,
  }
  if not ok then
    return nil, "Could not connect to RemoteCredentials metadata service: " .. tostring(err)
  end

  local response, err = client:request {
    method = "GET",
    path   = FullUri.path,
  }

  if not response then
    return nil, "Failed to request RemoteCredentials request returned error: " .. tostring(err)
  end

  if response.status ~= 200 then
    return nil, "Unable to request RemoteCredentials request returned status code " ..
                response.status .. " " .. tostring(response:read_body())
  end

  local credentials = json.decode(response:read_body())

  log(DEBUG, "Received temporary IAM credential from RemoteCredentials " ..
                      "service with session token: ", credentials.Token)

  self:set(credentials.AccessKeyId,
           credentials.SecretAccessKey,
           credentials.Token,
           credentials.Expiration)
  return true
end

return RemoteCredentials
