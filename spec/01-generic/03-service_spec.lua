describe("service generator", function()


  local AWS

  setup(function()
    AWS = require "resty.aws"
  end)

  teardown(function()
    AWS = nil
    package.loaded["resty.aws"] = nil
  end)


  it("creates a service", function()
    local sts = AWS():STS()
    assert.is.table(sts)
    assert.is.table(sts.config)
    assert.is.table(sts.api)
    assert.equal("STS", sts.api.metadata.serviceId)
    assert.equal("v4", sts.api.metadata.signatureVersion)
    assert.equal("AWS Security Token Service", sts.api.metadata.serviceFullName)
  end)


  it("sets the parent aws instance", function()
    local aws = AWS()
    local sts = aws:STS()
    assert.equal(aws, sts.config.aws)
  end)


  it("creates a specific service version", function()
    -- App Mesh has 2 versions, test both to make sure we do
    -- not hit a default
    local mesh = assert(AWS():AppMesh({ apiVersion = "2019-01-25", region = "us-east-1" }))
    assert.equal("2019-01-25", mesh.config.apiVersion)

    local mesh = assert(AWS():AppMesh({ apiVersion = "2018-10-01", region = "us-east-1" }))
    assert.equal("2018-10-01", mesh.config.apiVersion)
  end)


  it("creates methods for operations", function()
    local sts = AWS():STS()
    assert.is.Function(sts.assumeRole)
  end)


  it("generated operations validate input 1", function()
    local sts = assert(AWS():STS())
    --print(require("pl.pretty").write(sts.config))
    local ok, err = sts:assumeRole({
      RoleSessionName = "just_a_name",
    })
    assert.equal("STS:assumeRole() validation error: params.RoleArn is required but missing", err)
    assert.is_nil(ok)
  end)


  it("generated operations validate input 2", function()
    local sm = assert(AWS():SecretsManager({region = "us-east-1"}))
    --print(require("pl.pretty").write(sm.config))
    local ok, err = sm:getSecretValue({
      RoleSessionName = "just_a_name",
    })
    assert.equal("SecretsManager:getSecretValue() validation error: params.SecretId is required but missing", err)
    assert.is_nil(ok)
  end)


  -- just for debugging, always fails
  --[[
  it("creates a service", function()
    local sts = AWS().STS()
    assert.equal({}, sts.api.operations.assumeRole)
  end)
  --]]

end)
