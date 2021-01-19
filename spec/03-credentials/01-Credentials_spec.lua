describe("Credentials base-class", function()

  local AWS, Credentials

  setup(function()
    AWS = require "resty.aws"
    Credentials = require "resty.aws.credentials.Credentials"
  end)



  describe("Class inheritance", function()
    local EnvironmentCredentials
    local old_getenv = os.getenv

    setup(function()
      EnvironmentCredentials = require "resty.aws.credentials.EnvironmentCredentials"

      local mockvars = {
        ABC_ACCESS_KEY_ID = "access",
        ABC_SECRET_ACCESS_KEY = "secret",
        ABC_SESSION_TOKEN = "token",
      }
      os.getenv = function(name)  -- luacheck: ignore
        return mockvars[name] or old_getenv(name) or nil
      end
    end)

    teardown(function()
      os.getenv = old_getenv  -- luacheck: ignore
    end)



    it("instance does not modify class", function()
      local cred = Credentials:new { expiryWindow = 20 }
      assert.equal(20, cred.expiryWindow)
      assert.Not.equal(20, Credentials.expiryWindow)
    end)


    it("sub-class instance does not modify class nor sub-class", function()
      local cred = EnvironmentCredentials:new { expiryWindow = 20, envPrefix = "ABC" }

      assert.equal(20, cred.expiryWindow)
      assert.Not.equal(20, Credentials.expiryWindow)
      assert.Not.equal(20, EnvironmentCredentials.expiryWindow)

      assert.equal("ABC", cred.envPrefix)
      assert.Not.equal("ABC", Credentials.envPrefix)
      assert.Not.equal("ABC", EnvironmentCredentials.envPrefix)

      cred:get() -- refreshes and sets values
      assert.is.equal("access", cred.accessKeyId)
      assert.is.Nil(Credentials.accessKeyId)
      assert.is.Nil(EnvironmentCredentials.accessKeyId)
    end)

  end)



  it("new() accepts credentials", function()
    local exp = ngx.now() + 60
    local cred = Credentials:new {
      accessKeyId = "access",
      secretAccessKey = "secret",
      sessionToken = "token",
      expireTime = exp
    }
    assert.is_false(cred:needsRefresh())
    assert.same({true, "access", "secret", "token", exp}, {cred:get()})
  end)


  it("instantiation from aws instance", function()
    local aws = AWS()
    local exp = ngx.now() + 60
    local cred = aws:Credentials({
      accessKeyId = "access",
      secretAccessKey = "secret",
      sessionToken = "token",
      expireTime = exp
    })
    assert.is_false(cred:needsRefresh())
    assert.same({true, "access", "secret", "token", exp}, {cred:get()})
    assert.equals(aws, cred.aws)
  end)


  it("new() expireTime defaults to 10 years if creds provided", function()
    local cred = Credentials:new {
      accessKeyId = "access",
      secretAccessKey = "secret",
      sessionToken = "token",
    }
    assert.is_false(cred:needsRefresh())

    local get = {cred:get()}
    assert.is.near(ngx.now() + 10*365*24*60*60, 30, get[5]) -- max delta = 30 seconds

    get[5] = nil
    assert.same({true, "access", "secret", "token"}, get)
  end)


  it("new() only setting expireTime defaults to 0", function()
    local cred = Credentials:new {
      expireTime = ngx.now() + 60
    }
    assert.is_true(cred:needsRefresh())
  end)


  it("needsRefresh()", function()
    local cred = Credentials:new()
    assert.is_true(cred:needsRefresh())

    cred:set(1,2,3,ngx.now() + 60*60)
    assert.is_false(cred:needsRefresh())
  end)


  it("needsRefresh() accounts for expiryWindow", function()
    local expWindow = 20
    local cred = Credentials:new { expiryWindow = expWindow }

    cred:set(1,2,3,ngx.now() + expWindow + 0.1)
    assert.is_false(cred:needsRefresh())

    cred:set(1,2,3,ngx.now() + expWindow - 0.1)
    assert.is_true(cred:needsRefresh())
  end)


  it("get() returns properties", function()
    local cred = Credentials:new()
    local exp = ngx.now() + 60
    cred:set(1,2,3,exp)

    assert.are.same({true, 1,2,3,exp}, {cred:get()})
  end)


  it("get() invokes refresh() when expired", function()
    local cred = Credentials:new()

    stub(cred, "refresh")

    cred:get()
    assert.stub(cred.refresh).was.called()
  end)


  it("set() sets properties", function()
    local cred = Credentials:new()
    local exp = ngx.now() + 60
    cred:set(1,2,3,exp)

    assert.are.same({true,1,2,3,exp}, {cred:get()})
  end)


  it("set() accepts rfc3339 dates for expireTime", function()
    local cred = Credentials:new()
    local exp = "2030-01-01T20:00:00Z"

    assert.has.no.error(function()
      cred:set(1,2,3,exp)
    end)

    local _, _, _, _, t = cred:get()
    assert.is.number(t)
    assert(ngx.now() < t)
  end)

end)
