local pl_path = require("pl.path")
local pl_utils = require("pl.utils")
local d = require("pl.text").dedent
local restore = require "spec.helpers"


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
    restore()
    pl_utils.writefile(config_filename, config_info)
  end)

  after_each(function()
    restore()
    config = nil
    os.remove(config_filename)
  end)

  it("sets defaults", function()
    restore.setenv("AWS_CONFIG_FILE", config_filename)
    restore.setenv("AWS_DEFAULT_REGION", "eu-west-1")

    os.remove(config_filename) -- delete the file so we revert to defaults
    config = require "resty.aws.config"
    local conf = assert(config.get_config())

    -- just calling out as separate test; picking default region
    assert.equal("eu-west-1", conf.region)

    -- all defaults
    assert.same({
      AWS_DEFAULT_REGION = "eu-west-1",
      region = "eu-west-1",
      AWS_CONFIG_FILE = config_filename,
      AWS_EC2_METADATA_DISABLED = true,
      AWS_PROFILE = 'default',
      AWS_SHARED_CREDENTIALS_FILE = '~/.aws/credentials',
      cli_timestamp_format = 'iso8601',
      AWS_CLI_TIMESTAMP_FORMAT = 'iso8601',
      duration_seconds = 3600,
      AWS_DURATION_SECONDS = 3600,
      max_attempts = 5,
      AWS_MAX_ATTEMPTS = 5,
      parameter_validation = true,
      AWS_PARAMETER_VALIDATION = true,
      retry_mode = 'standard',
      AWS_RETRY_MODE = 'standard',
      sts_regional_endpoints = 'regional',
      AWS_STS_REGIONAL_ENDPOINTS = 'regional',
    }, conf)
  end)

  it("loads the configuration; default profile", function()
    restore.setenv("AWS_CONFIG_FILE", config_filename)
    config = require "resty.aws.config"
    local conf = assert(config.get_config())

    -- from the config file; default profile
    assert.equal("eu-central-1", conf.region)
    assert.equal(99, conf.max_attempts)

    assert.same({
      AWS_CONFIG_FILE = config_filename,
      AWS_EC2_METADATA_DISABLED = true,
      AWS_PROFILE = 'default',
      AWS_SHARED_CREDENTIALS_FILE = '~/.aws/credentials',
      cli_timestamp_format = 'iso8601',
      AWS_CLI_TIMESTAMP_FORMAT = 'iso8601',
      duration_seconds = 3600,
      AWS_DURATION_SECONDS = 3600,
      max_attempts = 99,
      AWS_MAX_ATTEMPTS = 5,
      region = "eu-central-1",
      parameter_validation = true,
      AWS_PARAMETER_VALIDATION = true,
      retry_mode = 'standard',
      AWS_RETRY_MODE = 'standard',
      sts_regional_endpoints = 'regional',
      AWS_STS_REGIONAL_ENDPOINTS = 'regional',
    }, conf)
  end)

  it("loads the configuration; 'tieske' profile", function()
    restore.setenv("AWS_CONFIG_FILE", config_filename)
    restore.setenv("AWS_PROFILE", "tieske")
    config = require "resty.aws.config"
    local conf = assert(config.get_config())

    -- from the config file; profile 'tieske'
    assert.equal("us-west-1", conf.region)

    assert.same({
      AWS_CONFIG_FILE = config_filename,
      AWS_EC2_METADATA_DISABLED = true,
      AWS_PROFILE = 'tieske',
      AWS_SHARED_CREDENTIALS_FILE = '~/.aws/credentials',
      cli_timestamp_format = 'iso8601',
      AWS_CLI_TIMESTAMP_FORMAT = 'iso8601',
      duration_seconds = 3600,
      AWS_DURATION_SECONDS = 3600,
      max_attempts = 5,
      AWS_MAX_ATTEMPTS = 5,
      region = "us-west-1",
      parameter_validation = true,
      AWS_PARAMETER_VALIDATION = true,
      retry_mode = 'standard',
      AWS_RETRY_MODE = 'standard',
      sts_regional_endpoints = 'regional',
      AWS_STS_REGIONAL_ENDPOINTS = 'regional',
    }, conf)
  end)

  it("global field returns the global configuration", function()
    config = require "resty.aws.config"
    local conf = config.global

    assert.same({
      region = nil, -- detection should fail
      AWS_CONFIG_FILE = "~/.aws/config",
      AWS_EC2_METADATA_DISABLED = true,
      AWS_PROFILE = 'default',
      AWS_SHARED_CREDENTIALS_FILE = '~/.aws/credentials',
      cli_timestamp_format = 'iso8601',
      AWS_CLI_TIMESTAMP_FORMAT = 'iso8601',
      duration_seconds = 3600,
      AWS_DURATION_SECONDS = 3600,
      max_attempts = 5,
      AWS_MAX_ATTEMPTS = 5,
      parameter_validation = true,
      AWS_PARAMETER_VALIDATION = true,
      retry_mode = 'standard',
      AWS_RETRY_MODE = 'standard',
      sts_regional_endpoints = 'regional',
      AWS_STS_REGIONAL_ENDPOINTS = 'regional',
    }, conf)

  end)

end)
