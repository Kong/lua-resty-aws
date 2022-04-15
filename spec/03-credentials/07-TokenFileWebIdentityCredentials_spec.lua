local restore = require "spec.helpers"

describe("TokenFileWebIdentityCredentials", function()

  local TokenFileWebIdentityCredentials

  before_each(function()
    restore()
    restore.setenv("AWS_ROLE_ARN", "arn:abc123")
    restore.setenv("AWS_WEB_IDENTITY_TOKEN_FILE", "/some/file")
    local _ = require("resty.aws.config").global -- load config before anything else

    TokenFileWebIdentityCredentials = require "resty.aws.credentials.TokenFileWebIdentityCredentials"
  end)

  after_each(function()
    restore()
  end)



  it("gets the relevant environment variables", function()
    local cred = TokenFileWebIdentityCredentials:new()
    assert.is_true(cred:needsRefresh()) -- true; because we only get env vars

    assert.same("arn:abc123", cred.role_arn)
    assert.same("/some/file", cred.token_file)
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
