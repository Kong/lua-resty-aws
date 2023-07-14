describe("AWS main instance", function()


  local AWS

  setup(function()
    package.loaded["resty.aws.request.execute"] = function ()
      return {
        status = 200,
        reason = "OK",
        headers = {},
        body = ""
      }
    end
    AWS = require "resty.aws"
    -- execute_request = require "resty.aws.request.execute"
  end)

  teardown(function()
    AWS = nil
    package.loaded["resty.aws"] = nil
  end)


  it("gets default config #only", function()
    local aws = AWS()
    assert.is.table(aws.config)
    assert.same({
      apiVersion = "latest",
      credentials = aws:CredentialProviderChain(),
    }, aws.config)
  end)


  it("overrides default config", function()
    local aws = AWS({
      region = "eu-central-1",
      apiVersion = "2020-09-29",
    })
    assert.is.table(aws.config)
    assert.same({
      region = "eu-central-1",
      apiVersion = "2020-09-29",
      credentials = require("resty.aws.credentials.CredentialProviderChain"):new({ aws = aws }),
    }, aws.config)
  end)


  it("allows custom config", function()
    local aws = AWS({
      unknown_property = "hi!",
    })
    assert.is.table(aws.config)
    assert.equal("hi!", aws.config.unknown_property)
  end)


  it("gets methods for services", function()
    local aws = AWS()
    assert.is.Function(aws.STS)
  end)


  it("gets methods for services, spaces removed from serviceId", function()
    local aws = AWS()
    assert.is.Function(aws.AppMesh) -- serviceId = "App Mesh"
  end)

  it("support sts regional endpoint inject and only inject once", function()
    local aws = AWS({
      region = "eu-central-1",
      stsRegionalEndpoints = "regional",
    })

    aws.config.credentials = aws:Credentials {
      accessKeyId = "test_id",
      secretAccessKey = "test_key",
    }

    assert.is.table(aws.config)
    local sts, err = aws:STS()
    local _, err = sts:assumeRole {
      RoleArn = "aws:arn::XXXXXXXXXXXXXXXXX:test123",
      RoleSessionName = "aws-test",
    }
    assert.same("https://sts.eu-central-1.amazonaws.com", sts.config.endpoint)

    local _, err = sts:assumeRole {
      RoleArn = "aws:arn::XXXXXXXXXXXXXXXXX:test123",
      RoleSessionName = "aws-test",
    }
    assert.same("https://sts.eu-central-1.amazonaws.com", sts.config.endpoint)
  end)

end)
