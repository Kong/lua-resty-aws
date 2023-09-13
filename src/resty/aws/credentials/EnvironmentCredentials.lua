--- EnvironmentCredentials class.
-- @classmod EnvironmentCredentials


local aws_config = require("resty.aws.config")


-- Create class
local Super = require "resty.aws.credentials.Credentials"
local EnvironmentCredentials = setmetatable({}, Super)
EnvironmentCredentials.__index = EnvironmentCredentials


--- Constructor, inherits from `Credentials`.
--
-- _Note_: this class will fetch the credentials upon instantiation. So it can be
-- instantiated in the `init` phase where there is still access to the environment
-- variables. The standard prefixes `AWS` and `AMAZON` are covered by the `config`
-- module, so in case those are used, only the `config` module needs to be loaded
-- in the `init` phase.
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
  local global_config = aws_config.global

  local access = os.getenv(self.envPrefix .. "_ACCESS_KEY_ID") or global_config[self.envPrefix .. "_ACCESS_KEY_ID"]
  if not access then
    -- Note: nginx workers do not have access to env vars. initialize in init phase
    -- or enable access for any prefix other than "AWS" and "AMAZON" which are covered
    -- by the 'config' module.
    return nil, "Couldn't find " .. self.envPrefix .. "_ACCESS_KEY_ID env variable"
  end
  local secret = os.getenv(self.envPrefix .. "_SECRET_ACCESS_KEY") or global_config[self.envPrefix .. "_SECRET_ACCESS_KEY"]
  local token = os.getenv(self.envPrefix .. "_SESSION_TOKEN") or global_config[self.envPrefix .. "_SESSION_TOKEN"]
  local expire = ngx.now() + 10 * 365 * 24 * 60 * 60 -- static, so assume 10 year validity
  self:set(access, secret, token, expire)
  return true
end

return EnvironmentCredentials
