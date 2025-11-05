setmetatable(_G, nil)

-- -- hock request sending
-- package.loaded["resty.aws.request.execute"] = function(...)
--   return ...
-- end

local AWS = require("resty.aws")
local AWS_global_config = require("resty.aws.config").global

local config = AWS_global_config
local aws = AWS(config)

aws.config.credentials = aws:Credentials {
  accessKeyId = "test_id",
  secretAccessKey = "test_key",
}

aws.config.region = "test_region"

local REGION = "ap-northeast-1"
local USER = "test"
local CACHE_NAME = "test-cache"

describe("Elasticache utils", function()
  local cache, signer
  local origin_time
  setup(function()
    origin_time = ngx.time
    ngx.time = function () --luacheck: ignore
      return 1667543171
    end
  end)

  teardown(function ()
    ngx.time = origin_time --luacheck: ignore
  end)

  before_each(function()
    cache = aws:ElastiCache()
    signer = cache:Signer {
      cachename = CACHE_NAME,
      username = USER,
      region = REGION, -- override aws config
    }
  end)

  after_each(function()
    cache = nil
    signer = nil
  end)

  it("should generate expected IAM auth token with mock key", function()
    local auth_token, err = signer:getAuthToken()
    local expected_auth_token = "test-cache/?X-Amz-Signature=606f98b24623c1e25deb70c2e98220cee859c39232ee7585aec51c25cb220882&Action=connect&User=test&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test_id%2F20221104%2Fap-northeast-1%2Felasticache%2Faws4_request&X-Amz-Date=20221104T062611Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host"
    assert.is_nil(err)
    assert.same(auth_token, expected_auth_token)
  end)

  it("should generate expected IAM auth token with mock temporary credential", function()
    signer.config.credentials = aws:Credentials {
      accessKeyId = "test_id2",
      secretAccessKey = "test_key2",
      sessionToken = "test_token2",
    }
    local auth_token, err = signer:getAuthToken()
    local expected_auth_token = "test-cache/?X-Amz-Signature=88de038c7918f1b733e23d65eb3bc0ee989214c26ed8124cb730ce6e7d7a3e5c&Action=connect&User=test&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test_id2%2F20221104%2Fap-northeast-1%2Felasticache%2Faws4_request&X-Amz-Date=20221104T062611Z&X-Amz-Expires=900&X-Amz-Security-Token=test_token2&X-Amz-SignedHeaders=host"
    assert.is_nil(err)
    assert.same(auth_token, expected_auth_token)
  end)
end)
