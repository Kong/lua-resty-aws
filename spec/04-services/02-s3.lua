setmetatable(_G, nil)

-- hock request sending
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

describe("S3 service", function()
  local s3, s3_3rd

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
    s3 = assert(aws:S3 {})
    s3_3rd = assert(aws:S3 {
      scheme = "http",
      endpoint = "testendpoint.com",
      port = 443,
      tls = false,
    })
  end)

  after_each(function()
  end)

  local testcases = {
    -- API = { param, expected_result_aws, expected_result_3rd_patry, },
    putObject = {
      {
        Bucket = "testbucket",
        Key = "testkey",
        Body = "testbody",
        Metadata = {
          test = "test",
        }
      },
      {
        body = 'testbody',
        headers = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=content-length;host;x-amz-content-sha256;x-amz-date;x-amz-meta-test, Signature=57e7e544e5bce7cdf6321768d7577212a874a3504031fba4bb97ab2e5245532f',
          ['Content-Length'] = 8,
          ['Host'] = 'testbucket.s3.test_region.amazonaws.com',
          ['X-Amz-Content-Sha256'] = '2417e54e58ac3752d4d82355e13053e0b3d9601d09d4fd5027be26da405b8ccd',
          ['X-Amz-Date'] = '20221104T062611Z',
          ['X-Amz-Meta-Test'] = 'test',
        },
        host = 'testbucket.s3.test_region.amazonaws.com',
        method = 'PUT',
        path = '/testkey',
        port = 443,
        query = {},
        tls = true,
      },
      {
        body = 'testbody',
        headers = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=content-length;host;x-amz-content-sha256;x-amz-date;x-amz-meta-test, Signature=c821cc6d135ee1abe2efd235d7a8f699fbaa90e979584cc274f1ea1610679f86',
          ['Content-Length'] = 8,
          ['Host'] = 'testbucket.testendpoint.com',
          ['X-Amz-Content-Sha256'] = '2417e54e58ac3752d4d82355e13053e0b3d9601d09d4fd5027be26da405b8ccd',
          ['X-Amz-Date'] = '20221104T062611Z',
          ['X-Amz-Meta-Test'] = 'test',
        },
        host = 'testbucket.testendpoint.com',
        method = 'PUT',
        path = '/testkey',
        port = 443,
        query = {},
        tls = false,
      },
    },
    getObject = {
      {
        Bucket = "testbucket",
        Key = "testkey",
      },
      {
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=a1cab7c5a3e2ec70af4acaed2dd5382842080af7dbe8f4416540cc99357b322b',
          ['Host'] = 'testbucket.s3.test_region.amazonaws.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 'testbucket.s3.test_region.amazonaws.com',
        ['method'] = 'GET',
        ['path'] = '/testkey',
        ['port'] = 443,
        ['query'] = {},
        ['tls'] = true
      },
      {
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=f0ba4ea255b0678c5e9339e44a976e3f6547bddfaf5dfe5a86403dc97d891010',
          ['Host'] = 'testbucket.testendpoint.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 'testbucket.testendpoint.com',
        ['method'] = 'GET',
        ['path'] = '/testkey',
        ['port'] = 443,
        ['query'] = {},
        ['tls'] = false,
      }
    },
    getBucketAcl = {
      {
        Bucket = "testbucket",
      },
      {
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=69eb892e8f3cae5b3f777c31e4318d946ce0ebba97f8539a5064e1709d8477c6',
          ['Host'] = 'testbucket.s3.test_region.amazonaws.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 'testbucket.s3.test_region.amazonaws.com',
        ['method'] = 'GET',
        ['path'] = '',
        ['port'] = 443,
        ['query'] = {
          ['acl'] = ''
        },
        ['tls'] = true,
      },
      {
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=0aac6b456c28cd393ca06a779074c4797155338569fad6f3e95ea348406b16a9',
          ['Host'] = 'testbucket.testendpoint.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 'testbucket.testendpoint.com',
        ['method'] = 'GET',
        ['path'] = '',
        ['port'] = 443,
        ['query'] = {
          ['acl'] = ''
        },
        ['tls'] = false,
      },
    },
  }


  for api, test in pairs(testcases) do
    it("s3:" .. api, function()
      local param = test[1]
      local expected_result_aws = test[2]
      local expected_result_3rd_patry = test[3]

      local result_aws = assert(s3[api](s3, param))
      local result_3rd_patry = assert(s3_3rd[api](s3_3rd, param))

      assert.same(expected_result_aws, result_aws)
      assert.same(expected_result_3rd_patry, result_3rd_patry)
    end)
  end
end)
