setmetatable(_G, nil)

-- to get a definitive result
-- luacheck:ignore
ngx.time = function()
  return 1667543171
end

-- -- hock request sending
-- package.loaded["resty.aws.request.execute"] = function(...)
--   return ...
-- end

local AWS = require("resty.aws")
local AWS_global_config = require("resty.aws.config").global

local presign = require("resty.aws.request.signatures.presign")

local config = AWS_global_config
local aws = AWS(config)


aws.config.credentials = aws:Credentials {
  accessKeyId = "test_id",
  secretAccessKey = "test_key",
}

aws.config.region = "test_region"

describe("Presign request", function()
  local presigned_request_data

  before_each(function()
    local request_data = {
      method = "GET",
      scheme = "https",
      tls = true,
      host = "test_host",
      port = 443,
      path = "/",
      query = "Action=TestAction",
      headers = {
        ["Host"] = "test_host:443",
      },
    }

    presigned_request_data = presign(aws.config, request_data, "test_service", "test_region", 900)
  end)

  after_each(function()
    presigned_request_data = nil
  end)

  it("should have correct signed request host header", function()
    assert.same(presigned_request_data.headers["Host"], "test_host:443")
    assert.same(presigned_request_data.host, "test_host")
    assert.same(presigned_request_data.port, 443)
  end)

  it("should have correct signed request path", function ()
    assert.same(presigned_request_data.path, "/")
  end)

  it("should have correct signed query parameters", function ()
    local query_params = {}
    for k, v in presigned_request_data.query:gmatch("([^&=]+)=?([^&]*)") do
      query_params[ngx.unescape_uri(k)] = ngx.unescape_uri(v)
    end
    assert.same(query_params["X-Amz-Algorithm"], "AWS4-HMAC-SHA256")
    assert.same(query_params["Action"], "TestAction")
    assert.same(query_params["X-Amz-Date"], "20221104T062611Z")
    assert.same(query_params["X-Amz-Expires"], "900")
    assert.same(query_params["X-Amz-SignedHeaders"], "host")
    assert.same(query_params["X-Amz-Credential"], "test_id/20221104/test_region/test_service/aws4_request")
  end)
end)
