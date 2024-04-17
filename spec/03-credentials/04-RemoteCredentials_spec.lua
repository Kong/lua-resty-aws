local json = require("cjson.safe").new()
local restore = require "spec.helpers"

local old_pl_utils = require("pl.utils")

-- Mock for HTTP client
local response = {} -- override in tests
local http_records = {} -- record requests for assertions
local http = {
  new = function()
    return {
      connect = function() return true end,
      set_timeout = function() return true end,
      set_timeouts = function() return true end,
      request = function(self, opts)
        if opts.path == "/test/path" then
          table.insert(http_records, opts)
          return { -- the response for the credentials
              status = (response or {}).status or 200,
              headers = opts and opts.headers or {},
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
  local pl_utils_readfile = old_pl_utils.readfile

  before_each(function()
    pl_utils_readfile = old_pl_utils.readfile
    old_pl_utils.readfile = function()
      return "testtokenabc123"
    end
    restore()
    restore.setenv("AWS_CONTAINER_CREDENTIALS_FULL_URI", "https://localhost/test/path")

    local _ = require("resty.aws.config").global -- load config before mocking http client
    package.loaded["resty.luasocket.http"] = http

    RemoteCredentials = require "resty.aws.credentials.RemoteCredentials"
  end)

  after_each(function()
    old_pl_utils.readfile = pl_utils_readfile
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


describe("RemoteCredentials with customized full URI", function ()
  it("fetches credentials", function ()
    local RemoteCredentials

    restore()
    restore.setenv("AWS_CONTAINER_CREDENTIALS_FULL_URI", "http://localhost:12345/test/path")

    local _ = require("resty.aws.config").global -- load config before mocking http client
    package.loaded["resty.luasocket.http"] = http

    RemoteCredentials = require "resty.aws.credentials.RemoteCredentials"
    finally(function()
      restore()
    end)

    local cred = RemoteCredentials:new()
    local success, key, secret, token = cred:get()
    assert.equal(true, success)
    assert.equal("access", key)
    assert.equal("secret", secret)
    assert.equal("token", token)
  end)
end)

describe("RemoteCredentials with full URI and token file", function ()
  local pl_utils_readfile
  before_each(function()
    pl_utils_readfile = old_pl_utils.readfile
    old_pl_utils.readfile = function()
      return "testtokenabc123"
    end
  end)
  after_each(function()
    old_pl_utils.readfile = pl_utils_readfile
  end)
  it("fetches credentials", function ()
    local RemoteCredentials

    restore()
    restore.setenv("AWS_CONTAINER_CREDENTIALS_FULL_URI", "http://localhost:12345/test/path")
    restore.setenv("AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE", "/var/run/secrets/pods.eks.amazonaws.com/serviceaccount/eks-pod-identity-token")

    local _ = require("resty.aws.config").global -- load config before mocking http client
    package.loaded["resty.luasocket.http"] = http

    RemoteCredentials = require "resty.aws.credentials.RemoteCredentials"
    finally(function()
      restore()
    end)

    local cred = RemoteCredentials:new()
    local success, key, secret, token = cred:get()
    assert.equal(true, success)
    assert.equal("access", key)
    assert.equal("secret", secret)
    assert.equal("token", token)

    assert.not_nil(http_records[#http_records].headers)
    assert.equal(http_records[#http_records].headers["Authorization"], "testtokenabc123")
  end)
end)

describe("RemoteCredentials with full URI and token and token file, file takes higher precedence", function ()
  local pl_utils_readfile
  before_each(function()
    pl_utils_readfile = old_pl_utils.readfile
    old_pl_utils.readfile = function()
      return "testtokenabc123"
    end
  end)
  after_each(function()
    old_pl_utils.readfile = pl_utils_readfile
  end)
  it("fetches credentials", function ()
    local RemoteCredentials

    restore()
    restore.setenv("AWS_CONTAINER_CREDENTIALS_FULL_URI", "http://localhost:12345/test/path")
    restore.setenv("AWS_CONTAINER_AUTHORIZATION_TOKEN", "testtoken")
    restore.setenv("AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE", "/var/run/secrets/pods.eks.amazonaws.com/serviceaccount/eks-pod-identity-token")

    local _ = require("resty.aws.config").global -- load config before mocking http client
    package.loaded["resty.luasocket.http"] = http

    RemoteCredentials = require "resty.aws.credentials.RemoteCredentials"
    finally(function()
      restore()
    end)

    local cred = RemoteCredentials:new()
    local success, key, secret, token = cred:get()
    assert.equal(true, success)
    assert.equal("access", key)
    assert.equal("secret", secret)
    assert.equal("token", token)

    assert.not_nil(http_records[#http_records].headers)
    assert.equal(http_records[#http_records].headers["Authorization"], "testtokenabc123")
  end)
end)

