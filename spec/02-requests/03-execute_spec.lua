local restore = require "spec.helpers".restore

describe("request execution", function()
  local AWS, Credentials

  setup(function()
    restore()
    AWS = require "resty.aws"
    Credentials = require "resty.aws.credentials.Credentials"
  end)

  teardown(function()
    AWS = nil
    package.loaded["resty.aws"] = nil
  end)

  it("tls defaults to true", function ()
    local config = {
      region = "us-east-1"
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
      region = "us-east-1"
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
      region = "us-east-1"
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
      region = "us-east-1"
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
      region = "us-east-1"
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
      region = "us-east-1"
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
end)
