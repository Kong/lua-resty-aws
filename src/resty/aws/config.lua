--- Load AWS configuration.
--
-- This is based of [Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
-- and [Environment variables to configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html).
--
-- <h3>Usage</h3>
--
-- Simply collect the global config table:
--     local config = require("resty.aws.config").config
--     print("AWS region: ", (config.region or "failed to detect"))
--
-- <h3>Additional environment variables</h3>
--
-- The following config file entries do not have an environment variable override
-- in the AWS CLI, but this Lua module adds them as follows:
--
-- * `AWS_CLI_TIMESTAMP_FORMAT` will override `cli_timestamp_format`
-- * `AWS_DURATION_SECONDS` will override `duration_seconds`
-- * `AWS_PARAMETER_VALIDATION` will override `parameter_validation`
--
-- <h3>Options processing and naming</h3>
--
-- Some options are available in the config/credential files, some as environment
-- variables, and some in both. The options are processed as follows:
--
-- * profiles will be honored (see environment variable `AWS_PROFILE`)
--
-- * Numeric and boolean values will be converted to their equivalent Lua types
--
-- * properties will have the name as used in the config file, for any property
--   that is a valid config file entry but also has an environment variable override.
--   For example:
--       export AWS_REGION="us-east-1"
--   will be available as `config.global.region` and `config.global.AWS_REGION`,
--   since in the config file the property
--   is named `region`, whilst the environment variable is called `AWS_REGION`.
--
-- * properties that only have environment variable settings (eg. `AWS_SHARED_CREDENTIALS_FILE`)
--   will be added to the config table by their all-caps name.
--   For example:
--       export AWS_SHARED_CREDENTIALS_FILE="~/my_aws_config"
--   will be available as `config.global.AWS_SHARED_CREDENTIALS_FILE`, since
--   there is no config file property in this case.
--
-- <h3>Other system variables</h3>
--
-- The following environment variables are also read (so only loading this config
-- module in the `init` phase will suffice for most use cases):
--
-- * `ECS_CONTAINERMETADATA_URI_V4`
-- * `ECS_CONTAINERMETADATA_URI`
-- * `AMAZON_ACCESS_KEY_ID`
-- * `AMAZON_SECRET_ACCESS_KEY`
-- * `AMAZON_SESSION_TOKEN`
-- * `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`
-- * `AWS_CONTAINER_CREDENTIALS_FULL_URI`


local pl_path = require "pl.path"
local pl_config = require "pl.config"



-- Convention: variable values are stored in the config table by the name of
-- the property in the config file, see https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html#cli-configure-files-settings
-- The variables that do not have an equivalent in the config file get the
-- environment variable name (in all-caps).
local env_vars = {
  -- configuration files and settings
  AWS_CONFIG_FILE = { name = "AWS_CONFIG_FILE", default = "~/.aws/config" },
  AWS_PROFILE = { name = "AWS_PROFILE", default = "default" },

  -- region configuration
  AWS_DEFAULT_REGION = { name = "AWS_DEFAULT_REGION", default = nil },
  AWS_REGION = { name = "region", default = nil }, -- overrides 'default_region'
  AWS_STS_REGIONAL_ENDPOINTS = { name = "sts_regional_endpoints", default = "regional" },

  -- retry logic  -- TODO: implement
  AWS_MAX_ATTEMPTS = { name = "max_attempts", default = 5 }, -- not used
  AWS_RETRY_MODE = { name = "retry_mode", default = "standard" }, -- not used

  -- for use with AssumeRoleWithWebIdentity
  AWS_ROLE_ARN = { name = "role_arn", default = nil },
  AWS_ROLE_SESSION_NAME = { name = "role_session_name", default = nil },
  AWS_WEB_IDENTITY_TOKEN_FILE = { name = "web_identity_token_file", default = nil },

  -- credentials
  AWS_ACCESS_KEY_ID = { name = "aws_access_key_id", default = nil },
  AWS_SECRET_ACCESS_KEY = { name = "aws_secret_access_key", default = nil },
  AWS_SESSION_TOKEN = { name = "aws_session_token", default = nil },
  AWS_SHARED_CREDENTIALS_FILE = { name = "AWS_SHARED_CREDENTIALS_FILE", default = "~/.aws/credentials" },

  -- Misc
  AWS_EC2_METADATA_DISABLED = { name = "AWS_EC2_METADATA_DISABLED", default = false },
  AWS_CA_BUNDLE = { name = "ca_bundle", default = nil }, -- not used
  AWS_CLI_AUTO_PROMPT = { name = "cli_auto_prompt", default = nil }, -- not used
  AWS_CLI_FILE_ENCODING = { name = "AWS_CLI_FILE_ENCODING", default = nil }, -- not used
  AWS_DEFAULT_OUTPUT = { name = "output", default = nil }, -- not used
  AWS_PAGER = { name = "cli_pager", default = nil }, -- not used



  -- Config file options without official environment variable overrides, but adding anyway
  -- so we can set defaults where we need them:

  -- cli_binary_format: default = "base64"
  AWS_CLI_TIMESTAMP_FORMAT = { name = "cli_timestamp_format", default = "iso8601" },
  -- credential_process:
  -- credential_source:
  AWS_DURATION_SECONDS = { name = "duration_seconds", default = 3600 },  -- TODO: implement
  -- external_id:
  -- mfa_serial:
  AWS_PARAMETER_VALIDATION = { name = "parameter_validation", default = true }, -- TODO: implement
  -- source_profile:
  -- sso_account_id:
  -- sso_region:
  -- sso_role_name:
  -- sso_start_url:
  -- tcp_keepalive:
  -- Not listed: the S3 specific settings



  -- Additional environment variables that are NOT part of the CLI configuration.
  -- Adding them here so we get their values in one place (since we need to load in
  -- 'init' phase because envs are not available in later stages)

  -- ECS metadata urls
  ECS_CONTAINERMETADATA_URI_V4 = { name = "ECS_CONTAINERMETADATA_URI_V4", default = nil },
  ECS_CONTAINERMETADATA_URI = { name = "ECS_CONTAINERMETADATA_URI", default = nil },

  -- Variables used in the CredentialProviderChain; EnvironmentCredentials with 'AMAZON' prefix
  AMAZON_ACCESS_KEY_ID = { name = "AMAZON_ACCESS_KEY_ID", default = nil },
  AMAZON_SECRET_ACCESS_KEY = { name = "AMAZON_SECRET_ACCESS_KEY", default = nil },
  AMAZON_SESSION_TOKEN = { name = "AMAZON_SESSION_TOKEN", default = nil },

  -- Variables used in RemoteCredentials (and in the CredentialProviderChain)
  AWS_CONTAINER_CREDENTIALS_RELATIVE_URI = { name = "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI", default = nil },
  AWS_CONTAINER_CREDENTIALS_FULL_URI = { name = "AWS_CONTAINER_CREDENTIALS_FULL_URI", default = nil },
}

-- populate the env vars with their values, or defaults
for var_name, var in pairs(env_vars) do
  var.value = os.getenv(var_name) or var.default
end

-- custom transforms
env_vars.AWS_MAX_ATTEMPTS.value = tonumber(env_vars.AWS_MAX_ATTEMPTS.value) or env_vars.AWS_MAX_ATTEMPTS.default
env_vars.AWS_DURATION_SECONDS.value = tonumber(env_vars.AWS_DURATION_SECONDS.value) or env_vars.AWS_DURATION_SECONDS.value
env_vars.AWS_PARAMETER_VALIDATION.value = (env_vars.AWS_PARAMETER_VALIDATION.value ~= "false")  -- to boolean
env_vars.AWS_EC2_METADATA_DISABLED.value = (env_vars.AWS_EC2_METADATA_DISABLED.value ~= "false")  -- to boolean



local config = {
  env_vars = env_vars
}

do
  -- load a config file. If section given returns section only, otherwise full file.
  -- returns an empty table if the section does not exist
  local function load_file(filename, section)
    assert(type(filename) == "string", "expected filename to be a string")
    if not pl_path.isfile(filename) then
      return nil, "not a file: '"..filename.."'"
    end

    local contents, err = pl_config.read(filename, { variabilize = false })
    if not contents then
      return nil, "failed reading file '"..filename.."': "..tostring(err)
    end

    if not section then
      return contents
    end

    assert(type(section) == "string", "expected section to be a string or falsy")
    if not contents[section] then
      ngx.log(ngx.DEBUG, "section '",section,"' does not exist in file '",filename,"'")
      return {}
    end

    ngx.log(ngx.DEBUG, "loaded section '",section,"' from file '",filename,"'")
    return contents[section]
  end


  --- loads a credential file.
  -- The returned table is a hash table with options. If profiles are returned
  -- then they will be sub-tables, with key "[profile-name]".
  -- @tparam string filename the filename of the credentials file to load
  -- @tparam[opt] string profile the profile to retrieve from the credentials file. If
  -- the profile doesn't exist, then it returns an empty table. Use `default` to get the default profile.
  -- @return table with the contents of the file, or only the profile if a profile was specified or
  -- nil+err if there was a problem loading the file
  function config.load_credentials_file(filename, profile)
    return load_file(filename, profile)
  end


  --- loads a configuration file.
  -- The returned table is a hash table with options. If profiles are returned
  -- then they will be sub-tables, with key "profile [profile-name]".
  -- @tparam string filename the filename of the configuration file to load
  -- @tparam[opt] string profile the profile to retrieve from the configuration file. If
  -- the profile doesn't exist, then it returns an empty table. Use `"default"` to get the default profile.
  -- @return table with the contents of the file, or only the profile if a profile was specified, or
  -- nil+err if there was a problem loading the file
  function config.load_configfile(filename, profile)
    if profile and profile ~= "default" then
      profile = "profile "..profile
    end
    return load_file(filename, profile)
  end
end


--- returns the configuration loaded from the config file.
-- The result is based on `AWS_CONFIG_FILE` and `AWS_PROFILE`. Returns an empty
-- table if the config file does not exist.
-- @return options table as gotten from the configuration file, or nil+err.
function config.load_config()
  if not pl_path.isfile(env_vars.AWS_CONFIG_FILE.value) then
    -- file doesn't exist
    return {}
  end
  return config.load_configfile(env_vars.AWS_CONFIG_FILE.value, env_vars.AWS_PROFILE.value)
end


--- returns the credentials loaded from the config files.
-- Options are based on `AWS_SHARED_CREDENTIALS_FILE` and `AWS_PROFILE`. Falls back to
-- the config file (see `config.load_config`). Returns an empty
-- table if the credentials file does not exist.
-- @return credentials table as gotten from the credentials file, or a table
-- with the key, id, and token from the configuration file, table can be empty.
function config.load_credentials()
  if pl_path.isfile(env_vars.AWS_SHARED_CREDENTIALS_FILE.value) then
    local creds = config.load_credentials_file(env_vars.AWS_SHARED_CREDENTIALS_FILE.value, env_vars.AWS_PROFILE.value)
    if creds then -- ignore error, already logged
      return creds
    end
  end

  -- fall back to config file
  local config = config.load_config() or {}  -- ignore error, already logged

  return {
    aws_access_key_id = config.aws_access_key_id,
    aws_secret_access_key = config.aws_secret_access_key,
    aws_session_token = config.aws_session_token,
  }
end


--- returns the current configuration.
-- Reads the configuration files (config + credentials) and overrides them with
-- any environment variables specified, or defaults.
--
-- NOTE: this will not auto-detect the region. Use `resty.aws.utils.getCurrentRegion`
-- for that, or get the `config.global` table which will auto-detect.
-- @return table with configuration options, table can be empty.
-- @usage
-- local config = require("resty.aws.config").config       -- does auto-detect region
--
-- -- is equivalent to:
-- local config = require("resty.aws.config").get_config()
-- if not config.region then
--     config.region = utils.getCurrentRegion()
-- end
function config.get_config()
  local cfg = config.load_config() or {}   -- ignore error, already logged

  if pl_path.isfile(env_vars.AWS_SHARED_CREDENTIALS_FILE.value) then
    -- there is a creds file, so override creds with creds file
    local creds = config.load_credentials_file(
      env_vars.AWS_SHARED_CREDENTIALS_FILE.value, env_vars.AWS_PROFILE.value)  -- ignore error, already logged
    if creds then
      cfg.aws_access_key_id = creds.aws_access_key_id
      cfg.aws_secret_access_key = creds.aws_secret_access_key
      cfg.aws_session_token = creds.aws_session_token
    end
  end

  -- add environment variables
  for var_name, var in pairs(env_vars) do
    if cfg[var_name] == nil then  -- add the environment variable name with value
      cfg[var_name] = var.value
    end
    if cfg[var.name] == nil then  -- add the config file name with value
      cfg[var.name] = var.value
    end
  end
  if cfg.region == nil then
    cfg.region = cfg.AWS_DEFAULT_REGION
  end

  return cfg
end


--- returns the credentials from config file, credential file, or environment variables.
-- Reads the configuration files (config + credentials) and overrides them with
-- any environment variables specified.
-- @return table with credentials (`aws_access_key_id`, `aws_secret_access_key`, and `aws_session_token`)
function config.get_credentials()
  local creds = {
    aws_access_key_id = env_vars.AWS_ACCESS_KEY_ID.value,
    aws_secret_access_key = env_vars.AWS_SECRET_ACCESS_KEY.value,
    aws_session_token = env_vars.AWS_SESSION_TOKEN,
  }
  if next(creds) then
    -- isn't empty, so return it
    return creds
  end

  -- nothing in env-vars, so return config file data
  return config.load_credentials()
end

-- @field global configuration
-- @table somename
config.global = {}  -- trick LuaDoc
config.global = nil

return setmetatable(config, {
  __index = function(self, key)
    if key ~= "global" then
      return nil
    end
    -- Build the global config on demand since there is a recursive relation
    -- between this module and the utils module.
    self.global = assert(self.get_config())
    if not self.global.region then
      local utils = require "resty.aws.utils"
      self.global.region = utils.getCurrentRegion()
    end
    return self.global
  end
})






