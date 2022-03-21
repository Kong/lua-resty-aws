--- TokenFileWebIdentityCredentials class.
-- @classmod TokenFileWebIdentityCredentials

local readfile = require("pl.utils").readfile
local xml = require("pl.xml")


local global_config = require("resty.aws.config").global
local AWS_ROLE_ARN = global_config.role_arn
local AWS_WEB_IDENTITY_TOKEN_FILE = global_config.web_identity_token_file
local AWS_ROLE_SESSION_NAME = global_config.role_session_name or "session@lua-resty-aws"


-- Create class
local Super = require "resty.aws.credentials.Credentials"
local TokenFileWebIdentityCredentials = setmetatable({}, Super)
TokenFileWebIdentityCredentials.__index = TokenFileWebIdentityCredentials


--- Constructor, inherits from `Credentials`.
-- @function aws:TokenFileWebIdentityCredentials
-- @tparam table opts options table, only listing additional fields to the `Credentials` class.
-- @tparam[opt=AWS_WEB_IDENTITY_TOKEN_FILE env var] string opts.token_file filename of the token file
-- @tparam[opt=AWS_ROLE_ARN env var] string opts.role_arn arn of the role to assume
-- @tparam[opt=AWS_ROLE_SESSION_NAME env var or 'session@lua-resty-aws'] string opts.session_name session name
function TokenFileWebIdentityCredentials:new(opts)
  local self = Super:new(opts)  -- override 'self' to be the new object/class
  setmetatable(self, TokenFileWebIdentityCredentials)

  opts = opts or {}
  self.token_file = assert(
    opts.token_file or AWS_WEB_IDENTITY_TOKEN_FILE,
    "either 'opts.token_file' or environment variable 'AWS_WEB_IDENTITY_TOKEN_FILE' must be set"
  )
  self.role_arn = assert(
    opts.role_arn or AWS_ROLE_ARN,
    "either 'opts.role_arn' or environment variable 'AWS_ROLE_ARN' must be set"
  )
  self.session_name = opts.session_name or AWS_ROLE_SESSION_NAME

  return self
end

-- updates credentials.
-- @return success, or nil+err
function TokenFileWebIdentityCredentials:refresh()
  if not self.sts then
    -- instantiate on first use. Cannot do this in the constructor, since the
    -- constructor is called when instantiating an AWS instance (creating a loop).
    -- That's because this credentials class is part of the "CredentialProviderChain"
    local AWS = require "resty.aws"
    local aws = AWS {
      region = global_config.region,
      stsRegionalEndpoints = global_config.sts_regional_endpoints,
    }
    local sts, err = aws:STS()
    if not sts then
      error("failed to construct AWS.STS instance: " .. tostring(err))
    end
    self.sts = sts
  end

  local token, err = readfile(self.token_file)
  if not token then
    return nil, "failed reading token file: " .. err
  end

  local response, err = self.sts:assumeRoleWithWebIdentity {
    RoleArn = self.role_arn,
    RoleSessionName = self.session_name,
    WebIdentityToken = token
  }

  if not response then
    return nil, "Request for token data failed: " .. tostring(err)
  end

  if response.status ~= 200 then
    return nil, ("request for token returned '%s': %s"):format(tostring(response.status), response.body)
  end

  local cred = xml.parse(response.body, nil, true):
    child_with_name("AssumeRoleWithWebIdentityResult"):
    child_with_name("Credentials")

  local AccessKeyId = cred:child_with_name("AccessKeyId")[1]
  local SecretAccessKey = cred:child_with_name("SecretAccessKey")[1]
  local SessionToken = cred:child_with_name("SessionToken")[1]
  local Expiration = cred:child_with_name("Expiration")[1]

  self:set(AccessKeyId, SecretAccessKey, SessionToken, Expiration)

  return true
end

return TokenFileWebIdentityCredentials
