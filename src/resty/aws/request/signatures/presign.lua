-- Performs AWS v4 request presigning.

local pl_string = require "pl.stringx"

local utils = require "resty.aws.request.signatures.utils"
local hmac = utils.hmac
local hash = utils.hash
local hex_encode = utils.hex_encode
local canonicalise_path = utils.canonicalise_path
local canonicalise_query_string = utils.canonicalise_query_string
local derive_signing_key = utils.derive_signing_key
local add_args_to_query_string = utils.add_args_to_query_string


local ALGORITHM = "AWS4-HMAC-SHA256"


local PRESIGN_SIGNING_FLAGS = {
  ["X-Amz-Algorithm"] = true,
  ["X-Amz-Signature"] = true,
  ["X-Amz-Security-Token"] = true,
  ["X-Amz-Date"] = true,
  ["X-Amz-Expires"] = true,
  ["X-Amz-Credential"] = true,
  ["X-Amz-SignedHeaders"] = true
}


-- remove old signing flags in the original request
local function handle_presign_removal(query)
  local q = {}
  if type(query) == "string" then
    for key, val in query:gmatch("([^&=]+)=?([^&]*)") do
      if not PRESIGN_SIGNING_FLAGS[key] then
        q[#q+1] = key .. "=" .. val
      end
    end

  elseif type(query) == "table" then
    for key, val in pairs(query) do
      if not PRESIGN_SIGNING_FLAGS[key] then
        q[#q+1] = key .. "=" .. val
      end
    end
  end

  return table.concat(q, "&")
end

-- Presigning AWS v4 Request
-- @param config - AWS config instance
-- @param request_data - request data table
-- @param service - AWS service name
-- @param region - AWS region name
-- @param expires - expires time in seconds, should be less than 604800 (7 days)
-- @return presigned request data table
--
-- config to contain:
-- config.endpoint: hostname to connect to
-- config.credentials: the Credentials class to use
--
-- request_data tbl to contain:
-- tbl.domain: optional, defaults to "amazon.com"
-- tbl.region: amazon region identifier, eg. "us-east-1"
-- tbl.service: amazon service targetted, eg. "lambda"
-- tbl.method: GET/POST/etc
-- tbl.path: path to invoke, defaults to 'canonicalURI' if given, or otherwise "/"
-- tbl.canonicalURI: if given will be used and override 'path'
-- tbl.query: string with the query parameters, defaults to 'canonical_querystring'
-- tbl.canonical_querystring: if given will be used and override 'query'
-- tbl.headers: table of headers for the request
--    note: for headers "Host" and "Authorization"; they will be used if
--          provided, and not be overridden by the generated ones
-- tbl.body: string, defaults to ""
-- tbl.tls: defaults to true (if nil)
-- tbl.port: defaults to 443 or 80 depending on 'tls'
-- tbl.timestamp: number defaults to 'ngx.time()''
-- tbl.global_endpoint: if true, then use "us-east-1" as signing region and different
--     hostname template: see https://github.com/aws/aws-sdk-js/blob/ae07e498e77000e55da70b20996dc8fd2f8b3051/lib/region_config_data.json
local function presign_awsv4_request(config, request_data, service, region, expire)
  if type(expire) ~= "number" then
    return nil, "bad expire type, expected number, got: ".. type(expire)
  end

  if expire < 1 or expire > 604800 then
    return nil, "bad expire value, expected 1 <= expire <= 604800, got: ".. expire
  end

  -- force expire time to integer
  local expire_time = tonumber(expire, 10)

  local region =  region or config.signingRegion or config.region
  local service = service or config.endpointPrefix or config.targetPrefix -- TODO: Presign may not need fallback on service name
  local request_method = request_data.method

  local canonicalURI = request_data.canonicalURI
  local path = request_data.path
  if path and not canonicalURI then
    canonicalURI = canonicalise_path(path)
  elseif canonicalURI == nil or canonicalURI == "" then
    canonicalURI = "/"
  end

  local canonical_querystring = request_data.canonical_querystring
  local query = request_data.query
  if query and not canonical_querystring then
    canonical_querystring = canonicalise_query_string(query)
    canonical_querystring = handle_presign_removal(canonical_querystring)
  end

  local req_headers = request_data.headers
  local req_payload = request_data.body

  -- get credentials
  local access_key, secret_key, session_token do
    if not config.credentials then
      return nil, "cannot sign request without 'config.credentials'"
    end
    local success
    success, access_key, secret_key, session_token = config.credentials:get()
    if not success then
      return nil, "failed to get credentials: " .. tostring(access_key)
    end
  end

  local tls = config.tls

  local host = request_data.host
  local port = request_data.port
  local timestamp = ngx.time()
  local req_date = os.date("!%Y%m%dT%H%M%SZ", timestamp)
  local date = os.date("!%Y%m%d", timestamp)

  local credential_scope = date .. "/" .. region .. "/" .. service .. "/aws4_request"

  local amz_query_args = {
    ["X-Amz-Algorithm"] = ALGORITHM,
    ["X-Amz-Security-Token"] = session_token,
    ["X-Amz-Date"] = req_date,
    ["X-Amz-Expires"] = expire_time,
    ["X-Amz-Credential"] = access_key .. "/" .. credential_scope
  }

  local headers = {}

  -- Request body SHA256 digest
  local hashed_payload

  if req_headers["X-Amz-Content-Sha256"] then
    hashed_payload = req_headers["X-Amz-Content-Sha256"]
    headers["X-Amz-Content-Sha256"] = hashed_payload
    req_headers["X-Amz-Content-Sha256"] = nil
  end

  if hashed_payload == "" or hashed_payload == nil then
    -- TODO: unsigned_payload?
    local include_sha256_in_header = config.unsigned_payload
                                      or service == "s3"
                                      or service == "s3-object-lambda"
                                      or service == "glacier"
    local is_s3_presign = service == "s3" or service == "s3-object-lambda"
    if config.unsigned_payload or is_s3_presign then
      hashed_payload = "UNSIGNED-PAYLOAD"
      include_sha256_in_header = not is_s3_presign

    else
      hashed_payload = hex_encode(hash(req_payload or ""))
    end

    if include_sha256_in_header then
      headers["X-Amz-Content-Sha256"] = hashed_payload
    end
  end

  for k, v in pairs(req_headers) do
    k = k:gsub("%f[^%z-]%w", string.upper) -- convert to standard header title case
    if v == false then -- don't allow a default value for this header
      v = nil
    end
    headers[k] = v
  end

  -- Task 1: Create a Canonical Request For Signature Version 4
  -- http://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
  local canonical_headers, signed_headers do
    -- We structure this code in a way so that we only have to sort once.
    canonical_headers, signed_headers = {}, {}
    local i = 0
    for name, value in pairs(headers) do
      if value then -- ignore headers with 'false', they are used to override defaults
        i = i + 1
        local name_lower = name:lower()
        signed_headers[i] = name_lower
        if canonical_headers[name_lower] ~= nil then
          return nil, "header collision"
        end
        canonical_headers[name_lower] = pl_string.strip(tostring(value))
      end
    end
    table.sort(signed_headers)
    for j=1, i do
      local name = signed_headers[j]
      local value = canonical_headers[name]
      canonical_headers[j] = name .. ":" .. value .. "\n"
    end
    signed_headers = table.concat(signed_headers, ";", 1, i)
    amz_query_args["X-Amz-SignedHeaders"] = signed_headers
    canonical_headers = table.concat(canonical_headers, nil, 1, i)
  end

  -- canonical_querystring = add_args_to_query_string(headers, canonical_querystring)
  canonical_querystring = add_args_to_query_string(amz_query_args, canonical_querystring, true)

  local canonical_request =
    request_method .. '\n' ..
    canonicalURI .. '\n' ..
    (canonical_querystring or "") .. '\n' ..
    canonical_headers .. '\n' ..
    signed_headers .. '\n' ..
    hashed_payload

  local hashed_canonical_request = hex_encode(hash(canonical_request))

  -- Task 2: Create a String to Sign for Signature Version 4
  -- http://docs.aws.amazon.com/general/latest/gr/sigv4-create-string-to-sign.html
  local string_to_sign =
    ALGORITHM .. '\n' ..
    req_date .. '\n' ..
    credential_scope .. '\n' ..
    hashed_canonical_request

  -- Task 3: Calculate the AWS Signature Version 4
  -- http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
  local signing_key = derive_signing_key(secret_key, date, region, service)
  local signature = hex_encode(hmac(signing_key, string_to_sign))
  canonical_querystring = add_args_to_query_string("X-Amz-Signature=" .. signature, canonical_querystring)

  -- local target = path or canonicalURI
  -- if query or canonical_querystring then
  --   target = target .. "?" .. (query or canonical_querystring)
  -- end
  -- local scheme = tls and "https" or "http"
  -- local url = scheme .. "://" .. host_header .. target

  return {
    --url = url,      -- "https://lambda.us-east-1.amazon.com:443/some/path?query1=val1"
    host = host,    -- "lambda.us-east-1.amazon.com"
    port = port,    -- 443
    tls = tls,      -- true
    path = path or canonicalURI,             -- "/some/path"
    method = request_method,  -- "GET"
    query = canonical_querystring,  -- "query1=val1"
    headers = headers,  -- table
    -- body = req_payload, -- Presign does not need to include body in request
  }
end

return presign_awsv4_request
