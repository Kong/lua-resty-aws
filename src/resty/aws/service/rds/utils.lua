local pl_string = require "pl.stringx"
local httpc = require("resty.http").new()
local presign_awsv4_request = require("resty.aws.request.signatures.presign")

local RDS_IAM_AUTH_EXPIRE_TIME = 15 * 60

-- Return an authorization token used as the password for a RDS DB connection.
--
-- @param config - AWS config object
-- @param endpoint - Endpoint consists of the port needed to connect to the DB. <host>:<port>
-- @param region - Region is the location of where the DB is
-- @param dbUser - User account within the database to sign in with
--
-- The following example shows how to use build_auth_token to create an authentication
-- token for connecting to a PostgreSQL database in RDS.
--
-- local pgmoon = require "pgmoon"
-- local AWS = require("resty.aws")
-- local AWS_global_config = require("resty.aws.config").global
-- local config = { region = AWS_global_config.region }
-- local aws = AWS(config)
--
-- local db_domain = "DB_NAME.us-east-1.rds.amazonaws.com"
-- local db_port = 5432
-- local db_endpoint = db_domain .. ":" .. db_port
-- local region = "us-east-1"
-- local db_user = "dbuser"
-- local db_name = "DB_NAME"
-- local auth_token, err = build_auth_token(aws.config, db_endpoint, region, user)
--
-- if err then
--   ngx.log(ngx.ERR, "Failed to build auth token: ", err)
--   return
-- end
--
-- local pg = pgmoon.new({
--   host = db_domain,
--   port = db_port,
--   database = db_name,
--   user = db_user,
--   password = auth_token,
--   ssl = true,
-- })
--
-- local flag, err = pg:connect()
-- if err then
--  ngx.log(ngx.ERR, "Failed to connect to database: ", err)
--  return
-- end
-- -- Test query
-- assert(pg:query("select * from users where status = 'active' limit 20"))
--
-- See https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html
-- for more information on using IAM database authentication with RDS.
local function build_auth_token(config, endpoint, region, db_user)
  if not(pl_string.startswith(endpoint, "http://") or pl_string.startswith(endpoint, "https://")) then
    endpoint = "https://" .. endpoint
  end

  local query_args = "Action=connect&DBUser=" .. db_user

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

  local presigned_request, err = presign_awsv4_request(config, req_data, "rds-db", region, RDS_IAM_AUTH_EXPIRE_TIME)
  if err then
    return nil, err
  end

  return presigned_request.host .. ":" .. presigned_request.port .. presigned_request.path .. "?" .. presigned_request.query
end


return {
  build_auth_token = build_auth_token,
}
