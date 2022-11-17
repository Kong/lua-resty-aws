--- EnvironmentCredentials class.
-- @classmod EnvironmentCredentials


-- Create class
local Super = require "resty.aws.credentials.Credentials"
local config = require "resty.aws.config"
local SharedFileCredentials = setmetatable({}, Super)
SharedFileCredentials.__index = SharedFileCredentials


--- Constructor, inherits from `Credentials`.
--
-- @function aws:SharedFileCredentials
-- @param opt options table, additional fields to the `Credentials` class:
function SharedFileCredentials:new(opts)
  local self = Super:new(opts)  -- override 'self' to be the new object/class
  setmetatable(self, SharedFileCredentials)

  self:get() -- force immediate refresh

  return self
end

-- updates credentials.
-- @return success, or nil+err
function SharedFileCredentials:refresh()
  local cred = config.load_credentials()

  if not (cred.aws_access_key_id or cred.aws_session_token) then
    return false, "no credentials found"
  end

  local expire = ngx.now() + 10 * 365 * 24 * 60 * 60 -- static, so assume 10 year validity
  self:set(cred.aws_access_key_id, cred.aws_secret_access_key, cred.aws_session_token, expire)
  return true
end

return SharedFileCredentials
