describe("CredentialProviderChain", function()

  local CredentialProviderChain = require "resty.aws.credentials.CredentialProviderChain"
  local old_getenv = os.getenv
  local mockvars

  setup(function()
    os.getenv = function(name)  -- luacheck: ignore
      return mockvars[name] or old_getenv(name) or nil
    end
  end)

  before_each(function()
    mockvars = {
      ABC_ACCESS_KEY_ID = "access-1",
      ABC_SECRET_ACCESS_KEY = "secret-1",
      ABC_SESSION_TOKEN = "token-1",
    }
  end)

  teardown(function()
    os.getenv = old_getenv  -- luacheck: ignore
  end)



  it("gets environment variables which are first", function()
    local cred = CredentialProviderChain:new {
      providers = {
        require("resty.aws.credentials.EnvironmentCredentials"):new { envPrefix = "ABC" },
        require("resty.aws.credentials.EnvironmentCredentials"):new { envPrefix = "AWS" },
        require("resty.aws.credentials.Credentials"):new {
          accessKeyId = "access-2",
          secretAccessKey = "secret-2",
          sessionToken = "token-2",
         },
      }
    }
    assert.is_true(cred:needsRefresh())

    local get = {cred:get()}
    get[5] = nil -- drop the expireTime

    assert.same({true, "access-1", "secret-1", "token-1"}, get)
  end)


  it("gets plain credentials which are last", function()
    mockvars = {} -- clear env vars such that the first 2 providers both fail
    local cred = CredentialProviderChain:new {
      providers = {
        require("resty.aws.credentials.EnvironmentCredentials"):new { envPrefix = "ABC" },
        require("resty.aws.credentials.EnvironmentCredentials"):new { envPrefix = "AWS" },
        require("resty.aws.credentials.Credentials"):new {
          accessKeyId = "access-2",
          secretAccessKey = "secret-2",
          sessionToken = "token-2",
         },
      }
    }
    assert.is_true(cred:needsRefresh())

    local get = {cred:get()}
    get[5] = nil -- drop the expireTime

    assert.same({true, "access-2", "secret-2", "token-2"}, get)
  end)


  it("gets default providers if not specified", function()
    local cred = CredentialProviderChain:new()
    assert.is.not_nil(cred.providers[1])
  end)

end)
