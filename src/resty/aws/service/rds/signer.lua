--- Signer class for RDS tokens for RDS DB access.
--
-- See [IAM database authentication for MariaDB, MySQL, and PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html)
-- for more information on using IAM database authentication with RDS.
--
-- RDS services created will get a `Signer` method to create an instance. The `Signer` will
-- inherit its configuration from the `AWS` instance (not from the RDS instance!).

local httpc = require("resty.http").new()
local presign_awsv4_request = require("resty.aws.request.signatures.presign")

local RDS_IAM_AUTH_EXPIRE_TIME = 15 * 60

--- Return an authorization token used as the password for a RDS DB connection.
-- The example shows how to use `getAuthToken` to create an authentication
-- token for connecting to a PostgreSQL database in RDS.
-- @name Signer:getAuthToken
-- @tparam table opts configuration to use, to override the options inherited from the underlying `AWS` instance;
-- @tparam string opts.region The AWS region
-- @tparam string opts.hostname the DB hostname to connect to, eg. `"DB_NAME.us-east-1.rds.amazonaws.com"`
-- @tparam number opts.port the port for the DB connection
-- @tparam string opts.username username of the account in the database to sign in with
-- @tparam Credentials opts.credentials aws credentials
-- @return token, err - Returns the token to use as the password for the DB connection, or nil and error if an error occurs
-- @usage
-- local pgmoon = require "pgmoon"
-- local AWS = require("resty.aws")
-- local AWS_global_config = require("resty.aws.config").global
-- local aws = AWS { region = AWS_global_config.region }
-- local rds = aws:RDS()
--
--
-- local db_hostname = "DB_NAME.us-east-1.rds.amazonaws.com"
-- local db_port = 5432
-- local db_name = "DB_NAME"
--
-- local signer = rds:Signer {  -- create a signer instance
--   hostname = db_hostname,
--   username = "db_user",
--   port = db_port,
--   region = nil,              -- will be inherited from `aws`
--   credentials = nil,         -- will be inherited from `aws`
-- }
--
-- -- use the 'signer' to generate the token, whilst overriding some options
-- local auth_token, err = signer:getAuthToken {
--   username = "another_user"  -- this overrides the earlier provided config above
-- }
--
-- if err then
--   ngx.log(ngx.ERR, "Failed to build auth token: ", err)
--   return
-- end
--
-- local pg = pgmoon.new({
--   host = db_hostname,
--   port = db_port,
--   database = db_name,
--   user = "another_user",
--   password = auth_token,
--   ssl = true,
-- })
--
-- local flag, err = pg:connect()
-- if err then
--  ngx.log(ngx.ERR, "Failed to connect to database: ", err)
--  return
-- end
--
-- -- Test query
-- assert(pg:query("select * from users where status = 'active' limit 20"))
local function getAuthToken(self, opts) --endpoint, region, db_user)
  opts = setmetatable(opts or {}, { __index = self.config }) -- lookup missing params in inherited config

  local region = assert(opts.region, "parameter 'region' not set")
  local hostname = assert(opts.hostname, "parameter 'hostname' not set")
  local port = assert(opts.port, "parameter 'port' not set")
  local username = assert(opts.username, "parameter 'username' not set")

  local endpoint = hostname .. ":" .. port
  if endpoint:sub(1,7) ~= "http://" and endpoint:sub(1,8) ~= "https://" then
    endpoint = "https://" .. endpoint
  end

  local query_args = "Action=connect&DBUser=" .. username

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
      ["Host"] = host .. ":" .. port,
    },
  }

  local presigned_request, err = presign_awsv4_request(self, req_data, opts.signingName, region, RDS_IAM_AUTH_EXPIRE_TIME)
  if err then
    return nil, err
  end

  return presigned_request.host .. ":" .. presigned_request.port .. presigned_request.path .. "?" .. presigned_request.query
end


-- signature: intended to be a method on the RDS service object, rds_instance == self in that case
return function(rds_instance, config)
  local token_instance = {
    config = {},
    getAuthToken = getAuthToken,  -- injected method for token generation
  }

  -- first copy the inherited config elements NOTE: inherits from AWS, not the rds_instance!!!
  for k,v in pairs(rds_instance.aws.config) do
    token_instance.config[k] = v
  end

  -- service specifics
  -- see https://github.com/aws/aws-sdk-js/blob/9295e45fdcda93b62f8c1819e924cdb4fb378199/lib/rds/signer.js#L11-L15
  token_instance.config.signatureVersion = "v4"
  token_instance.config.signingName = "rds-db"

  -- then add/overwrite with provided config
  for k,v in pairs(config or {}) do
    token_instance.config[k] = v
  end

  return token_instance
end
