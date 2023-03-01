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

local DB_ENDPOINT = "test_database.test_cluster.us-east-1.rds.amazonaws.com"
local DB_PORT = "443"
local DB_REGION = "us-east-1"
local DB_USER = "test_user"

describe("RDS utils", function()
  local rds, signer
  setup(function()
    ngx.origin_time = ngx.time
    ngx.time = function ()
      return 1667543171
    end
  end)

  teardown(function ()
    ngx.time = ngx.origin_time
    ngx.origin_time = nil
  end)

  before_each(function()
    rds = aws:RDS()
    signer = rds:Signer {
      hostname = DB_ENDPOINT,
      port = DB_PORT,
      username = DB_USER,
      region = DB_REGION, -- override aws config
    }
  end)

  after_each(function()
    rds = nil
    signer = nil
  end)

  it("should generate expected IAM auth token with mock key", function()
    local auth_token, err = signer:getAuthToken()
    local expected_auth_token = "test_database.test_cluster.us-east-1.rds.amazonaws.com:443/?X-Amz-Signature=ff72d46f1937c1f5917f69d694929ca814b781619b8d730451c7ffef050059b0&Action=connect&DBUser=test_user&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test_id%2F20221104%2Fus-east-1%2Frds-db%2Faws4_request&X-Amz-Date=20221104T062611Z&X-Amz-Expires=900&X-Amz-SignedHeaders=host"
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
    local expected_auth_token = "test_database.test_cluster.us-east-1.rds.amazonaws.com:443/?X-Amz-Signature=7fcb20a161bb493b405686590604bfb864f8ac68dea84b903cd551e93f850ac5&Action=connect&DBUser=test_user&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test_id2%2F20221104%2Fus-east-1%2Frds-db%2Faws4_request&X-Amz-Date=20221104T062611Z&X-Amz-Expires=900&X-Amz-Security-Token=test_token2&X-Amz-SignedHeaders=host"
    assert.is_nil(err)
    assert.same(auth_token, expected_auth_token)
  end)
end)
