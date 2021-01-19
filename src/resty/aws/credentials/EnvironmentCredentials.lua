--- EnvironmentCredentials class.
-- @classmod EnvironmentCredentials


-- Create class
local Super = require "resty.aws.credentials.Credentials"
local EnvironmentCredentials = setmetatable({}, Super)
EnvironmentCredentials.__index = EnvironmentCredentials


--- Constructor, inherits from `Credentials`.
--
-- _Note_: this class will fetch the credentials upon instantiation. So it can be
-- instantiated in the `init` phase where there is still access to the environment
-- variables.
-- @function aws:EnvironmentCredentials
-- @param opt options table, additional fields to the `Credentials` class:
-- @param opt.envPrefix prefix to use when looking for environment variables, defaults to "AWS".
function EnvironmentCredentials:new(opts)
  local self = Super:new(opts)  -- override 'self' to be the new object/class
  setmetatable(self, EnvironmentCredentials)

  opts = opts or {}
  self.envPrefix = opts.envPrefix or "AWS"

  self:get() -- force immediate refresh

  return self
end

-- updates credentials.
-- @return success, or nil+err
function EnvironmentCredentials:refresh()
  local access = os.getenv(self.envPrefix .. "_ACCESS_KEY_ID")
  if not access then
    -- Note: nginx workers do not have access to env vars. initialize in init phase or enable access.
    return nil, "Couldn't find " .. self.envPrefix .. "_ACCESS_KEY_ID env variable"
  end
  local secret = os.getenv(self.envPrefix .. "_SECRET_ACCESS_KEY")
  local token = os.getenv(self.envPrefix .. "_SESSION_TOKEN")
  local expire = ngx.now() + 10 * 365 * 24 * 60 * 60 -- static, so assume 10 year validity
  self:set(access, secret, token, expire)
  return true
end

return EnvironmentCredentials
