local utils = require "resty.aws.utils"

describe("Utils:getInstanceSignature", function()
  local mock_token = "mock-imds-token-12345"
  local mock_signature = "-----BEGIN PKCS7-----\nMIAGCSqGSIb3DQEHAqCAMIACAQExCzAJ\n-----END PKCS7-----\n"
  local expected_signature = "-----BEGIN PKCS7-----MIAGCSqGSIb3DQEHAqCAMIACAQExCzAJ-----END PKCS7-----"

  local http = {
    new = function()
      return {
        connect = function() return true end,
        set_timeouts = function() return true end,
        close = function() end,
        request_uri = function(self, uri, opts)
          if string.find(uri, "/latest/api/token") then
            ngx.log(ngx.ERR, "Returning mock IMDSv2 token")
            return {
              status = 200,
              headers = {
                ["Content-Type"] = "application/xml",
              },
              body = mock_token
            }
          elseif string.find(uri, "/rsa2048") then
            return {
              status = 200,
              headers = {
                ["Content-Type"] = "application/xml",
              },
              body = mock_signature
            }
          end
        end,
      }
    end
  }

  setup(function()
    package.loaded["resty.luasocket.http"] = http
  end)

  teardown(function()
    package.loaded["resty.luasocket.http"] = nil
  end)

  before_each(function()
    package.loaded["resty.luasocket.http"] = http
    package.loaded["resty.aws.utils"] = nil
    utils = require "resty.aws.utils"
  end)

  it("fetches instance signature successfully with IMDSv2", function()
    local signature, err = utils.getInstanceSignature()

    assert.is_nil(err)
    assert.equals(expected_signature, signature)
  end)
end)
