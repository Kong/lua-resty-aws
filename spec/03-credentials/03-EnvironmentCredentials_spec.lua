local restore = require "spec.helpers"

describe("EnvironmentCredentials", function()

  local EnvironmentCredentials

  before_each(function()
    restore()
    restore.setenv("ABC_ACCESS_KEY_ID", "access")
    restore.setenv("ABC_SECRET_ACCESS_KEY", "secret")
    restore.setenv("ABC_SESSION_TOKEN", "token")
    local _ = require("resty.aws.config").global -- load config before anything else

    EnvironmentCredentials = require "resty.aws.credentials.EnvironmentCredentials"
  end)

  after_each(function()
    restore()
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
