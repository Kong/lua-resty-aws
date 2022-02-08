local pl_path = require("pl.path")
local pl_utils = require("pl.utils")
local d = require("pl.text").dedent

local setenv, unsetenv do
  local ffi = require "ffi"

  ffi.cdef [[
    int setenv(const char *name, const char *value, int overwrite);
    int unsetenv(const char *name);
  ]]

  function setenv(env, value)
    return ffi.C.setenv(env, value, 1) == 0
  end
  function unsetenv(env)
    return ffi.C.unsetenv(env) == 0
  end
end


-- clear all modules already loaded
local function clear_modules()
  for name, mod in pairs(package.loaded) do
    if type(name) == "string" and (name:match("^resty%.aws$") or name:match("^resty%.aws%.")) then
      package.loaded[name] = nil
    end
  end
  collectgarbage()
  collectgarbage()
end

describe("config loader", function()

  local config_info = d[[
    [default]
    region=eu-central-1
    max_attempts=99

    [profile tieske]
    region=us-west-1
  ]]
  local config_filename = pl_path.tmpname()

  local config
  before_each(function()
    clear_modules()
    pl_utils.writefile(config_filename, config_info)
  end)

  after_each(function()
    clear_modules()
    config = nil
    os.remove(config_filename)
  end)

  it("sets defaults", function()
    setenv("AWS_CONFIG_FILE", config_filename)
    setenv("AWS_DEFAULT_REGION", "eu-west-1")
    finally(function()
      unsetenv("AWS_CONFIG_FILE")
      unsetenv("AWS_DEFAULT_REGION")
    end)

    os.remove(config_filename) -- delete the file so we revert to defaults
    config = require "resty.aws.config"
    local conf = assert(config())

    -- just calling out as separate test; picking default region
    assert.equal("eu-west-1", conf.region)

    -- all defaults
    assert.same({
      AWS_DEFAULT_REGION = "eu-west-1",
      region = "eu-west-1",
      AWS_CONFIG_FILE = config_filename,
      AWS_EC2_METADATA_DISABLED = false,
      AWS_PROFILE = 'default',
      AWS_SHARED_CREDENTIALS_FILE = '~/.aws/credentials',
      cli_timestamp_format = 'iso8601',
      duration_seconds = 3600,
      max_attempts = 5,
      parameter_validation = true,
      retry_mode = 'standard',
      sts_regional_endpoints = 'regional'
    }, conf)
  end)

  it("loads the configuration; default profile", function()
    setenv("AWS_CONFIG_FILE", config_filename)
    finally(function()
      unsetenv("AWS_CONFIG_FILE")
    end)
    config = require "resty.aws.config"
    local conf = assert(config())

    -- from the config file; default profile
    assert.equal("eu-central-1", conf.region)
    assert.equal(99, conf.max_attempts)

    assert.same({
      AWS_CONFIG_FILE = config_filename,
      AWS_EC2_METADATA_DISABLED = false,
      AWS_PROFILE = 'default',
      AWS_SHARED_CREDENTIALS_FILE = '~/.aws/credentials',
      cli_timestamp_format = 'iso8601',
      duration_seconds = 3600,
      max_attempts = 99,
      region = "eu-central-1",
      parameter_validation = true,
      retry_mode = 'standard',
      sts_regional_endpoints = 'regional'
    }, conf)
  end)

  it("loads the configuration; 'tieske' profile", function()
    setenv("AWS_CONFIG_FILE", config_filename)
    setenv("AWS_PROFILE", "tieske")
    finally(function()
      unsetenv("AWS_CONFIG_FILE")
      unsetenv("AWS_PROFILE")
    end)
    config = require "resty.aws.config"
    local conf = assert(config())

    -- from the config file; profile 'tieske'
    assert.equal("us-west-1", conf.region)

    assert.same({
      AWS_CONFIG_FILE = config_filename,
      AWS_EC2_METADATA_DISABLED = false,
      AWS_PROFILE = 'tieske',
      AWS_SHARED_CREDENTIALS_FILE = '~/.aws/credentials',
      cli_timestamp_format = 'iso8601',
      duration_seconds = 3600,
      max_attempts = 5,
      region = "us-west-1",
      parameter_validation = true,
      retry_mode = 'standard',
      sts_regional_endpoints = 'regional'
    }, conf)
  end)

end)
