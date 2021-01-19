--- AWS class.
-- @classmod AWS

local validate_input = require("resty.aws.request.validate")
local build_request = require("resty.aws.request.build")
local sign_request = require("resty.aws.request.sign")
local execute_request = require("resty.aws.request.execute")
local split = require("pl.utils").split
local cjson = require "cjson.safe"



-- case-insensitive lookup help.
-- always throws an error!
local lookup_helper = function(self, key)  -- signature to match __index meta-method
  if type(key) == "string" then
    local lckey = key:lower()
    for k,v in pairs(self) do
      if type(k) == "string" and k:lower() == lckey then
        error(("key '%s' not found, did you mean '%s'?"):format(key, k), 2)
      end
    end
  end
  error(("key '%s' not found"):format(tostring(key)), 2)
end


-- dereference all "shape" properties in an AWS service definition. This
-- is done in-place.
local function dereference_service(service)

  local function dereference_shapes(service, shapes)
    for key, value in pairs(service) do
      if key == "documentation" then service[key] = nil end -- drop documentation
      if type(value) == "table" then
        local recurse = true
        if value.shape then
          value.documentation = nil

          local shape = shapes[value.shape]
          if not shape then
            --print("shape: ",value.shape, " is undefined")
            value.shape_undefined = value.shape
            value.shape = nil
          else
            value.shape = nil
            if next(value) then -- not empty...
              -- go copy them in here
              for k,v in pairs(shape) do
                value[k] = v
              end
            else
              -- empty, table just holds "shape", replace by ref
              service[key] = shape
              recurse = false
            end
          end
        end
        -- recurse for this sub-table
        if recurse then dereference_shapes(value, shapes) end
      end
    end
  end

  dereference_shapes(service, service.shapes)
  service.shapes = nil
end

local AWS = {}
AWS.__index = lookup_helper



local aws_config do
  aws_config = {
    region = require("resty.aws.raw-api.region_config_data"),
    api = {},
  }

  -- The API table is a map, where the index is the service-name. The value is a table.
  -- The table is another map, indexed by version (string). The value of that one
  -- is the raw AWS api.
  -- That raw-api is loaded upon demand by meta-table magic so we only load what we need.
  local list = require("resty.aws.raw-api.table_of_contents")
  for i, filename in ipairs(list) do
    -- example filename: "AWSMigrationHub-2017-05-31"
    local module_name = "resty.aws.raw-api." .. filename
    -- example module_name: "resty.aws.raw-api.AWSMigrationHub-2017-05-31"
    local service_name, version = assert(filename:match("^(.-)%-(%d%d%d%d%-%d%d%-%d%d)$"))
    -- example service_name: "AWSMigrationHub"
    -- example version: "2017-05-31"
    local service_table = aws_config.api[service_name]
    if not service_table then
      service_table = {}
      aws_config.api[service_name] = service_table
    end
    -- load the file and dereference shapes
    local api = require(module_name)
    dereference_service(api)

    service_table[version] = api

    if service_table.latest then
      -- update 'latest' if this one is newer
      if service_table.latest.metadata.apiVersion < version then
        service_table.latest = api
      end
    else
      -- we're the only one, and hence also 'latest' so far
      service_table.latest = api
    end
  end
end



-- JS copied



do
  local function generateRegionPrefix(region)
    if not region then
      return nil, "no region given"
    end

    local parts = split(region, "-", true)
    if #parts < 3 then
      return nil, "not a valid region, only 2 parts; "..region
    end
    parts[#parts] = "*"
    return table.concat(parts, "-")
  end


  local function derivedKeys(service)
    local region = service.config.region  -- look s like a configuration for and instance of a service???
    local regionPrefix = generateRegionPrefix(region) -- this can return nil !
    local endpointPrefix = service.api.metadata.endpointPrefix   -- looks like it comes from the services table

    local result = {}
    if region       and endpointPrefix then result[#result+1] = region.."/"..endpointPrefix end
    if regionPrefix and endpointPrefix then result[#result+1] = regionPrefix.."/"..endpointPrefix end
    if region                          then result[#result+1] = region.."/*" end
    if regionPrefix                    then result[#result+1] = regionPrefix.."/*" end
    if endpointPrefix                  then result[#result+1] = "*/"..endpointPrefix end
    result[#result+1] = "*/*"
    return result
  end


  -- copy properties of 'config' into 'service.config' if not already set
  -- (so essentially 'config' contains the default values to use)
  local function applyConfig(service_config, config)
    for key, value in pairs(config) do
      if key ~= "globalEndpoint" then
        service_config[key] = service_config[key] or value
      end
    end
  end


  function AWS.configureEndpoint(service)
    local keys = derivedKeys(service)  -- there should be a 'service.config.region' field...
    for i, key in ipairs(keys) do

      local region_rule_config = aws_config.region.rules[key]
      if type(region_rule_config) == 'string' then
        -- it's a reference, resolve it
        region_rule_config = aws_config.region.patterns[region_rule_config]
      end

      if region_rule_config then
        -- set dualstack endpoint
        --[[  not supported for now....
        if (service.config.useDualstack && util.isDualstackAvailable(service)) {
          config = util.copy(config);
          config.endpoint = config.endpoint.replace(
            /{service}\.({region}\.)?/,
            '{service}.dualstack.{region}.'
          );
        }
        --]]

        -- set global endpoint
        service.isGlobalEndpoint = not not region_rule_config.globalEndpoint
        if region_rule_config.signingRegion then
          service.signingRegion = region_rule_config.signingRegion
        end

        -- signature version
        if not region_rule_config.signatureVersion then
          region_rule_config.signatureVersion = 'v4'
        end

        -- merge config
        applyConfig(service.config, region_rule_config)
        return
      end
    end
  end
end



do
  local defaultSuffix = 'amazonaws.com'
  local regionRegexes = {
    { '^(us|eu|ap|sa|ca|me)\\-\\w+\\-\\d+$', 'amazonaws.com' },
    { '^cn\\-\\w+\\-\\d+$', 'amazonaws.com.cn' },
    { '^us\\-gov\\-\\w+\\-\\d+$', 'amazonaws.com' },
    { '^us\\-iso\\-\\w+\\-\\d+$', 'c2s.ic.gov' },
    { '^us\\-isob\\-\\w+\\-\\d+$', 'sc2s.sgov.gov' }
  }

  -- Get the endpoint suffix for a region.
  -- @param region the region identifier, eg. "us-east-1"
  -- @return endpoint suffix; eg. "amazonaws.com", "amazonaws.com.cn", etc
  function AWS.getEndpointSuffix(region)
    for _, entry in ipairs(regionRegexes) do
      if ngx.re.match(region, entry[1], "jo") then
        return entry[2]
      end
    end
    return defaultSuffix;
  end
end



-- written from scratch



-- Generate a function for each operation in the service api "operations" table
local function generate_service_methods(service)
  for _, operation in pairs(service.api.operations) do

    -- decapitalize first character of method names to mimic JS sdk
    local method_name = operation.name:sub(1,1):lower() .. operation.name:sub(2,-1)

    local operation_prefix = ("%s:%s()"):format(
                              service.api.metadata.serviceId:gsub(" ",""),
                              method_name)

    service[method_name] = function(self, params)

      --print(require("pl.pretty").write(self.config))

      -- validate parameters
      local ok, err = validate_input(params, operation.input, "params")
      if not ok then
        return nil, operation_prefix .. " validation error: " .. tostring(err)
      end

      -- generate request data and format it according to the protocol
      local request = build_request(operation, self.config, params)

      -- sign the request according to the signature version required
      local signed_request = sign_request(self.config, request)

      --print(require("pl.pretty").write(signed_request))

      -- execute the request
      local response, err = execute_request(signed_request)
      if not response then
        return nil, operation_prefix .. " " .. tostring(err)
      end

      return response
    end
  end
end


--- Creates a new AWS instance.
-- By default the instance will get a `CredentialProviderChain` set of
-- credentials, which can be overridden.
--
-- Note that the AWS objects as well as the Service objects are expensive to
-- create, so you might want to reuse them.
-- @param config (optional) the config table to be copied into the instance as the global `aws_instance.config`
-- @usage
-- local AWS = require("AWS")
--
-- local aws = AWS(config)
-- -- or similarly
-- local aws = AWS:new(config)
--
-- -- Override default "CredentialProviderChain" credentials
-- local my_creds = aws:Credentials {
--   accessKeyId = "access",
--   secretAccessKey = "secret",
--   sessionToken = "token",
-- }
-- aws.config.credentials = my_creds
--
-- -- instantiate a service (optionally overriding the global config)
-- local sm = aws:SecretsManager {
--   region = "us-east-2",
-- }
--
-- -- Invoke a method
-- local results, err = sm:GetSecretValue {
--   SecretId = "arn:aws:secretsmanager:us-east-2:238406704566:secret:test-HN1F1k",
-- })
function AWS:new(config)
  if self ~= AWS then
    error("must instantiate AWS instances by calling AWS(config) or AWS:new(config)", 2)
  end

  local aws_instance = setmetatable({
    config = {
      apiVersion = "latest",     -- default to latest version
    }
  }, AWS)

  -- inject global AWS config
  for k,v in pairs(config or {}) do
    aws_instance.config[k] = v
  end

  -- create service methods/constructors
  for service_name, versions in pairs(aws_config.api) do
    -- Create service specific functions, by `serviceId`

    local serviceId = versions[next(versions)].metadata.serviceId
    local cleanId = serviceId:gsub(" ", "") -- for interface drop all spaces

    aws_instance[cleanId] = function(aws, config)
      if getmetatable(aws) ~= AWS then
        error("must instantiate AWS services by calling aws_instance:ServiceName(config)", 2)
      end
      -- create a service config table
      local service_config = {
        aws = aws  -- store parent aws instance
      }
      -- first copy the aws_instance config elements
      for k,v in pairs(aws_instance.config) do
        assert(k ~= "aws", "'config.aws' found, cannot override the aws instance")
        service_config[k] = v
      end
      -- then add/overwrite with provided config
      for k,v in pairs(config or {}) do
        service_config[k] = v
      end

      -- create the service
      -- `config.apiVersion`: the api version to use
      local api = versions[service_config.apiVersion]
      if not api then
        return nil, ("service '%s' does not have an apiVersion '%s'"):format(serviceId, tostring(service_config.apiVersion))
      end
      if service_config.apiVersion == "latest" then
        service_config.apiVersion = api.metadata.apiVersion
      end

      -- apply metadata
      for k,v in pairs(api.metadata) do
        service_config[k] = service_config[k] or v
      end

      local service_instance = {
        aws = aws_instance,
        config = service_config,
        api = api,
      }

      AWS.configureEndpoint(service_instance)

      do -- render the endpoint url
        local url = service_instance.config.endpoint
        if url:find("{service}") then
          url = url:gsub("{service}", service_instance.config.endpointPrefix)
        end
        if url:find("{region}") then
          if not service_instance.config.region then
            return nil, "no region provided in config"
          end
          url = url:gsub("{region}", service_instance.config.region)
        end
        service_instance.config.endpoint = url
      end

      generate_service_methods(service_instance)
      return setmetatable(service_instance, {__index = lookup_helper})
    end
  end

  -- add credential classes constructors
  for _, class_name in ipairs {
      "Credentials", -- Lua specific
      "ChainableTemporaryCredentials",
      "CognitoIdentityCredentials",
      "CredentialProviderChain",
      "EC2MetadataCredentials",
      "EnvironmentCredentials",
      "FileSystemCredentials",
      "ProcessCredentials",
      "RemoteCredentials",
      "SAMLCredentials",
      "SharedIniFileCredentials",
      "TemporaryCredentials",
      "TokenFileWebIdentityCredentials",
      "WebIdentityCredentials",
    } do
    -- not all classes have been implemented, so we load what we can and
    -- once implemented the others will automatically be added
    local ok, cred_class = xpcall(require, debug.traceback, "resty.aws.credentials." .. class_name)
    if ok then
      aws_instance[class_name] = function(self, opts)
        if self ~= aws_instance then
          error("must instantiate AWS credentials by calling aws_instance:CredentialType(opts)", 2)
        end
        opts = opts or {}
        if opts.aws and opts.aws ~= aws_instance then
          error("'opts.aws' found, cannot override the aws instance", 2)
        end
        local old_aws = opts.aws
        opts.aws = self
        local creds, err = cred_class:new(opts)
        opts.aws = old_aws
        return creds, err
      end
    else
      -- not implemented yet
      aws_instance[class_name] = function(self, opts)
        error(("'%s' hasn't been implemented yet"):format(class_name), 2)
      end
    end
  end

  -- if there are no Credentials then instantiate the default chain to lookup
  if not aws_instance.config.credentials then
    --aws_instance.config.credentials = require("resty.aws.credentials.CredentialProviderChain"):new({aws = aws_instance})
-- for k, v in pairs(aws_instance) do
--   print(k, tostring(v))
-- end
-- print(tostring(aws_instance.CredentialProviderChain))
    aws_instance.config.credentials = aws_instance:CredentialProviderChain()
  end

  return aws_instance
end



return setmetatable(AWS, {
  __call = function(self, ...)
    return self:new(...)
  end,
})
