local json = require("cjson.safe").new()
local restore = require "spec.helpers"


-- Mock for HTTP client
local response = {} -- override in tests
local http = {
  new = function()
    return {
      connect = function() return true end,
      set_timeout = function() return true end,
      set_timeouts = function() return true end,
      request = function(self, opts)
        if opts.path == "/test/path" then
          return { -- the response for the credentials
              status = (response or {}).status or 200,
              read_body = function() return json.encode {
                  AccessKeyId = (response or {}).AccessKeyId or "access",
                  SecretAccessKey = (response or {}).SecretAccessKey or "secret",
                  Token = (response or {}).Token or "token",
                  Expiration = (response or {}).Expiration or "2030-01-01T20:00:00Z",
                }
              end,
            }
        else
          error("bad test path provided??? " .. tostring(opts.path))
        end
      end,
    }
  end,
}


describe("RemoteCredentials", function()

  local RemoteCredentials

  before_each(function()
    restore()
    restore.setenv("AWS_CONTAINER_CREDENTIALS_FULL_URI", "https://localhost/test/path")

    local _ = require("resty.aws.config").global -- load config before mocking http client
    package.loaded["resty.aws.request.http.http"] = http

    RemoteCredentials = require "resty.aws.credentials.RemoteCredentials"
  end)

  after_each(function()
    restore()
  end)



  it("fetches credentials", function()
    local cred = RemoteCredentials:new()
    local success, key, secret, token = cred:get()
    assert.equal(true, success)
    assert.equal("access", key)
    assert.equal("secret", secret)
    assert.equal("token", token)
  end)

end)
