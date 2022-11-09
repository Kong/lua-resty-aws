setmetatable(_G, nil)

-- to get a definitive result
-- luacheck:ignore
ngx.time = function()
  return 1667543171
end

-- hook request sending
package.loaded["resty.aws.request.execute"] = function(...)
  return ...
end

local AWS = require("resty.aws")
local AWS_global_config = require("resty.aws.config").global


local config = AWS_global_config
config.tls = true
local aws = AWS(config)


aws.config.credentials = aws:Credentials {
  accessKeyId = "test_id",
  secretAccessKey = "test_key",
}

aws.config.region = "test_region"

describe("Secret Manager service", function()
  local sm
  before_each(function()
    sm = assert(aws:SecretsManager {})
  end)

  after_each(function()
  end)

  local testcases = {
    -- API = { param, expected_result_aws, },
    getSecretValue = {
      {
        SecretId = "test_id",
        VersionStage = "AWSCURRENT",
      },
      {
        ['body'] = '{"VersionStage":"AWSCURRENT","SecretId":"test_id"}',
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/secretsmanager/aws4_request, SignedHeaders=content-length;content-type;host;x-amz-date;x-amz-target, Signature=81618df993cf58510f22d95efb815d03a9bd3cfb7af0ef766e6980f7a99799ff',
          ['Content-Length'] = 50,
          ['Content-Type'] = 'application/x-amz-json-1.1',
          ['Host'] = 'secretsmanager.test_region.amazonaws.com',
          ['X-Amz-Date'] = '20221104T062611Z',
          ['X-Amz-Target'] = 'secretsmanager.GetSecretValue'
        },
        ['host'] = 'secretsmanager.test_region.amazonaws.com',
        ['method'] = 'POST',
        ['path'] = '/',
        ['port'] = 443,
        ['query'] = {},
        ['tls'] = true,
      },
    },
  }

  for api, test in pairs(testcases) do
    it("SecretsManager:" .. api, function()
      local param = test[1]
      local expected_result_aws = test[2]

      local result_aws = assert(sm[api](sm, param))

      assert.same(expected_result_aws, result_aws)
    end)
  end
end)
