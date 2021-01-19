--- EC2MetadataCredentials class.
-- @classmod EC2MetadataCredentials

local http = require "resty.http"
local json = require("cjson.safe").new()
local log = ngx.log
local DEBUG = ngx.DEBUG



local METADATA_SERVICE_PORT = 80
local METADATA_SERVICE_REQUEST_TIMEOUT = 5000  -- milliseconds
local METADATA_SERVICE_HOST = "169.254.169.254"



-- Create class
local Super = require "resty.aws.credentials.Credentials"
local EC2MetadataCredentials = setmetatable({}, Super)
EC2MetadataCredentials.__index = EC2MetadataCredentials


--- Constructor, inherits from `Credentials`.
-- @function aws:EC2MetadataCredentials
-- @param opt options table, no additional fields to the `Credentials` class.
function EC2MetadataCredentials:new(opts)
  local self = Super:new(opts)  -- override 'self' to be the new object/class
  setmetatable(self, EC2MetadataCredentials)

  return self
end

-- updates credentials.
-- @return success, or nil+err
function EC2MetadataCredentials:refresh()
  local client = http.new()
  client:set_timeout(METADATA_SERVICE_REQUEST_TIMEOUT)

  local ok, err = client:connect(METADATA_SERVICE_HOST, METADATA_SERVICE_PORT)

  if not ok then
    return nil, "Could not connect to EC2 metadata service: " .. tostring(err)
  end

  local role_name_request_res, err = client:request {
    method = "GET",
    path   = "/latest/meta-data/iam/security-credentials/",
  }

  if not role_name_request_res then
    return nil, "Could not fetch role name from EC2 metadata service: " .. tostring(err)
  end

  if role_name_request_res.status ~= 200 then
    return nil, "Fetching role name from EC2 metadata service returned status code " ..
                role_name_request_res.status .. " with body: " .. role_name_request_res:read_body()
  end

  local iam_role_name = role_name_request_res:read_body()

  log(DEBUG, "Found EC2 IAM role on instance with name: ", iam_role_name)

  local ok, err = client:connect(METADATA_SERVICE_HOST, METADATA_SERVICE_PORT)

  if not ok then
    return nil, "Could not connect to EC2 metadata service: " .. tostring(err)
  end

  local iam_security_token_request, err = client:request {
    method = "GET",
    path   = "/latest/meta-data/iam/security-credentials/" .. iam_role_name,
  }

  if not iam_security_token_request then
    return nil, "Failed to request EC2 IAM credentials for role " .. iam_role_name ..
                " Request returned error: " .. tostring(err)
  end

  if iam_security_token_request.status == 404 then
    return nil, "Unable to request EC2 IAM credentials for role " .. iam_role_name ..
                " Request returned status code 404."
  end

  if iam_security_token_request.status ~= 200 then
    return nil, "Unable to request EC2 IAM credentials for role" .. iam_role_name ..
                " Request returned status code " .. iam_security_token_request.status ..
                " " .. tostring(iam_security_token_request:read_body())
  end

  local iam_security_token_data = json.decode(iam_security_token_request:read_body())

  log(DEBUG, "Received temporary IAM credential from EC2 metadata service for role '",
                     iam_role_name, "' with session token: ", iam_security_token_data.Token)

  self:set(iam_security_token_data.AccessKeyId,
           iam_security_token_data.SecretAccessKey,
           iam_security_token_data.Token,
           iam_security_token_data.Expiration)

  return true
end

return EC2MetadataCredentials
