local json = require("cjson.safe").new()

-- Mock for HTTP client
local response = {} -- override in tests
local http = {
  new = function()
    return {
      connect = function() return true end,
      close = function() return true end,
      set_timeout = function() return true end,
      request = function(self, opts)
        if opts.path == "/latest/meta-data/iam/security-credentials/" then
          return { -- the response for requesting the role name
              status = 200,
              read_body = function() return "the_role_name" end,
            }
        elseif opts.path == "/latest/meta-data/iam/security-credentials/the_role_name" then
          return { -- the response for the credentials for the role
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


describe("EC2MetadataCredentials", function()

  local EC2MetadataCredentials

  setup(function()
    package.loaded["resty.aws.request.http.http"] = http
  end)

  teardown(function()
    package.loaded["resty.aws.request.http.http"] = nil
  end)

  before_each(function()
    package.loaded["resty.aws.credentials.EC2MetadataCredentials"] = nil
    EC2MetadataCredentials = require "resty.aws.credentials.EC2MetadataCredentials"
  end)



  it("fetches credentials", function()
    local cred = EC2MetadataCredentials:new()
    local success, key, secret, token = cred:get()
    assert.equal("access", key)
    assert.equal(true, success)
    assert.equal("secret", secret)
    assert.equal("token", token)
  end)

end)
