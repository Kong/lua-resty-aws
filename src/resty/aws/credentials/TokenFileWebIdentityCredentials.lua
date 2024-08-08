--- TokenFileWebIdentityCredentials class.
-- @classmod TokenFileWebIdentityCredentials

local readfile = require("pl.utils").readfile
local cjson = require("cjson")

local aws_config = require("resty.aws.config")


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
    opts.token_file or aws_config.global.AWS_WEB_IDENTITY_TOKEN_FILE,
    "either 'opts.token_file' or environment variable 'AWS_WEB_IDENTITY_TOKEN_FILE' must be set"
  )
  self.role_arn = assert(
    opts.role_arn or aws_config.global.AWS_ROLE_ARN,
    "either 'opts.role_arn' or environment variable 'AWS_ROLE_ARN' must be set"
  )
  self.session_name = opts.session_name or aws_config.global.AWS_ROLE_SESSION_NAME or "session@lua-resty-aws"

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
      region = aws_config.global.region,
      stsRegionalEndpoints = aws_config.global.sts_regional_endpoints,
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

  if type(response.body) ~= "string" then
    return nil, "request for token returned invalid body: " .. err
  end

  local data, err = cjson.decode(response.body)
  if not data then
    return nil, "failed to parse response body: " .. err
  end
  local credentials = data.AssumeRoleResponse.AssumeRoleResult.Credentials
  self:set(
    credentials.AccessKeyId,
    credentials.SecretAccessKey,
    credentials.SessionToken,
    credentials.Expiration
  )

  return true
end

return TokenFileWebIdentityCredentials
