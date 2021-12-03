describe("TokenFileWebIdentityCredentials", function()

  local TokenFileWebIdentityCredentials
  local old_getenv = os.getenv
  local mockvars

  before_each(function()
    mockvars = {
      AWS_ROLE_ARN = "arn:abc123",
      AWS_WEB_IDENTITY_TOKEN_FILE = "/some/file",
    }
    os.getenv = function(name)  -- luacheck: ignore
      return mockvars[name] or old_getenv(name) or nil
    end
    TokenFileWebIdentityCredentials = require "resty.aws.credentials.TokenFileWebIdentityCredentials"
  end)

  after_each(function()
    os.getenv = old_getenv  -- luacheck: ignore
  end)



  it("gets the relevant environment variables", function()
    local cred = TokenFileWebIdentityCredentials:new()
    assert.is_true(cred:needsRefresh()) -- true; because we only get env vars

    assert.same(mockvars.AWS_ROLE_ARN, cred.role_arn)
    assert.same(mockvars.AWS_WEB_IDENTITY_TOKEN_FILE, cred.token_file)
    assert.same("session@lua-resty-aws", cred.session_name)
  end)

  it("options override defaults", function()
    local cred = TokenFileWebIdentityCredentials:new {
      token_file = "another/file",
      role_arn = "another arn",
      session_name = "i like sessions",
    }
    assert.same("another arn", cred.role_arn)
    assert.same("another/file", cred.token_file)
    assert.same("i like sessions", cred.session_name)
  end)

end)
