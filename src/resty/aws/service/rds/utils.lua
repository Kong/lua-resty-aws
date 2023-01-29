local pl_string = require "pl.stringx"
local httpc = require("resty.http").new()
local presign_awsv4_request = require("resty.aws.request.signatures.presign")

local RDS_IAM_AUTH_EXPIRE_TIME = 15 * 60

-- BuildAuthToken will return an authorization token used as the password for a DB
-- connection.
--
-- * endpoint - Endpoint consists of the port needed to connect to the DB. <host>:<port>
-- * region - Region is the location of where the DB is
-- * dbUser - User account within the database to sign in with
-- * creds - Credentials to be signed with
--
-- The following example shows how to use BuildAuthToken to create an authentication
-- token for connecting to a MySQL database in RDS.
--
--	authToken, err := BuildAuthToken(dbEndpoint, awsRegion, dbUser, awsCreds)
--
--	-- Create the MySQL DNS string for the DB connection
--	-- user:password@protocol(endpoint)/dbname?<params>
--	connectStr = fmt.Sprintf("%s:%s@tcp(%s)/%s?allowCleartextPasswords=true&tls=rds",
--	   dbUser, authToken, dbEndpoint, dbName,
--	)
--
--	-- Use db to perform SQL operations on database
--	db, err := sql.Open("mysql", connectStr)
--
-- See http:--docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html
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
      ["Host"] = host,
    },
  }

  local presigned_request, err = presign_awsv4_request(config, req_data, "rds-db", region, RDS_IAM_AUTH_EXPIRE_TIME)
  if err then
    return nil, err
  end

  return presigned_request.host .. presigned_request.path .. "?" .. presigned_request.query
end


return {
  build_auth_token = build_auth_token,
}
