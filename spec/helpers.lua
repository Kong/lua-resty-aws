local ffi = require "ffi"


local M = {}


ffi.cdef [[
  int setenv(const char *name, const char *value, int overwrite);
  int unsetenv(const char *name);
]]

local function unsetenv(env)
  assert(type(env) == "string", "expected env name to be a string")
  return ffi.C.unsetenv(env) == 0
end

local function setenv(env, value)
  assert(type(env) == "string", "expected env name to be a string")
  if value == nil then
    return unsetenv(env)
  end
  assert(type(value) == "string", "expected value to be a string (or nil to clear)")
  return ffi.C.setenv(env, value, 1) == 0
end

local original_env_values = {}
local nil_sentinel = {}
local function backup_env(name)
  original_env_values[name] = original_env_values[name] or os.getenv(name) or nil_sentinel
end


-- sets an environment variable, set to nil to remove it
function M.setenv(env, value)
  assert(type(env) == "string", "expected env name to be a string")
  assert(type(value) == "string" or value == nil, "expected value to be a string (or nil to clear)")
  backup_env(env)
  setenv(env, value)
end


-- unsets an environment variable
function M.unsetenv(env)
  assert(type(env) == "string", "expected env name to be a string")
  backup_env(env)
  unsetenv(env)
end


-- gets an environment variable
M.getenv = os.getenv  -- for symetry; get/set/unset


-- restores all env vars to original values and clears all loaded 'resty.aws' modules
function M.restore()
  for name, value in pairs(original_env_values) do
    setenv(name, value ~= nil_sentinel and value or nil)
  end
  for name, mod in pairs(package.loaded) do
    if type(name) == "string" and (name:match("^resty%.aws$") or name:match("^resty%.aws%.")) then
      package.loaded[name] = nil
    end
  end
  collectgarbage()
  collectgarbage()

  -- disable EC2 metadata
  setenv("AWS_EC2_METADATA_DISABLED", "true")
end

return setmetatable(M, {
  __call = function(self, ...)
    return self.restore(...)
  end
})
