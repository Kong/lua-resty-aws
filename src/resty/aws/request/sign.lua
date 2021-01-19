
-- table with signature functions, loaded on demand. Additional signatures can be
-- implemented as modules. Typically the key would be "v4", "v3", etc.
local signatures = setmetatable({}, {
  __index = function(self, key)
    -- if we do not have a specific signature version, then load it
    assert(type(key) == "string", "the signature type must be a string")
    local ok, mod = pcall(require, "resty.aws.request.signatures." .. key)
    if not ok then
      return error("AWS signature version '"..key.."' does not exist or hasn't been implemented")
    end
    rawset(self, key, mod)
    return mod
  end
})


return function(config, request)
  -- the 'nil' string is to ensure the __index method of 'signatures' throws the
  -- proper error message.
  return signatures[config.signatureVersion or "nil"](config, request)
end
