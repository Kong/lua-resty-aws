--- CredentialProviderChain class.
-- @classmod CredentialProviderChain


-- Create class
local Super = require "resty.aws.credentials.Credentials"
local CredentialProviderChain = setmetatable({}, Super)
CredentialProviderChain.__index = CredentialProviderChain


CredentialProviderChain.defaultProviders = {} do
  -- while not everything is implemented this will load what we do have without
  -- failing on what is missing. Will auto pick up newly added classes afterwards.
  local function add_if_exists(name, opts)
    local ok, class = pcall(require, "resty.aws.credentials." .. name)
    if not ok then
      ngx.log(ngx.DEBUG, "AWS credential class '", name, "' not found or failed to load")
      return
    end
    -- instantiate and add
    CredentialProviderChain.defaultProviders[#CredentialProviderChain.defaultProviders+1] = class:new(opts)
  end

  -- add the defaults
  add_if_exists("EnvironmentCredentials", { envPrefix = 'AWS' })
  add_if_exists("EnvironmentCredentials", { envPrefix = 'AMAZON' })
  add_if_exists("SharedIniFileCredentials")
  add_if_exists("RemoteCredentials") -- since "ECSCredentials" doesn't exist? and for ECS RemoteCredentials is used???
  add_if_exists("ProcessCredentials")
  add_if_exists("TokenFileWebIdentityCredentials")
  add_if_exists("EC2MetadataCredentials")
end

--- Constructor, inherits from `Credentials`.
--
-- The `providers` array defaults to the following list (in order, not all implemented):
--
-- 1. `EnvironmentCredentials`; envPrefix = 'AWS'
--
-- 2. `EnvironmentCredentials`; envPrefix = 'AMAZON'
--
-- 3. `SharedIniFileCredentials`
--
-- 4. `RemoteCredentials`
--
-- 5. `ProcessCredentials`
--
-- 6. `TokenFileWebIdentityCredentials`
--
-- 7. `EC2MetadataCredentials`
--
-- @function aws:CredentialProviderChain
-- @param opt options table, additional fields to the `Credentials` class:
-- @param opt.providers array of `Credentials` objects or functions (functions must return a `Credentials` object)
function CredentialProviderChain:new(opts)
  local self = Super:new(opts)  -- override 'self' to be the new object/class
  setmetatable(self, CredentialProviderChain)

  opts = opts or {}

  self.providers = opts.providers
  if not self.providers then
    self.providers = {}
    for i, provider in ipairs(CredentialProviderChain.defaultProviders) do
      self.providers[i] = provider
    end
  end

  assert(type(self.providers) == "table", "expected opts.providers to be an array of 'Credentials' objects or functions returning Credentials")

  return self
end

-- updates credentials.
-- @return true
function CredentialProviderChain:refresh()
  for i, provider in ipairs(self.providers) do
    if type(provider) == "function" then
      -- lazily create Credential
      local p, err = provider()
      if not p then
        ngx.log(ngx.ERR, "failed to instantiate Credential from provider function: ", tostring(err))
      else
        -- store succesful created credential, replacing the previous function
        self.providers[i] = p
        provider = p
      end
    end

    local success, accessKeyId, secretAccessKey, sessionToken, expireTime = provider:get()
    if not success then
      ngx.log(ngx.DEBUG, "Provider failed: ", accessKeyId)
    else
      -- success, store results and exit
      self:set(accessKeyId, secretAccessKey, sessionToken, expireTime)
      return true
    end
  end
  return nil, "none of the providers succeeded, no credentials available"
end

return CredentialProviderChain
