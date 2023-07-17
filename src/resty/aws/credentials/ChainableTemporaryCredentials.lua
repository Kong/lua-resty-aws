--- ChainedTemporaryCredentials class.
-- @classmod ChainedTemporaryCredentials

local lom = require("lxp.lom")


-- Create class
local Super = require "resty.aws.credentials.Credentials"
local ChainedTemporaryCredentials = setmetatable({}, Super)
ChainedTemporaryCredentials.__index = ChainedTemporaryCredentials


--- Constructor, inherits from `Credentials`.
-- @function aws:ChainableTemporaryCredentials
-- @param opt options table, additional fields to the `Credentials` class:
-- @param opt.params params table for the `assumeRole` function, or array of those
-- tables in case of a chain of roles to assume.
-- @param opt.aws `AWS` instance, required when creating a chain.
-- @param opt.masterCredentials `Credentials` instance to use when assuming the
-- role. Defaults to `sts.config.credentials` or `aws.config.credentials` in that
-- order.
-- @param opt.sts the `STS` service instance to use for fetching the credentials.
-- Defaults to a new instance created as `aws:STS()`.
-- @usage -- creating a chain of assumed roles
-- local aws = AWS()      -- provides the masterCredentials
-- local role1 = { ... }  -- parameters to assume role1, from the masterCredentials
-- local role2 = { ... }  -- parameters to assume role2, from the role1 credentials
-- local role3 = { ... }  -- parameters to assume role3, from the role2 credentials
--
-- local creds = aws:ChainableTemporaryCredentials {
--     params = { role1, role2, role3 },
--   }
--
-- -- Get credentials for role3
-- local success, id, key, token, expiretime = creds:get()
-- if not success then
--   return nil, id
-- end

function ChainedTemporaryCredentials:new(opts)
  local self = Super:new(opts)  -- override 'self' to be the new object/class
  setmetatable(self, ChainedTemporaryCredentials)

  opts = opts or {}

  assert(opts.tokenCodeFn == nil, "Option 'opts.tokenCodeFn' is not supported.")

  -- get the master credentials to use
  local mCredentials = opts.masterCredentials
  if not mCredentials and opts.sts then
    mCredentials = ((opts.sts or {}).config or {}).credentials
  end
  if not mCredentials and opts.aws then
    mCredentials = ((opts.aws or {}).config or {}).credentials
  end
  assert(type(mCredentials) == "table", "No master-credentials provided, either 'opts.masterCredentials', 'opts.aws', or 'opts.sts' options must be set")

  -- get array of params-tables
  local params = opts.params
  assert(type(params) == "table", "Expected 'opts.params' to be a parameter table/map or an array of parameter tables/maps")
  if not params[1] then
    -- not an array, so a parameter table/map, make it an array
    params = { params }
  end

  -- get the STS service instance to use
  local sts = opts.sts
  if sts then
    assert(#params == 1, "Cannot use 'opts.sts' to create a chain, only specify a single 'opts.params' entry, or specify 'opts.aws' instead of 'opts.sts'.")
  else
    if opts.aws then
      local err
      sts, err = opts.aws:STS()
      if not sts then
        error("failed to create STS instance: " .. tostring(err))
      end
    end
  end
  assert(type(sts) == "table", "No STS service, either 'opts.sts' or 'opts.aws' option must be set")

  if #params == 1 then
    -- there is only 1 role to assume so that is us.
    -- self.aws = aws
    self.sts = sts
    self.params = params[1]
    self.masterCredentials = mCredentials
  else
    -- multiple roles to assume, so pick the last and create a sub-credential
    -- self.aws = aws
    self.sts = sts
    self.params = params[#params]
    params[#params] = nil
    self.masterCredentials = ChainedTemporaryCredentials:new {
      masterCredentials = mCredentials,
      params = params,
      aws = opts.aws,
    }
  end

  return self
end


-- updates credentials.
-- @return success, or nil+err
function ChainedTemporaryCredentials:refresh()
  local response, err = self.sts:assumeRole(self.params)
  if not response then
    return nil, "Request for token data failed: " .. tostring(err)
  end

  if response.status ~= 200 then
    return nil, ("request for token returned '%s': %s"):format(tostring(response.status), response.body)
  end

  if type(response.body) ~= "string" then
    return nil, "request for token returned invalid body: " .. err
  end

  local resp_body_lom, err = lom.parse(response.body)
  if not resp_body_lom then
    return nil, "failed to parse response body: " .. err
  end

  local cred_lom = lom.find_elem(lom.find_elem(resp_body_lom, "AssumeRoleResult"), "Credentials")

  local AccessKeyId = lom.find_elem(cred_lom, "AccessKeyId")[1]
  local SecretAccessKey = lom.find_elem(cred_lom, "SecretAccessKey")[1]
  local SessionToken = lom.find_elem(cred_lom, "SessionToken")[1]
  local Expiration = lom.find_elem(cred_lom, "Expiration")[1]

  self:set(AccessKeyId, SecretAccessKey, SessionToken, Expiration)

  return true
end

return ChainedTemporaryCredentials
