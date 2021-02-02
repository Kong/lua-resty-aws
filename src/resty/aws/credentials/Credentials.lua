--- Credentials class.
-- Manually sets credentials.
-- Also the base class for all credential classes.
-- @classmod Credentials
local parse_date = require("luatz").parse.rfc_3339
local semaphore = require "ngx.semaphore"


local SEMAPHORE_TIMEOUT = 30 -- semaphore timeout in seconds

-- Executes a xpcall but returns hard-errors as Lua 'nil+err' result.
-- Handles max of 10 return values.
-- @param f function to execute
-- @param ... parameters to pass to the function
local function safe_call(f, ...)
  local ok, result, err, r3, r4, r5, r6, r7, r8, r9, r10 = xpcall(f, debug.traceback, ...)
  if ok then
    return result, err, r3, r4, r5, r6, r7, r8, r9, r10
  end
  return nil, result
end


local Credentials = {}
Credentials.__index = Credentials

--- Constructor.
-- @function aws:Credentials
-- @param opt options table
-- @param opt.expiryWindow number (default 15) of seconds before expiry to start refreshing
-- @param opt.accessKeyId (optional) only specify if you manually specify credentials
-- @param opt.secretAccessKey (optional) only specify if you manually specify credentials
-- @param opt.sessionToken (optional) only specify if you manually specify credentials
-- @param opt.expireTime (optional, number (epoch) or string (rfc3339)). This should
-- not be specified. Default: If any of the 3 secrets are given; 10yrs, otherwise 0
-- (forcing a refresh on the first call to `get`).
-- @usage
-- local my_creds = aws:Credentials {
--   accessKeyId = "access",
--   secretAccessKey = "secret",
--   sessionToken = "token",
-- }
--
-- local success, id, secret, token = my_creds:get()
function Credentials:new(opts)
  local self = {}  -- override 'self' to be the new object/class
  setmetatable(self, Credentials)

  opts = opts or {}
  if opts.aws then
    if getmetatable(opts.aws) ~= require("resty.aws") then
      error("'opts.aws' must be set to an AWS instance or nil")
    end
    self.aws = opts.aws
  end

  if opts.accessKeyId or opts.secretAccessKey or opts.sessionToken then
    -- credentials provided, if no expire given then use 10 yrs
    self:set(opts.accessKeyId, opts.secretAccessKey, opts.sessionToken,
             opts.expireTime or (ngx.now() + 10*365*24*60*60))
  else
    self.accessKeyId = nil
    self.secretAccessKey = nil
    self.sessionToken = nil
    self.expireTime = 0  -- force refresh on next "get"
  end
  -- self.expired     -- not implemented
  self.expiryWindow = opts.expiryWindow or 15 -- time in seconds befoer expireTime creds should be refreshed

  return self
end

--- checks whether credentials have expired.
-- @return boolean
function Credentials:needsRefresh()
  return (self.expireTime or 0) < (ngx.now() + self.expiryWindow)
end

--- Gets credentials, refreshes if required.
-- Returns credentials, doesn't take a callback like AWS SDK.
--
-- When a refresh is executed, it will be done within a semaphore to prevent
-- many simultaneous refreshes.
-- @return success(true) + accessKeyId + secretAccessKey + sessionToken + expireTime or success(false) + error
function Credentials:get()
  while self:needsRefresh() do
    if self.semaphore then
      -- an update is in progress
      local ok, err = self.semaphore:wait(SEMAPHORE_TIMEOUT)
      if not ok then
        ngx.log(ngx.ERR, "[Credentials ", self.type, "] waiting for semaphore failed: ", err)
        return nil, "waiting for semaphore failed: " .. tostring(err)
      end
    else
      -- no update in progress
      local sema, err = semaphore.new()
      self.semaphore = sema
      if not sema then
        return nil, "create semaphore failed: " .. tostring(err)
      end

      local ok, err = safe_call(self.refresh, self)

      -- release all waiting threads
      self.semaphore = nil
      sema:post(math.abs(sema:count())+1)

      if not ok then return
        nil, err
      end
      break
    end
  end
  -- we always return a boolean successvalue, if we would rely on standard Lua
  -- "nil + err" behaviour, then if the accessKeyId happens to be 'nil' for some
  -- reason, we risk logging the secretAccessKey as the error message in some
  -- client code.
  return true, self.accessKeyId, self.secretAccessKey, self.sessionToken, self.expireTime
end

--- Sets credentials.
-- additional to AWS SDK
-- @param accessKeyId
-- @param secretAccessKey
-- @param sessionToken
-- @param expireTime (optional) number (unix epoch based), or string (valid rfc 3339)
-- @return true
function Credentials:set(accessKeyId, secretAccessKey, sessionToken, expireTime)
  -- TODO: should we be parsing the token (if given) to get the expireTime?
  local expiration
  if type(expireTime) == "string" then
    expiration = parse_date(expireTime):timestamp()
  end
  if type(expireTime) == "number" then
    expiration = expireTime
  end
  if not expiration then
    error("expected expireTime to be a number (unix epoch based), or string (valid rfc 3339)", 2)
  end

  self.expireTime = expiration
  self.accessKeyId = accessKeyId
  self.secretAccessKey = secretAccessKey
  self.sessionToken = sessionToken
  return true
end

--- updates credentials.
-- override in subclasses, should call `set` to set the properties.
-- @return success, or nil+err
function Credentials:refresh()
  error("Not implemented")
end

-- not implemented
function Credentials:getPromise()
  error("Not implemented")
end
function Credentials:refreshPromise()
  error("Not implemented")
end

return Credentials
