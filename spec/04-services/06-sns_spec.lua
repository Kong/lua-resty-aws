setmetatable(_G, nil)

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
aws.config.dry_run = true

describe("SNS service", function()
  local sns
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
    sns = assert(aws:SNS({}))
  end)

  after_each(function()
  end)

  local testcases = {
    publish = {
      {
        TopicArn = "arn:aws:sns:test-region:000000000000:test-topic",
        Message = '{"timestamp":"1980-01-02T08:11:12.123+01:00","message":"test%abc%22"}',  -- this is not an urlencoded message value
      },
      {
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/sns/aws4_request, SignedHeaders=host;x-amz-date, Signature=9a83a7bafbccd6c3214091baf22eb1d1e507327be18f7ad5cf8ccc45ac335e48',
          ['Host'] = 'sns.test_region.amazonaws.com',
          ['X-Amz-Date'] = '20221104T062611Z',
        },
        ['host'] = 'sns.test_region.amazonaws.com',
        ['method'] = 'POST',
        ['path'] = '/',
        ['proxy_opts'] = {},
        ['port'] = 443,
        ['query'] = {
          ['Action'] = 'Publish',
          ['Version'] = '2010-03-31',
          ['Message'] = '{"timestamp":"1980-01-02T08:11:12.123+01:00","message":"test%abc%22"}',
          ['TopicArn'] = 'arn:aws:sns:test-region:000000000000:test-topic',
        },
        ['tls'] = true,
      },
    },
  }

  for api, test in pairs(testcases) do
    it("SecretsManager:" .. api, function()
      local param = test[1]
      local expected_result_aws = test[2]

      local result_aws = assert(sns[api](sns, param))

      assert.same(expected_result_aws, result_aws)
    end)
  end
end)
