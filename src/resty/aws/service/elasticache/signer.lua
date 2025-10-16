--- Signer class for Elasticache tokens for Valkey and Redis OSS access.

-- Elasticache services created will get a `Signer` method to create an instance.
-- The `Signer` will inherit its configuration from the `AWS` instance.

local httpc = require("resty.luasocket.http")
local presign_awsv4_request = require("resty.aws.request.signatures.presign")

local ELASTICACHE_IAM_AUTH_EXPIRE_TIME = 15 * 60


--- The example shows how to use `getAuthToken` to create an authentication
-- token for connecting to a PostgreSQL database in RDS.
-- @name Signer:getAuthToken
-- @tparam table opts configuration to use, to override the options inherited from the underlying `AWS` instance;
-- @tparam string opts.region The AWS region
-- @tparam string opts.cachename the Elasticache instance name to connect to, eg. `"test-cache"`
-- @tparam string opts.username name of the IAM-enabled user configured in the Elasticache User management page.
-- @tparam boolean opts.is_serverless the deployment mode of the cache cluster.
-- @tparam Credentials opts.credentials aws credentials
-- @return token, err - Returns the token to use as the password for the Redis connection, or nil and error if an error occurs
-- @usage
-- local AWS = require("resty.aws")
-- local AWS_global_config = require("resty.aws.config").global
-- local aws = AWS { region = AWS_global_config.region }
-- local cache = aws:ElastiCache()
-- local redis = require "resty.redis"
--
-- local hostname = "HOSTNAME, e.g. test-cache-ppl9c2.serverless.apne1.cache.amazonaws.com"
-- local cachename = "CACHE CLUSTER NAME, e.g. test-cache"
-- local port = 6379
-- local name = "Username e.g. test-user"
--
-- local signer = cache:Signer {  -- create a signer instance
--   cachename = cachename,
--   username = name,
--   is_serverless = true,
--   region = nil,              -- will be inherited from `aws`
--   credentials = nil,         -- will be inherited from `aws`
-- }
--
-- -- use the 'signer' to generate the token, whilst overriding some options
-- local auth_token, err = signer:getAuthToken()
--
-- if err then
--   ngx.log(ngx.ERR, "Failed to build auth token: ", err)
--   return
-- end
-- print(auth_token)
--
-- local red = redis:new()
-- --red:set_timeouts(1000, 1000, 1000)
--
-- local ok, err = red:connect(hostname, port, { ssl = true })
-- if not ok then
--   print("failed to connect: ", err)
--   return
-- end
--
-- local res, err = red:auth(name, auth_token)
-- if not res then
--   print("failed to authenticate: ", err)
--   return
-- end
--
-- print("OK")


local function getAuthToken(self, opts) --cachename, region, username, is_serverless)
  opts = setmetatable(opts or {}, { __index = self.config }) -- lookup missing params in inherited config

  local region = assert(opts.region, "parameter 'region' not set")
  local cachename = assert(opts.cachename, "parameter 'cachename' not set")
  local username = assert(opts.username, "parameter 'username' not set")

  local endpoint = cachename
  if endpoint:sub(1,7) ~= "http://" then
    endpoint = "http://" .. endpoint
  end

  local query_args = "Action=connect&User=" .. username
  if opts.is_serverless then
    query_args = query_args .. "&ResourceType=ServerlessCache"
  end

  local canonical_request_url = endpoint .. "/?" .. query_args
  local scheme, host, port, path, query = unpack(httpc:parse_uri(canonical_request_url, false))
  local req_data = {
    method = "GET",
    scheme = scheme,
    tls = scheme == "https",
    host = host,
    port = port,
    path = path,
    query = query,
    headers = {
      ["Host"] = host,
    },
  }

  local presigned_request, err = presign_awsv4_request(self.config, req_data, opts.signingName, region, ELASTICACHE_IAM_AUTH_EXPIRE_TIME)
  if err then
    return nil, err
  end

  return presigned_request.host .. presigned_request.path .. "?" .. presigned_request.query
end


-- signature: intended to be a method on the Elasticache service object, cache_instance == self in that case
return function(cache_instance, config)
  local token_instance = {
    config = {},
    getAuthToken = getAuthToken,  -- injected method for token generation
  }

  -- first copy the inherited config elements NOTE: inherits from AWS, not the cache_instance!!!
  for k,v in pairs(cache_instance.aws.config) do
    token_instance.config[k] = v
  end

  -- service specifics
  token_instance.config.signatureVersion = "v4"
  token_instance.config.signingName = "elasticache"

  -- then add/overwrite with provided config
  for k,v in pairs(config or {}) do
    token_instance.config[k] = v
  end

  return token_instance
end
