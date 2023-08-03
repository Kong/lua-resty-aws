-- Performs AWSv4 Signing
-- http://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html

local pl_string = require "pl.stringx"

local utils = require "resty.aws.request.signatures.utils"
local hmac = utils.hmac
local hash = utils.hash
local hex_encode = utils.hex_encode
local canonicalise_path = utils.canonicalise_path
local canonicalise_query_string = utils.canonicalise_query_string
local derive_signing_key = utils.derive_signing_key


local ALGORITHM = "AWS4-HMAC-SHA256"


-- config to contain:
-- config.endpoint: hostname to connect to
-- config.credentials: the Credentials class to use
--
-- tbl to contain:
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
-- tbl.timeout: number socket timeout (in ms), defaults to 60000
-- tbl.keepalive_idle_timeout: number keepalive idle timeout (in ms), no keepalive if nil
-- tbl.tls: defaults to true (if nil)
-- tbl.ssl_verify: defaults to true (if nil)
-- tbl.port: defaults to 443 or 80 depending on 'tls'
-- tbl.timestamp: number defaults to 'ngx.time()''
-- tbl.global_endpoint: if true, then use "us-east-1" as signing region and different
--     hostname template: see https://github.com/aws/aws-sdk-js/blob/ae07e498e77000e55da70b20996dc8fd2f8b3051/lib/region_config_data.json
local function prepare_awsv4_request(config, request_data)
  local region = config.signingRegion or config.region
  local service = config.endpointPrefix or config.targetPrefix -- TODO: targetPrefix as fallback, correct???
  local request_method = request_data.method -- TODO: should this get a fallback/default??

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

  local timeout = config.timeout
  local keepalive_idle_timeout = config.keepalive_idle_timeout
  local tls = config.tls
  local ssl_verify = config.ssl_verify

  local host = request_data.host
  local port = request_data.port
  local timestamp = ngx.time()
  local req_date = os.date("!%Y%m%dT%H%M%SZ", timestamp)
  local date = os.date("!%Y%m%d", timestamp)

  local headers = {
    ["X-Amz-Date"] = req_date,
    ["Host"] = host,
    ["X-Amz-Security-Token"] = session_token,
  }

  local S3 = config.signatureVersion == "s3"

  local hashed_payload = hex_encode(hash(req_payload or ""))

  -- Special handling of S3
  -- https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html#:~:text=Unsigned%20payload%20option
  if S3 then
    headers["X-Amz-Content-Sha256"] = hashed_payload
  end

  local add_auth_header = true
  for k, v in pairs(req_headers) do
    k = k:gsub("%f[^%z-]%w", string.upper) -- convert to standard header title case
    if k == "Authorization" then
      add_auth_header = false
    elseif v == false then -- don't allow a default value for this header
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
    canonical_headers = table.concat(canonical_headers, nil, 1, i)
  end

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
  local credential_scope = date .. "/" .. region .. "/" .. service .. "/aws4_request"
  local string_to_sign =
    ALGORITHM .. '\n' ..
    req_date .. '\n' ..
    credential_scope .. '\n' ..
    hashed_canonical_request

  -- Task 3: Calculate the AWS Signature Version 4
  -- http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
  local signing_key = derive_signing_key(secret_key, date, region, service)
  local signature = hex_encode(hmac(signing_key, string_to_sign))

  -- Task 4: Add the Signing Information to the Request
  -- http://docs.aws.amazon.com/general/latest/gr/sigv4-add-signature-to-request.html
  local authorization = ALGORITHM
    .. " Credential=" .. access_key .. "/" .. credential_scope
    .. ", SignedHeaders=" .. signed_headers
    .. ", Signature=" .. signature
  if add_auth_header then
    headers.Authorization = authorization
  end

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
    timeout = timeout,  -- 60000
    keepalive_idle_timeout = keepalive_idle_timeout, -- 60000
    tls = tls,      -- true
    ssl_verify = ssl_verify, -- true
    path = path or canonicalURI,             -- "/some/path"
    method = request_method,  -- "GET"
    query = query or canonical_querystring,  -- "query1=val1"
    headers = headers,  -- table
    body = req_payload, -- string
    --target = target,  -- "/some/path?query1=val1"
  }
end

return prepare_awsv4_request
