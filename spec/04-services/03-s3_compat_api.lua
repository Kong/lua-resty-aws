setmetatable(_G, nil)

-- hock request sending
package.loaded["resty.aws.request.execute"] = function(...)
  return ...
end

local AWS = require("resty.aws")
local AWS_global_config = require("resty.aws.config").global


local config = AWS_global_config
config.tls = true
-- old API format
config.s3_bucket_in_path = true
local aws = AWS(config)


aws.config.credentials = aws:Credentials {
  accessKeyId = "test_id",
  secretAccessKey = "test_key",
}

aws.config.region = "test_region"

describe("S3 service", function()
  local s3, s3_3rd
  before_each(function()
    s3 = assert(aws:S3 {})
    s3_3rd = assert(aws:S3 {
      scheme = "http",
      endpoint = "testendpoint.com",
      port = 443,
      tls = false,
    })
    ngx.origin_time = ngx.time
    ngx.time = function ()
      return 1667543171
    end
  end)

  after_each(function()
    ngx.time = ngx.origin_time
    ngx.origin_time = nil
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
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=content-length;host;x-amz-content-sha256;x-amz-date;x-amz-meta-test, Signature=5d3c4b53bfcecfba7b9c76637f64e832ad35af583d1098df6eabc1b98a5f4c4f',
          ['Content-Length'] = 8,
          ['Host'] = 's3.test_region.amazonaws.com',
          ['X-Amz-Content-Sha256'] = '2417e54e58ac3752d4d82355e13053e0b3d9601d09d4fd5027be26da405b8ccd',
          ['X-Amz-Date'] = '20221104T062611Z',
          ['X-Amz-Meta-Test'] = 'test',
        },
        host = 's3.test_region.amazonaws.com',
        method = 'PUT',
        path = '/testbucket/testkey',
        port = 443,
        query = {},
        tls = true,
      },
      {
        body = 'testbody',
        headers = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=content-length;host;x-amz-content-sha256;x-amz-date;x-amz-meta-test, Signature=3536e1dcf26a23b78a5345df54ef1f86c796f13251c7fdaa23d78f6d67aeb0be',
          ['Content-Length'] = 8,
          ['Host'] = 'testendpoint.com',
          ['X-Amz-Content-Sha256'] = '2417e54e58ac3752d4d82355e13053e0b3d9601d09d4fd5027be26da405b8ccd',
          ['X-Amz-Date'] = '20221104T062611Z',
          ['X-Amz-Meta-Test'] = 'test',
        },
        host = 'testendpoint.com',
        method = 'PUT',
        path = '/testbucket/testkey',
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
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=66fc85f53ba4ff3665e1c575c882216b6489442e1bc2822d73b2f43949cca0cf',
          ['Host'] = 's3.test_region.amazonaws.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 's3.test_region.amazonaws.com',
        ['method'] = 'GET',
        ['path'] = '/testbucket/testkey',
        ['port'] = 443,
        ['query'] = {},
        ['tls'] = true
      },
      {
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=67a06a5f1634a5e9598d576636ef7d6d77a6fe7f07a0e1d5f66df80a3c47e9f4',
          ['Host'] = 'testendpoint.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 'testendpoint.com',
        ['method'] = 'GET',
        ['path'] = '/testbucket/testkey',
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
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=19bf55ee1b8db1c5099c8e40cf96881479e47cb2e7f08d191f31733f0335d38d',
          ['Host'] = 's3.test_region.amazonaws.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 's3.test_region.amazonaws.com',
        ['method'] = 'GET',
        ['path'] = '/testbucket',
        ['port'] = 443,
        ['query'] = {
          ['acl'] = ''
        },
        ['tls'] = true,
      },
      {
        ['headers'] = {
          ['Authorization'] = 'AWS4-HMAC-SHA256 Credential=test_id/20221104/test_region/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=8439d7f57d8de5b9ecb6a578983b8e5fb6722ca375530753d4a6f498d2c4194e',
          ['Host'] = 'testendpoint.com',
          ['X-Amz-Content-Sha256'] = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ['X-Amz-Date'] = '20221104T062611Z'
        },
        ['host'] = 'testendpoint.com',
        ['method'] = 'GET',
        ['path'] = '/testbucket',
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
