--- AWS class.
-- @classmod AWS

local validate_input = require("resty.aws.request.validate")
local build_request = require("resty.aws.request.build")
local sign_request = require("resty.aws.request.sign")
local execute_request = require("resty.aws.request.execute")
local split = require("pl.utils").split
local tablex = require("pl.tablex")

local AWS_PUBLIC_DOMAIN_PATTERN = "^(.+)(%.amazonaws%.com)$"
local AWS_VPC_ENDPOINT_DOMAIN_PATTERN = "^(.+)(%.vpce%.amazonaws%.com)$"


-- case-insensitive lookup help.
-- always throws an error!
local lookup_helper = function(self, key)  -- signature to match __index meta-method
  if type(key) == "string" then
    local lckey = key:lower()
    for k in pairs(self) do
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



local aws_config = {
  region = require("resty.aws.raw-api.region_config_data"),
  api = {},
}

local load_api
do
  -- The API table is a map, where the index is the service-name. The value is a table.
  -- The table is another map, indexed by version (string). The value of that one
  -- is the raw AWS api.
  -- That raw-api is loaded upon demand by meta-table magic so we only load what we need.
  local list = require("resty.aws.raw-api.table_of_contents")
  for _, filename in ipairs(list) do
    -- example module_name: "resty.aws.raw-api.AWSMigrationHub-2017-05-31"
    -- example table_of_contents: "MigrationHub:AWSMigrationHub-2017-05-31"
    local service_id, service, version = assert(filename:match("^(.-)%:(.-)%-(%d%d%d%d%-%d%d%-%d%d)$"))
    -- example filename: "AWSMigrationHub-2017-05-31"
    local module_name = "resty.aws.raw-api." .. service .. "-" .. version
    -- example service_id: "MigrationHub"
    -- example version: "2017-05-31"
    local service_table = aws_config.api[service_id] or {}
    service_table[version] = module_name

    local sorted_versions = tablex.filter(tablex.keys(service_table),
                              function(v) return v ~= "latest" end)
    table.sort(sorted_versions)

    service_table.latest = service_table[sorted_versions[#sorted_versions]]

    aws_config.api[service_id] = service_table
  end

  local cache = setmetatable({}, { __mode = "v" })

  function load_api(service, version)
    local module_name = aws_config.api[service] and aws_config.api[service][version]
    if not module_name then
      return nil, "unknown service: " .. tostring(service) .. "/" .. tostring(version)
    end

    local api = cache[module_name]
    if api then
      return api
    end

    api = require(module_name)
    dereference_service(api)

    cache[module_name] = api
    return api
  end
end



-- JS copied



do
  -- https://github.com/aws/aws-sdk-js/blob/c0ec9d31057748cda57eac863273f5ef5a695782/lib/region_config.js#L4
  -- returns the region with the last element replaced by "*"
  -- "us-east-1" --> "us-*"
  -- "us-isob-west-1" --> "us-isob-*"
  local function generateRegionPrefix(region)
    if not region then
      return nil, "no region given"
    end

    local parts = split(region, "-", true)
    if #parts < 3 then
      return nil, "not a valid region, only 2 parts; "..region
    end

    local n_parts = #parts
    parts[n_parts] = nil
    parts[n_parts - 1] = "*"
    return table.concat(parts, "-")
  end


  -- returns array of patterns;
  -- 'sts' has endpointPrefix = "sts" in its metadata
  -- 'sts' configured without region;
  -- {
  --   "*/sts"
  --   "*/*"
  -- }
  -- 'sts' configured for region 'us-west-2';
  -- {
  --   "us-west-2/sts",
  --   "us-*/sts",
  --   "us-west-2/*",
  --   "us-*/*",
  --   "*/sts",
  --   "*/*",
  -- }
  local function derivedKeys(service)
    local region = service.config.region  -- configuration for an instance of a service
    local regionPrefix = generateRegionPrefix(region) -- this can return nil, or eg. "us-east-*"
    local endpointPrefix = service.api.metadata.endpointPrefix   -- this comes from the service metadata

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


  -- @param service service-instance being created; field `aws` is the aws instance,
  -- `config` is the service instance config, `api` the service api.
  function AWS.configureEndpoint(service)
    for _, key in ipairs(derivedKeys(service)) do

      local region_rule_config = aws_config.region.rules[key]  --> contains regions templates
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

        -- merge region_rule_config into service.config
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


local is_regional_sts_domain do
  -- from the list described in https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp_enable-regions.html
  -- TODO: not sure if gov cloud also has their own endpoints so leave it for now
  local stsRegionRegexes = {
    [[sts\.(us|eu|ap|sa|ca|me)\-\w+\-\d+\.amazonaws\.com$]],
    [[sts\.cn\-\w+\-\d+\.amazonaws\.com\.cn$]],
  }

  function is_regional_sts_domain(domain)
    for _, entry in ipairs(stsRegionRegexes) do
      if ngx.re.match(domain, entry, "jo") then
        return true
      end
    end

    return false
  end
end

-- written from scratch



-- a few AWS services make unsigned calls, this is not part of the metadata, but
-- of override files. See this one: https://github.com/aws/aws-sdk-js/blob/307e82673b48577fce4389e4ce03f95064e8fe0d/lib/services/sts.js
local unsigned = {
  STS = {
    AssumeRoleWithWebIdentity = true,
    AssumeRoleWithSAML = true,
  }
}


local function s3_patch(request, bucket)
  if not bucket then
    return
  end

  request.host = bucket .. "." .. request.host

  local path = request.path
  if bucket and path then
    path = path:sub(#bucket + 2)
    if path == "/" then
      path = ""
    end

    request.path = path
  end
end

-- Generate a function for each operation in the service api "operations" table
local function generate_service_methods(service)
  for _, operation in pairs(service.api.operations) do

    -- decapitalize first character of method names to mimic JS sdk
    local method_name = operation.name:sub(1,1):lower() .. operation.name:sub(2,-1)

    local operation_prefix = ("%s:%s()"):format(
                              service.api.metadata.serviceId:gsub(" ",""),
                              method_name)

    service[method_name] = function(self, params)
      params = params or {}

      --print(require("pl.pretty").write(self.config))

      -- validate parameters if we have any; eg. S3 "listBuckets" has none
      if operation.input then
        local ok, err = validate_input(params, operation.input, "params")
        if not ok then
          return nil, operation_prefix .. " validation error: " .. tostring(err)
        end
      end

      -- implement stsRegionalEndpoints config setting,
      if service.api.metadata.serviceId == "STS"
        and service.config.stsRegionalEndpoints == "regional"
        and service.isGlobalEndpoint then
        -- we use regional endpoints, see
        -- https://github.com/aws/aws-sdk-js/blob/307e82673b48577fce4389e4ce03f95064e8fe0d/lib/services/sts.js#L78-L82
        assert(service.config.region, "region is required when using STS regional endpoints")

        if not service.config._regionalEndpointInjected then
          service.config._regionalEndpointInjected = true
          -- stsRegionalEndpoints is set to 'regional', so inject region into the
          -- signingRegion to override global region_config_data
          service.config.signingRegion = service.config.region

          -- If the endpoint is a VPC endpoint DNS hostname, or a regional STS domain, then we don't need to inject the region
          -- VPC endpoint DNS hostnames always contain region, see
          -- https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html#interface-endpoint-dns-hostnames
          if not service.config.endpoint:match(AWS_VPC_ENDPOINT_DOMAIN_PATTERN) and not is_regional_sts_domain(service.config.endpoint) then
            local pre, post = service.config.endpoint:match(AWS_PUBLIC_DOMAIN_PATTERN)
            service.config.endpoint = pre .. "." .. service.config.region .. post
          end
        end
      end

      -- generate request data and format it according to the protocol
      local request = build_request(operation, self.config, params)

      local old_sig
      if (unsigned[service.api.metadata.serviceId] or {})[operation.name] then
        -- were not signing this one, patch signature version
        old_sig = self.config.signatureVersion
        self.config.signatureVersion = "none"
      end

      if not self.config.s3_bucket_in_path then
        s3_patch(request, params.Bucket)
      end

      -- sign the request according to the signature version required
      local signed_request, err = sign_request(self.config, request)
      if old_sig then
        -- revert the patched signatureVersion
        self.config.signatureVersion = old_sig
      end
      if not signed_request then
        return nil, "failed to sign request: " .. tostring(err)
      end

      --print(require("pl.pretty").write(signed_request))

      if self.config.dry_run then
        return signed_request
      end
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
-- -- in the "init" phase initialize the configuration
-- local _ = require("resty.aws.config").global
--
--
-- @usage
-- -- In your code
-- local AWS = require("resty.aws")
-- local AWS_global_config = require("resty.aws.config").global
--
-- local config = { region = AWS_global_config.region }
--
-- local aws = AWS(config)
--
-- -- Override default "CredentialProviderChain" credentials.
-- -- This is optional, the defaults should work with AWS-IAM.
-- local my_creds = aws:Credentials {
--   accessKeyId = "access",
--   secretAccessKey = "secret",
--   sessionToken = "token",
-- }
-- aws.config.credentials = my_creds
--
-- -- instantiate a service (optionally overriding the aws-instance config)
-- local sm = aws:SecretsManager {
--   region = "us-east-2",
-- }
--
-- -- Invoke a method.
-- -- Note this only takes the parameter table, and NOT a callback as the
-- -- JS sdk requires. Instead this call will directly return the results.
-- local results, err = sm:getSecretValue {
--   SecretId = "arn:aws:secretsmanager:us-east-2:238406704566:secret:test-HN1F1k",
-- }
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
  for service_id in pairs(aws_config.api) do
    -- Create service specific functions, by `serviceId`
    aws_instance[service_id] = function(aws, config)
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
      local api = load_api(service_id, service_config.apiVersion)
      if not api then
        return nil, ("service '%s' does not have an apiVersion '%s'"):format(service_id, tostring(service_config.apiVersion))
      end
      if service_config.apiVersion == "latest" then
        service_config.apiVersion = api.metadata.apiVersion
      end

      -- apply metadata
      for k,v in pairs(api.metadata) do
        service_config[k] = service_config[k] or v
      end

      local signer
      if service_id == "RDS" then
        signer = require("resty.aws.service.rds.signer")
      elseif service_id == "ElastiCache" then
        signer = require("resty.aws.service.elasticache.signer")
      end

      local service_instance = {
        aws = aws_instance,
        config = service_config,
        api = api,
        -- Add service specific methods:
        Signer = signer
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
      if cred_class:find("module 'resty.aws.credentials." .. class_name .. "' not found", 1, true) then
        -- not implemented yet
        aws_instance[class_name] = function(self, opts)
          error(("'%s' hasn't been implemented yet"):format(class_name), 2)
        end
      else
        -- some other error, bail out
        error(cred_class)
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
