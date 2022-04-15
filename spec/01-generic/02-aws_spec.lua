describe("AWS main instance", function()


  local AWS

  setup(function()
    AWS = require "resty.aws"
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

end)
