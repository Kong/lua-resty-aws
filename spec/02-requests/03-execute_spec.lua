local restore = require "spec.helpers".restore
local cjson = require "cjson"

describe("request execution", function()
  local AWS, Credentials

  local mock_request_response = {
    ["s3.amazonaws.com"] = {
      ["/"] = {
        GET = {
          status = 200,
          headers = {
            ["x-amz-id-2"] = "test",
            ["x-amz-request-id"] = "test",
            ["Date"] = "test",
            ["Content-Type"] = "application/json",
            ["Server"] = "AmazonS3",
          },
          body = [[{"ListAllMyBucketsResult":{"Buckets":[]}}]]
        }
      }
    }
  }

  setup(function()
    restore()
    local http = require "resty.luasocket.http"
    http.connect = function(...) return true end
    http.request = function(self, req)
      return { has_body = true,
               status = mock_request_response[req.headers.Host][req.path][req.method].status,
               headers = mock_request_response[req.headers.Host][req.path][req.method].headers,
               read_body = function()
                 local resp = mock_request_response[req.headers.Host][req.path][req.method].body
                 return resp
               end
              }
    end
    http.set_timeout = function(...) return true end
    http.set_keepalive = function(...) return true end
    http.close = function(...) return true end
    AWS = require "resty.aws"
    Credentials = require "resty.aws.credentials.Credentials"
  end)

  teardown(function()
    package.loaded["resty.luasocket.http"] = nil
    AWS = nil
    package.loaded["resty.aws"] = nil
  end)

  it("tls defaults to true", function ()
    local config = {
      region = "us-east-1",
      protocol = "json",
    }

    config.credentials = Credentials:new({
      accessKeyId = "teqst_id",
      secretAccessKey = "test_key",
    })

    local aws = AWS(config)
    aws.config.dry_run = true

    local s3 = aws:S3()

    assert.same(type(s3.getObject), "function")
    local request, err = s3:getObject({
      Bucket = "test-bucket",
      Key = "test-key",
    })

    assert.same(err, nil)
    assert.same(request.tls, true)
  end)

  it("support configuring tls false", function ()
    local config = {
      region = "us-east-1",
      protocol = "json",
    }

    config.credentials = Credentials:new({
      accessKeyId = "teqst_id",
      secretAccessKey = "test_key",
    })

    local aws = AWS(config)
    aws.config.tls = false
    aws.config.dry_run = true

    local s3 = aws:S3()

    assert.same(type(s3.getObject), "function")
    local request, err = s3:getObject({
      Bucket = "test-bucket",
      Key = "test-key",
    })

    assert.same(err, nil)
    assert.same(request.port, 80)
    assert.same(request.tls, false)
  end)

  it("support configuring ssl verify false", function ()
    local config = {
      region = "us-east-1",
      protocol = "json"
    }

    config.credentials = Credentials:new({
      accessKeyId = "teqst_id",
      secretAccessKey = "test_key",
    })

    local aws = AWS(config)
    aws.config.dry_run = true
    aws.config.ssl_verify = false

    local s3 = aws:S3()

    assert.same(type(s3.getObject), "function")
    local request, err = s3:getObject({
      Bucket = "test-bucket",
      Key = "test-key",
    })

    assert.same(err, nil)
    assert.same(request.ssl_verify, false)
  end)

  it("support configure timeout", function ()
    local config = {
      region = "us-east-1",
      protocol = "json",
    }

    config.credentials = Credentials:new({
      accessKeyId = "teqst_id",
      secretAccessKey = "test_key",
    })

    local aws = AWS(config)
    aws.config.dry_run = true
    aws.config.timeout = 123456000

    local s3 = aws:S3()

    assert.same(type(s3.getObject), "function")
    local request, err = s3:getObject({
      Bucket = "test-bucket",
      Key = "test-key",
    })

    assert.same(err, nil)
    assert.same(request.timeout, 123456000)
  end)

  it("support configure keepalive idle timeout", function ()
    local config = {
      region = "us-east-1",
      protocol = "json",
    }

    config.credentials = Credentials:new({
      accessKeyId = "teqst_id",
      secretAccessKey = "test_key",
    })

    local aws = AWS(config)
    aws.config.dry_run = true
    aws.config.keepalive_idle_timeout = 123456000

    local s3 = aws:S3()

    assert.same(type(s3.getObject), "function")
    local request, err = s3:getObject({
      Bucket = "test-bucket",
      Key = "test-key",
    })

    assert.same(err, nil)
    assert.same(request.keepalive_idle_timeout, 123456000)
  end)

  it("support set proxy options", function ()
    local config = {
      region = "us-east-1",
      protocol = "json",
    }

    config.credentials = Credentials:new({
      accessKeyId = "teqst_id",
      secretAccessKey = "test_key",
    })

    local proxy_opts = {
      http_proxy = 'http://test-http-proxy:1234',
      https_proxy = 'http://test-https-proxy:4321',
      no_proxy = '127.0.0.1,localhost'
    }

    local aws = AWS(config)
    aws.config.dry_run = true
    aws.config.http_proxy = proxy_opts.http_proxy
    aws.config.https_proxy = proxy_opts.https_proxy
    aws.config.no_proxy = proxy_opts.no_proxy

    local s3 = aws:S3()

    assert.same(type(s3.getObject), "function")
    local request, _ = s3:getObject({
      Bucket = "test-bucket",
      Key = "test-key",
    })

    assert.same(type(request.proxy_opts), "table")
    for k, v in pairs(proxy_opts) do
      assert.same(request.proxy_opts[k], v)
    end
  end)

  it("decoded json body should have array metatable", function ()
    local config = {
      region = "us-east-1",
      protocol = "json",
    }

    config.credentials = Credentials:new({
      accessKeyId = "teqst_id",
      secretAccessKey = "test_key",
    })

    local aws = AWS(config)

    local s3 = aws:S3()

    assert.same(type(s3.listBuckets), "function")
    local resp = s3:listBuckets()

    assert.is_not_nil(resp.body)
    assert.same([[{"ListAllMyBucketsResult":{"Buckets":[]}}]], cjson.encode(resp.body))
  end)
end)
