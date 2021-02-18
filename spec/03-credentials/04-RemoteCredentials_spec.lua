local json = require("cjson.safe").new()

-- Mock for HTTP client
local response = {} -- override in tests
local http = {
  new = function()
    return {
      connect = function() return true end,
      set_timeout = function() return true end,
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
  local old_getenv = os.getenv
  local mockvars = {
    AWS_CONTAINER_CREDENTIALS_FULL_URI = "https://localhost/test/path",
  }

  before_each(function()
    os.getenv = function(name)  -- luacheck: ignore
      return mockvars[name] or old_getenv(name) or nil
    end
    package.loaded["resty.aws.request.http.http"] = http
    package.loaded["resty.aws.credentials.RemoteCredentials"] = nil
    RemoteCredentials = require "resty.aws.credentials.RemoteCredentials"
  end)

  after_each(function()
    package.loaded["resty.aws.request.http.http"] = nil
    package.loaded["resty.aws.credentials.RemoteCredentials"] = nil
    os.getenv = old_getenv  -- luacheck: ignore
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
