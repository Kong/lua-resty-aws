describe("EnvironmentCredentials", function()

  local EnvironmentCredentials = require "resty.aws.credentials.EnvironmentCredentials"
  local old_getenv = os.getenv

  setup(function()
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



  it("gets environment variables", function()
    local cred = EnvironmentCredentials:new { envPrefix = "ABC" }
    assert.is_false(cred:needsRefresh()) -- false; because we fetch upon instanciation

    local get = {cred:get()}
    assert.is.near(ngx.now() + 10*365*24*60*60, 30, get[5]) -- max delta = 30 seconds

    get[5] = nil
    assert.same({true, "access", "secret", "token"}, get)
  end)

end)
